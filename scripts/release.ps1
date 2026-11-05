#requires -Version 7.5
<#
.SYNOPSIS
  Update Cargo manifests and publish an annotated release tag.
.EXAMPLE
  .\scripts\release.ps1 0.1.7
#>
[CmdletBinding()]
param([Parameter(Mandatory, Position = 0)][string]$Version)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Version = $Version -replace '^v', ''
if ($Version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
    throw 'release version must be MAJOR.MINOR.PATCH'
}
if (git status --porcelain) { throw 'release requires a clean working tree' }
$branch = (git branch --show-current).Trim()
if ($branch -ne 'main') { throw 'release must run from the main branch' }
if (git tag --list "v$Version") { throw "tag v$Version already exists" }

$patterns = [ordered]@{
    'Cargo.toml' = '(?m)^(version[ \t]*=[ \t]*")[^"]+("[ \t]*\r?)$'
    'Cargo.lock' = '(?ms)(\[\[package\]\][ \t]*\r?\nname = "shed"[ \t]*\r?\nversion = ")[^"]+("[ \t]*)'
}
$updates = [ordered]@{}
foreach ($entry in $patterns.GetEnumerator()) {
    $path = Join-Path (Get-Location) $entry.Key
    $text = [IO.File]::ReadAllText($path)
    $pattern = [regex]::new($entry.Value)
    if ($pattern.Matches($text).Count -ne 1) { throw "expected one package version in $($entry.Key)" }
    $updates[$path] = $pattern.Replace($text, { param($m) $m.Groups[1].Value + $Version + $m.Groups[2].Value })
}
foreach ($entry in $updates.GetEnumerator()) {
    [IO.File]::WriteAllText($entry.Key, $entry.Value, [Text.UTF8Encoding]::new($false))
}

cargo check --locked
git add Cargo.toml Cargo.lock
$PSNativeCommandUseErrorActionPreference = $false
git diff --cached --quiet
if ($LASTEXITCODE -gt 1) { throw 'git diff failed' }
$changed = $LASTEXITCODE -eq 1
$PSNativeCommandUseErrorActionPreference = $true
if ($changed) { git commit -m "chore: release v$Version" }
git tag -a "v$Version" -m "Release v$Version"
git push --atomic origin "HEAD:$branch" "v$Version"
Write-Host "released v$Version"
