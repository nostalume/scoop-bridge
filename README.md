<div align="center">

# ScoopBridge

**[中文](README-cn.md) | [English](README.md)**

[![Verify](https://github.com/nostalume/scoop-bridge/actions/workflows/verify.yml/badge.svg)](https://github.com/nostalume/scoop-bridge/actions/workflows/verify.yml)
[![Auto Update](https://github.com/nostalume/scoop-bridge/actions/workflows/auto-update.yml/badge.svg)](https://github.com/nostalume/scoop-bridge/actions/workflows/auto-update.yml)

</div>

ScoopBridge aggregates widely used Scoop buckets and rewrites selected download
URLs to mirror-aware routes. It is intended for users whose access to upstream
package hosts is slow or unreliable. The compatible local bucket alias remains
`spc`.

## Features

- Aggregates `main`, `extras`, `versions`, `nirsoft`, `sysinternals`, `php`,
  `nerd-fonts`, `nonportable`, `java`, `games`, `charmbracelet`, `winspec`,
  `spx`, and `shed`.
- Refreshes generated manifests every four hours.
- Builds in a staging directory and publishes only validated JSON manifests.
- Keeps an existing bucket checkout and updates its remote in place.
- Migrates installed-app metadata only when explicitly requested, with backups.

## Quick start

If Scoop is already installed:

```powershell
scoop bucket add spc https://gh-proxy.org/https://github.com/nostalume/scoop-bridge
scoop install spc/<package-name>
```

To install or configure ScoopBridge with the bundled installer:

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nostalume/scoop-bridge/main/installer.ps1' -OutFile "$env:TEMP\scoop-bridge.ps1"
& "$env:TEMP\scoop-bridge.ps1" -UseProxy
```

Use direct upstream routes with `-UseProxy:$false`. The installer prompts when
the option is omitted.

### Installer options

| Parameter | Purpose | Default |
| --- | --- | --- |
| `-UseProxy` | Use mirror-aware routes | Prompt |
| `-ScoopDir` | Scoop installation directory | `$env:USERPROFILE\scoop` |
| `-BucketName` | Local ScoopBridge alias | `spc` |
| `-MigrateInstalledApps` | Migrate supported bucket references and retain backups | Off |
| `-WhatIf` | Preview installer changes | Off |

Preview an explicit migration before applying it:

```powershell
& "$env:TEMP\scoop-bridge.ps1" -UseProxy -MigrateInstalledApps -WhatIf
& "$env:TEMP\scoop-bridge.ps1" -UseProxy -MigrateInstalledApps
```

## Development

URL replacement rules live in [`bin/config.ps1`](bin/config.ps1); their format
is documented in [`docs/configuration.md`](docs/configuration.md).

```powershell
# Run the test suite (requires Pester 5 or newer)
.\tests\Run-Tests.ps1

# Exercise the complete aggregation without publishing generated output
.\bin\auto-update.ps1 -DryRun
```

See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change.

## License

ScoopBridge is available under the [MIT License](LICENSE).
