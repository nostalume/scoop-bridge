#Requires -Module Pester

BeforeAll {
    . (Join-Path (Join-Path $PSScriptRoot '..') 'installer.ps1')
}

Describe 'Invoke-ScoopBridgeSetup' {
    BeforeEach {
        Mock Get-ExecutionPolicy { 'RemoteSigned' }
        Mock Test-IsAdministrator { $false }
        Mock Install-Scoop {}
        Mock Set-ScoopConfiguration {}
        Mock Set-ScoopBridgeBucket {}
        Mock Update-InstalledAppBucketReferences { 0 }
        Mock Write-Status {}
    }

    It 'reconfigures an existing installation only after confirmation' {
        Mock Get-Command { [PSCustomObject]@{ Name = 'scoop' } }
        Mock Read-YesNo { $true }

        Invoke-ScoopBridgeSetup -Destination 'C:\Scoop' -BucketName 'spc' -ViaProxy $true

        Should -Invoke Install-Scoop -Times 0
        Should -Invoke Set-ScoopConfiguration -Times 1
        Should -Invoke Set-ScoopBridgeBucket -Times 1
    }

    It 'leaves an existing installation unchanged when confirmation is declined' {
        Mock Get-Command { [PSCustomObject]@{ Name = 'scoop' } }
        Mock Read-YesNo { $false }

        Invoke-ScoopBridgeSetup -Destination 'C:\Scoop' -BucketName 'spc' -ViaProxy $false

        Should -Invoke Install-Scoop -Times 0
        Should -Invoke Set-ScoopConfiguration -Times 0
        Should -Invoke Set-ScoopBridgeBucket -Times 0
    }

    It 'passes the requested destination to a new Scoop installation' {
        Mock Get-Command { $null }

        Invoke-ScoopBridgeSetup -Destination 'D:\Applications\Scoop' -BucketName 'spc' -ViaProxy $false

        Should -Invoke Install-Scoop -Times 1 -ParameterFilter {
            $Destination -eq 'D:\Applications\Scoop'
        }
    }

    It 'does not migrate installed apps unless explicitly requested' {
        Mock Get-Command { $null }

        Invoke-ScoopBridgeSetup -Destination 'C:\Scoop' -BucketName 'spc' -ViaProxy $false

        Should -Invoke Update-InstalledAppBucketReferences -Times 0
    }
}

Describe 'Update-InstalledAppBucketReferences' {
    BeforeEach {
        $script:ScoopRoot = Join-Path $TestDrive 'scoop'
        if (Test-Path -LiteralPath $script:ScoopRoot) {
            Remove-Item -LiteralPath $script:ScoopRoot -Recurse -Force
        }
        $script:AppDirectory = Join-Path $script:ScoopRoot 'apps\sample\current'
        $null = New-Item -ItemType Directory -Path $script:AppDirectory -Force
        $script:InstallJson = Join-Path $script:AppDirectory 'install.json'
        [System.IO.File]::WriteAllText(
            $script:InstallJson,
            '{"bucket":"main","architecture":"64bit"}',
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    It 'creates a backup and writes UTF-8 without BOM' {
        Update-InstalledAppBucketReferences -Destination $script:ScoopRoot -BucketName 'spc' |
            Should -Be 1

        Test-Path -LiteralPath "$script:InstallJson.scoopbridge.bak" | Should -BeTrue
        ([System.IO.File]::ReadAllText($script:InstallJson) | ConvertFrom-Json).bucket |
            Should -Be 'spc'
        $bytes = [System.IO.File]::ReadAllBytes($script:InstallJson)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) |
            Should -BeFalse
    }

    It 'supports a mutation-free preview' {
        $before = [System.IO.File]::ReadAllText($script:InstallJson)

        Update-InstalledAppBucketReferences -Destination $script:ScoopRoot -BucketName 'spc' -WhatIf |
            Should -Be 0

        [System.IO.File]::ReadAllText($script:InstallJson) | Should -Be $before
        Test-Path -LiteralPath "$script:InstallJson.scoopbridge.bak" | Should -BeFalse
    }
}

Describe 'Set-ScoopBridgeBucket' {
    It 'updates an existing bucket in place instead of removing it' {
        $scoopRoot = Join-Path $TestDrive 'scoop'
        $bucketPath = Join-Path $scoopRoot 'buckets\spc'
        $null = New-Item -ItemType Directory -Path (Join-Path $bucketPath '.git') -Force
        Mock git {}
        Mock scoop {}
        Mock Assert-NativeCommandSucceeded {}
        Mock Write-Status {}

        Set-ScoopBridgeBucket -Destination $scoopRoot -Name 'spc' -ViaProxy $false

        Should -Invoke git -Times 2
    }
}
