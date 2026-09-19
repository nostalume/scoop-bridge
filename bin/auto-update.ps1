param(
    [switch]$DryRun
)

. "$PSScriptRoot\lib.ps1"

Invoke-Entry -DryRun:$DryRun
