Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:BinRoot = $PSScriptRoot
$Script:Root = (Get-Item $PSScriptRoot).Parent.FullName
$Script:ConfigFile = Join-Path $Script:BinRoot 'config.ps1'

if (-not (Test-Path -LiteralPath $Script:ConfigFile -PathType Leaf)) {
    throw "Configuration file not found: $Script:ConfigFile"
}

$Script:Context = & $Script:ConfigFile

function Expand-Variables {
    param(
        [string]$Text,
        [hashtable]$Variables
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or $null -eq $Variables) {
        return $Text
    }

    $seen = @{}
    while ($true) {
        if ($seen.ContainsKey($Text)) {
            throw "Variable expansion contains a cycle: $Text"
        }

        $seen[$Text] = $true
        $expanded = $Text

        foreach ($name in $Variables.Keys) {
            $pattern = '\$\{' + [regex]::Escape($name) + '\}'
            $expanded = $expanded -replace $pattern, $Variables[$name]
        }

        if ($expanded -eq $Text) {
            foreach ($name in $Variables.Keys) {
                if ($expanded -match ('\$\{' + [regex]::Escape($name) + '\}')) {
                    throw "Variable expansion contains a cycle involving '$name'."
                }
            }

            return $expanded
        }

        $Text = $expanded
    }
}

function Get-ManifestUrls {
    param([AllowNull()]$InputObject)

    if ($null -eq $InputObject -or $InputObject -is [string]) {
        return
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and
        $InputObject -isnot [System.Management.Automation.PSCustomObject]) {
        foreach ($item in $InputObject) {
            Get-ManifestUrls -InputObject $item
        }
        return
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.Name -eq 'url') {
            foreach ($url in @($property.Value)) {
                if ($url -is [string]) {
                    $url
                }
            }
        }

        Get-ManifestUrls -InputObject $property.Value
    }
}

function Test-ManifestContent {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Source
    )

    try {
        $manifest = ConvertFrom-Json -InputObject $Content -ErrorAction Stop
    } catch {
        throw "Invalid JSON in '$Source': $($_.Exception.Message)"
    }

    foreach ($url in Get-ManifestUrls -InputObject $manifest) {
        $candidate = $url.Trim()
        if ($candidate -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://' -and $candidate -notmatch '^\$[a-zA-Z]') {
            throw "Manifest '$Source' contains a non-absolute URL: $url"
        }
    }
}

function Test-GeneratedOutput {
    param([Parameter(Mandatory)][string]$OutputRoot)

    $bucketDirectory = Join-Path $OutputRoot 'bucket'
    $manifests = @(Get-ChildItem -LiteralPath $bucketDirectory -Filter '*.json' -File -Recurse)

    if ($manifests.Count -eq 0) {
        throw "Generated bucket is empty: $bucketDirectory"
    }

    foreach ($manifest in $manifests) {
        $content = [System.IO.File]::ReadAllText($manifest.FullName)
        Test-ManifestContent -Content $content -Source $manifest.FullName
    }

    [PSCustomObject]@{
        ManifestCount = $manifests.Count
    }
}

function Update-Manifest {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$Manifest,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Rules
    )

    $content = [System.IO.File]::ReadAllText($Manifest.FullName)
    $updated = $content

    foreach ($rule in $Rules) {
        if ($updated -match $rule.find) {
            Write-Verbose "[$($Manifest.Name)] Applying rule: $($rule.description)"
            $updated = $updated -replace $rule.find, $rule.replace
        }
    }

    if ($updated -eq $content) {
        return $false
    }

    Test-ManifestContent -Content $updated -Source $Manifest.FullName
    [System.IO.File]::WriteAllText(
        $Manifest.FullName,
        $updated,
        [System.Text.UTF8Encoding]::new($false)
    )
    return $true
}

function Invoke-GitClone {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$Destination
    )

    $url = "https://github.com/$Repository.git"
    & git clone --depth 1 --quiet $url $Destination

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone '$Repository' (git exit code $LASTEXITCODE)."
    }
}

function Copy-RepositoryContent {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][hashtable]$Provenance,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.ArrayList]$Collisions
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        return
    }

    $sourcePrefix = (Get-Item -LiteralPath $Source).FullName
    foreach ($file in Get-ChildItem -LiteralPath $Source -File -Recurse) {
        $relativePath = $file.FullName.Substring($sourcePrefix.Length)
        $relativePath = $relativePath.TrimStart([char]'\', [char]'/')
        $target = Join-Path $Destination $relativePath
        $targetDirectory = Split-Path -Parent $target

        if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $targetDirectory -Force
        }

        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $null = $Collisions.Add([PSCustomObject]@{
                Path     = $relativePath
                Previous = $Provenance[$relativePath]
                Current  = $Repository
            })
        }

        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        $Provenance[$relativePath] = $Repository
    }
}

