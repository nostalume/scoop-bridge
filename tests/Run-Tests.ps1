#Requires -Version 5.1

<#
.SYNOPSIS
    Test runner for the ScoopBridge test suite
.DESCRIPTION
    Runs all Pester tests for ScoopBridge
#>

param(
    [switch]$VerboseOutput,
    [string]$TestPath = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$pester = Get-Module -Name Pester |
    Where-Object { $_.Version -ge [version]'5.0.0' } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -eq $pester) {
    $pester = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version -ge [version]'5.0.0' } |
    Sort-Object Version -Descending |
    Select-Object -First 1
}

if ($null -eq $pester) {
    throw 'Pester 5.0 or later is required. Install it before running the test suite.'
}

if (-not (Get-Module -Name Pester | Where-Object { $_.Version -eq $pester.Version })) {
    Import-Module $pester.Path -Force
}

# Configure Pester
$config = New-PesterConfiguration
$config.Run.Path = $TestPath
$config.Run.PassThru = $true
$config.Output.Verbosity = if ($VerboseOutput) { 'Detailed' } else { 'Normal' }

# Run tests
Write-Host 'Running ScoopBridge tests...' -ForegroundColor Cyan
$results = Invoke-Pester -Configuration $config

if ($null -eq $results) {
    throw 'Pester did not return a test result.'
}

exit $results.FailedCount
