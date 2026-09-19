#Requires -Version 5.1

<#
.SYNOPSIS
    Installs and configures ScoopBridge.
.DESCRIPTION
    Installs Scoop when needed, configures a mirror-aware Scoop repository, and
    adds the ScoopBridge bucket. Existing app metadata is migrated only when
    -MigrateInstalledApps is explicitly supplied.
.PARAMETER UseProxy
    Downloads the official Scoop installer and repositories through configured
    mirrors. When omitted, the script asks interactively.
.PARAMETER ScoopDir
    Scoop installation directory.
.PARAMETER BucketName
    Local alias for the ScoopBridge bucket. The compatible default is spc.
.PARAMETER MigrateInstalledApps
    Rewrites supported installed-app bucket references after creating backups.
.EXAMPLE
    .\installer.ps1 -UseProxy -BucketName spc
.EXAMPLE
    .\installer.ps1 -UseProxy -MigrateInstalledApps -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$UseProxy,
    [string]$ScoopDir = "$env:USERPROFILE\scoop",
    [string]$BucketName = 'spc',
    [switch]$MigrateInstalledApps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Status {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Read-YesNo {
    param([Parameter(Mandatory)][string]$Question)

    (Read-Host $Question) -match '^[Yy]$'
}

function Assert-NativeCommandSucceeded {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [int]$ExitCode = $LASTEXITCODE
    )

    if ($ExitCode -ne 0) {
        throw "$Operation failed with exit code $ExitCode."
    }
}

function Install-Scoop {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [bool]$ViaProxy
    )

    $officialUrl = 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1'
    $installerUrl = if ($ViaProxy) {
        "https://gh-proxy.org/$officialUrl"
    } else {
        $officialUrl
    }
    $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) "scoop-install-$([guid]::NewGuid().ToString('N')).ps1"

    Write-Status "Downloading the official Scoop installer from $installerUrl" Cyan
    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        & $installerPath -ScoopDir $Destination
        if (-not $?) {
            throw 'Scoop installation failed.'
        }
    } finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

function Set-ScoopConfiguration {
    param([bool]$ViaProxy)

    $repository = if ($ViaProxy) {
        'https://gitee.com/scoop-installer/scoop'
    } else {
        'https://github.com/ScoopInstaller/Scoop'
    }

    & scoop config SCOOP_REPO $repository
    Assert-NativeCommandSucceeded -Operation 'Scoop repository configuration'
}

function Set-ScoopBridgeBucket {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Name,
        [bool]$ViaProxy
    )

    if ($Name -notmatch '^[a-zA-Z0-9._-]+$') {
        throw "Invalid bucket name: $Name"
    }

    $repositoryUrl = if ($ViaProxy) {
        'https://gh-proxy.org/https://github.com/nostalume/scoop-bridge'
    } else {
        'https://github.com/nostalume/scoop-bridge'
    }
    $bucketPath = Join-Path (Join-Path $Destination 'buckets') $Name

    if (Test-Path -LiteralPath $bucketPath -PathType Container) {
        if (-not (Test-Path -LiteralPath (Join-Path $bucketPath '.git') -PathType Container)) {
            throw "Existing bucket path is not a Git repository: $bucketPath"
        }

        Write-Status "Updating bucket '$Name' without removing it." Yellow
        & git -C $bucketPath remote set-url origin $repositoryUrl
        Assert-NativeCommandSucceeded -Operation "Updating bucket '$Name' remote"
        & git -C $bucketPath fetch --prune origin
        Assert-NativeCommandSucceeded -Operation "Fetching bucket '$Name'"
        return
    }

    & scoop bucket add $Name $repositoryUrl
    Assert-NativeCommandSucceeded -Operation "Adding bucket '$Name'"
}

function Update-InstalledAppBucketReferences {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$BucketName
    )

    $sourceBuckets = @(
        'main', 'extras', 'versions', 'nirsoft', 'sysinternals', 'php',
        'nerd-fonts', 'nonportable', 'java', 'games', 'scoop-bucket',
        'winspec', 'spx', 'shed'
    )
    $escapedNames = $sourceBuckets | ForEach-Object { [regex]::Escape($_) }
    $pattern = '"bucket"\s*:\s*"(' + ($escapedNames -join '|') + ')"'
    $appsDirectory = Join-Path $Destination 'apps'
    $updatedCount = 0

    foreach ($file in Get-ChildItem -LiteralPath $appsDirectory -Filter 'install.json' -File -Recurse -ErrorAction SilentlyContinue) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $updated = $content -replace $pattern, "`"bucket`": `"$BucketName`""

        if ($updated -eq $content -or -not $PSCmdlet.ShouldProcess($file.FullName, "Migrate bucket reference to '$BucketName'")) {
            continue
        }

        try {
            $null = ConvertFrom-Json -InputObject $updated -ErrorAction Stop
        } catch {
            throw "Migration would produce invalid JSON in '$($file.FullName)': $($_.Exception.Message)"
        }

        $backupPath = "$($file.FullName).scoopbridge.bak"
        if (Test-Path -LiteralPath $backupPath) {
            $backupPath = "$backupPath.$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
        }
        $temporaryPath = "$($file.FullName).scoopbridge.tmp"

        try {
            [System.IO.File]::WriteAllText(
                $temporaryPath,
                $updated,
                [System.Text.UTF8Encoding]::new($false)
            )
            [System.IO.File]::Replace($temporaryPath, $file.FullName, $backupPath, $true)
        } finally {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }

        $updatedCount++
    }

    return $updatedCount
}

function Invoke-ScoopBridgeSetup {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$BucketName,
        [bool]$ViaProxy,
        [switch]$MigrateInstalledApps
    )

    if ((Get-ExecutionPolicy) -eq 'Restricted') {
        throw "PowerShell execution policy is Restricted. Run 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser' explicitly, then retry."
    }

    if (Test-IsAdministrator) {
        Write-Status 'Running as Administrator is not recommended for Scoop.' Yellow
        if (-not (Read-YesNo -Question 'Continue anyway? (y/N)')) {
            return
        }
    }

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Status 'Scoop is already installed.' Yellow
        if (-not (Read-YesNo -Question 'Reconfigure the existing installation? (y/N)')) {
            return
        }
    } else {
        Install-Scoop -Destination $Destination -ViaProxy $ViaProxy
    }

    Set-ScoopConfiguration -ViaProxy $ViaProxy
    Set-ScoopBridgeBucket -Destination $Destination -Name $BucketName -ViaProxy $ViaProxy

    if ($MigrateInstalledApps) {
        $updatedCount = Update-InstalledAppBucketReferences -Destination $Destination -BucketName $BucketName
        Write-Status "Migrated $updatedCount installed app reference(s)." Green
    }

    Write-Host ''
    Write-Status 'ScoopBridge is ready.' Green
    Write-Status "  Bucket : $BucketName" Green
    Write-Status "  Root   : $Destination" Green
    Write-Status "  Proxy  : $ViaProxy" Green
    Write-Status "Use: scoop install $BucketName/<package>" Green
}

if ($MyInvocation.InvocationName -ne '.') {
    $useProxyValue = [bool]$UseProxy
    if (-not $PSBoundParameters.ContainsKey('UseProxy')) {
        $useProxyValue = Read-YesNo -Question 'Use mirror-aware download routes? (y/N)'
    }

    if ($PSCmdlet.ShouldProcess($ScoopDir, 'Install or configure ScoopBridge')) {
        Invoke-ScoopBridgeSetup -Destination $ScoopDir -BucketName $BucketName -ViaProxy $useProxyValue -MigrateInstalledApps:$MigrateInstalledApps
    }
}