function Invoke-BucketAggregation {
    param(
        [Parameter(Mandatory)][string[]]$Repositories,
        [Parameter(Mandatory)][string]$Workspace
    )

    $repositoriesRoot = Join-Path $Workspace 'repositories'
    $outputRoot = Join-Path $Workspace 'output'
    $bucketDirectory = Join-Path $outputRoot 'bucket'
    $scriptsDirectory = Join-Path $outputRoot 'scripts'

    $null = New-Item -ItemType Directory -Path $repositoriesRoot -Force
    $null = New-Item -ItemType Directory -Path $bucketDirectory -Force
    $null = New-Item -ItemType Directory -Path $scriptsDirectory -Force

    $provenance = @{}
    $scriptProvenance = @{}
    $collisions = [System.Collections.ArrayList]::new()
    $clones = @{}
    $index = 0

    Write-Host "Acquiring $($Repositories.Count) upstream repositories..." -ForegroundColor Cyan

    foreach ($repository in $Repositories) {
        $index++
        $repositoryName = $repository.Split('/')[-1]
        $cloneName = '{0:D2}-{1}' -f $index, $repositoryName
        $clonePath = Join-Path $repositoriesRoot $cloneName

        Write-Host "  $repository"
        Invoke-GitClone -Repository $repository -Destination $clonePath
        $clones[$repository] = $clonePath

        $sourceBucket = Join-Path $clonePath 'bucket'
        if (Test-Path -LiteralPath $sourceBucket -PathType Container) {
            Copy-RepositoryContent -Source $sourceBucket -Destination $bucketDirectory -Repository $repository -Provenance $provenance -Collisions $collisions
        } else {
            $rootManifests = @(Get-ChildItem -LiteralPath $clonePath -Filter '*.json' -File)
            foreach ($manifest in $rootManifests) {
                $target = Join-Path $bucketDirectory $manifest.Name
                if (Test-Path -LiteralPath $target -PathType Leaf) {
                    $null = $collisions.Add([PSCustomObject]@{
                        Path     = $manifest.Name
                        Previous = $provenance[$manifest.Name]
                        Current  = $repository
                    })
                }
                Copy-Item -LiteralPath $manifest.FullName -Destination $target -Force
                $provenance[$manifest.Name] = $repository
            }
        }

        Copy-RepositoryContent -Source (Join-Path $clonePath 'scripts') -Destination $scriptsDirectory -Repository $repository -Provenance $scriptProvenance -Collisions $collisions
    }

    foreach ($collision in $collisions) {
        Write-Warning "Collision '$($collision.Path)': $($collision.Previous) -> $($collision.Current)"
    }

    [PSCustomObject]@{
        OutputRoot = $outputRoot
        Clones = $clones
        Collisions = @($collisions)
    }
}

function Invoke-PostProcess {
    param(
        [array]$Actions,
        [Parameter(Mandatory)][string]$BucketDirectory
    )

    foreach ($action in @($Actions)) {
        if (-not $action.enabled) {
            continue
        }

        if ($action.action -ne 'rename') {
            throw "Unsupported post-process action: $($action.action)"
        }

        $source = Join-Path $BucketDirectory $action.from
        $destination = Join-Path $BucketDirectory $action.to

        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Post-process source not found: $source"
        }

        Move-Item -LiteralPath $source -Destination $destination -Force
    }
}

function Invoke-Replacement {
    param(
        [Parameter(Mandatory)][string]$BucketDirectory,
        [array]$Rules,
        [hashtable]$Variables
    )

    $expandedRules = @(
        foreach ($rule in @($Rules)) {
            if ($rule.enabled) {
                [PSCustomObject]@{
                    description = $rule.description
                    find = $rule.find
                    replace = Expand-Variables -Text $rule.replace -Variables $Variables
                }
            }
        }
    )

    $changedCount = 0
    foreach ($manifest in Get-ChildItem -LiteralPath $BucketDirectory -Filter '*.json' -File -Recurse) {
        if (Update-Manifest -Manifest $manifest -Rules $expandedRules) {
            $changedCount++
        }
    }

    return $changedCount
}

function Publish-GeneratedOutput {
    param(
        [Parameter(Mandatory)][string]$GeneratedRoot,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$Workspace
    )

    $backupRoot = Join-Path $Workspace 'previous'
    $null = New-Item -ItemType Directory -Path $backupRoot -Force
    $published = [System.Collections.ArrayList]::new()

    try {
        foreach ($name in @('bucket', 'scripts')) {
            $current = Join-Path $DestinationRoot $name
            if (Test-Path -LiteralPath $current) {
                Move-Item -LiteralPath $current -Destination (Join-Path $backupRoot $name)
            }
        }

        foreach ($name in @('bucket', 'scripts')) {
            $staged = Join-Path $GeneratedRoot $name
            $destination = Join-Path $DestinationRoot $name
            Move-Item -LiteralPath $staged -Destination $destination
            $null = $published.Add($destination)
        }
    } catch {
        foreach ($path in $published) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }

        foreach ($name in @('bucket', 'scripts')) {
            $backup = Join-Path $backupRoot $name
            $destination = Join-Path $DestinationRoot $name
            if (Test-Path -LiteralPath $backup) {
                Move-Item -LiteralPath $backup -Destination $destination
            }
        }

        throw
    }
}

function Invoke-Entry {
    param(
        [switch]$DryRun,
        [hashtable]$Context = $Script:Context,
        [string]$Root = $Script:Root
    )

    $workspaceName = '.scoopbridge-work-{0}' -f [guid]::NewGuid().ToString('N')
    $workspace = Join-Path $Root $workspaceName
    $null = New-Item -ItemType Directory -Path $workspace

    try {
        $aggregation = Invoke-BucketAggregation -Repositories $Context.repositories -Workspace $workspace
        $bucketDirectory = Join-Path $aggregation.OutputRoot 'bucket'
        Invoke-PostProcess -Actions $Context.postprocess -BucketDirectory $bucketDirectory
        $changedCount = Invoke-Replacement -BucketDirectory $bucketDirectory -Rules $Context.rules -Variables $Context.proxies
        $validation = Test-GeneratedOutput -OutputRoot $aggregation.OutputRoot

        if (-not $DryRun) {
            Publish-GeneratedOutput -GeneratedRoot $aggregation.OutputRoot -DestinationRoot $Root -Workspace $workspace
        }

        [PSCustomObject]@{
            DryRun = [bool]$DryRun
            ManifestCount = $validation.ManifestCount
            ChangedCount = $changedCount
            CollisionCount = $aggregation.Collisions.Count
        }
    } finally {
        if (Test-Path -LiteralPath $workspace) {
            Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
