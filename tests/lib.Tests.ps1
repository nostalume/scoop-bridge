#Requires -Module Pester

BeforeAll {
    $script:BinRoot = Join-Path (Join-Path $PSScriptRoot '..') 'bin'
    . (Join-Path $script:BinRoot 'lib.ps1')

    function New-TestRepository {
        param(
            [Parameter(Mandatory)][string]$Destination,
            [Parameter(Mandatory)][string]$Version,
            [string]$ManifestName = 'sample.json'
        )

        $bucket = Join-Path $Destination 'bucket'
        $null = New-Item -ItemType Directory -Path $bucket -Force
        $content = @{
            version = $Version
            url = "https://example.com/$Version.zip"
        } | ConvertTo-Json
        [System.IO.File]::WriteAllText(
            (Join-Path $bucket $ManifestName),
            $content,
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    function New-TestContext {
        param([string[]]$Repositories = @('owner/source'))

        @{
            repositories = $Repositories
            proxies = @{}
            rules = @()
            postprocess = @()
        }
    }
}

Describe 'Expand-Variables' {
    It 'expands single and recursive variables' {
        $variables = @{
            Proxy = '${Mirror}'
            Mirror = 'https://mirror.example'
        }

        Expand-Variables -Text '${Proxy}/path' -Variables $variables |
            Should -Be 'https://mirror.example/path'
    }

    It 'rejects expansion cycles' {
        $variables = @{
            First = '${Second}'
            Second = '${First}'
        }

        { Expand-Variables -Text '${First}' -Variables $variables } |
            Should -Throw '*cycle*'
    }
}

Describe 'Manifest transformation' {
    BeforeEach {
        $script:ManifestPath = Join-Path $TestDrive 'test.json'
        [System.IO.File]::WriteAllText(
            $script:ManifestPath,
            '{"url":"https://github.com/user/repo"}',
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    It 'applies replacement rules and writes UTF-8 without BOM' {
        $rules = @(
            [PSCustomObject]@{
                description = 'Test rule'
                find = 'github\.com'
                replace = 'proxy.example/github'
            }
        )

        Update-Manifest -Manifest (Get-Item $script:ManifestPath) -Rules $rules |
            Should -BeTrue

        [System.IO.File]::ReadAllText($script:ManifestPath) |
            Should -Match 'proxy\.example/github'
        $bytes = [System.IO.File]::ReadAllBytes($script:ManifestPath)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) |
            Should -BeFalse
    }

    It 'rejects invalid output without changing the file' {
        $original = [System.IO.File]::ReadAllText($script:ManifestPath)
        $rules = @(
            [PSCustomObject]@{
                description = 'Break JSON'
                find = '"url"'
                replace = '"url": invalid'
            }
        )

        { Update-Manifest -Manifest (Get-Item $script:ManifestPath) -Rules $rules } |
            Should -Throw '*Invalid JSON*'
        [System.IO.File]::ReadAllText($script:ManifestPath) | Should -Be $original
    }

    It 'rejects non-absolute manifest URLs' {
        { Test-ManifestContent -Content '{"url":"mirror.example/file.zip"}' -Source 'fixture' } |
            Should -Throw '*non-absolute URL*'
    }

    It 'accepts Scoop URL placeholders used by autoupdate hash checks' {
        $content = '{"autoupdate":{"hash":{"url":"$url.sha256"}}}'

        { Test-ManifestContent -Content $content -Source 'fixture' } |
            Should -Not -Throw
    }

    It 'tolerates whitespace in an upstream absolute URL' {
        { Test-ManifestContent -Content '{"checkver":{"url":" https://example.test"}}' -Source 'fixture' } |
            Should -Not -Throw
    }
}

Describe 'Staged aggregation' {
    BeforeEach {
        $script:Root = Join-Path $TestDrive 'root'
        $null = New-Item -ItemType Directory -Path (Join-Path $script:Root 'bucket') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $script:Root 'scripts') -Force
        Set-Content -LiteralPath (Join-Path $script:Root 'bucket\existing.txt') -Value 'keep'
        Set-Content -LiteralPath (Join-Path $script:Root 'scripts\existing.txt') -Value 'keep'
    }

    It 'keeps published output unchanged during a dry run' {
        Mock Invoke-GitClone {
            param($Repository, $Destination)
            New-TestRepository -Destination $Destination -Version '1.0.0'
        }

        $result = Invoke-Entry -DryRun -Context (New-TestContext) -Root $script:Root

        $result.DryRun | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:Root 'bucket\existing.txt') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:Root 'bucket\sample.json') |
            Should -BeFalse
        @(Get-ChildItem -LiteralPath $script:Root -Filter '.scoopbridge-work-*').Count |
            Should -Be 0
    }

    It 'keeps published output when acquisition fails' {
        Mock Invoke-GitClone { throw 'simulated clone failure' }

        { Invoke-Entry -Context (New-TestContext) -Root $script:Root } |
            Should -Throw '*simulated clone failure*'
        Test-Path -LiteralPath (Join-Path $script:Root 'bucket\existing.txt') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:Root 'scripts\existing.txt') |
            Should -BeTrue
    }

    It 'keeps published output when staged validation fails' {
        Mock Invoke-GitClone {
            param($Repository, $Destination)
            New-TestRepository -Destination $Destination -Version '1.0.0'
            Set-Content -LiteralPath (Join-Path $Destination 'bucket\sample.json') -Value '{"url":"relative/file.zip"}'
        }

        { Invoke-Entry -Context (New-TestContext) -Root $script:Root } |
            Should -Throw '*non-absolute URL*'
        Test-Path -LiteralPath (Join-Path $script:Root 'bucket\existing.txt') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:Root 'bucket\sample.json') |
            Should -BeFalse
    }

    It 'uses repository order as the explicit collision priority' {
        Mock Invoke-GitClone {
            param($Repository, $Destination)
            $version = if ($Repository -eq 'owner/first') { '1.0.0' } else { '2.0.0' }
            New-TestRepository -Destination $Destination -Version $version
        }

        $context = New-TestContext -Repositories @('owner/first', 'owner/second')
        $result = Invoke-Entry -Context $context -Root $script:Root -WarningAction SilentlyContinue
        $manifest = Get-Content -LiteralPath (Join-Path $script:Root 'bucket\sample.json') -Raw |
            ConvertFrom-Json

        $result.CollisionCount | Should -Be 1
        $manifest.version | Should -Be '2.0.0'
    }

    It 'renames post-processed manifests instead of publishing both names' {
        Mock Invoke-GitClone {
            param($Repository, $Destination)
            New-TestRepository -Destination $Destination -Version '1.0.0' -ManifestName '.json'
        }

        $context = New-TestContext
        $context.postprocess = @(
            @{
                action = 'rename'
                from = '.json'
                to = 'wishlist.json'
                enabled = $true
            }
        )
        $null = Invoke-Entry -Context $context -Root $script:Root

        Test-Path -LiteralPath (Join-Path $script:Root 'bucket\.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:Root 'bucket\wishlist.json') |
            Should -BeTrue
    }
}
