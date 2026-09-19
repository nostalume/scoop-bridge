# Configuration Guide

This document describes the configuration system for ScoopBridge.

## Overview

The configuration is defined in [`bin/config.ps1`](../bin/config.ps1) as a PowerShell hashtable containing four main sections:

1. **Repositories** - Upstream bucket sources
2. **Proxies** - Mirror/proxy URL definitions
3. **Rules** - URL replacement patterns
4. **Postprocess** - Explicit file operations performed before validation

## Repositories

The `repositories` array lists the GitHub repositories to aggregate:

```powershell
repositories = @(
    "ScoopInstaller/Main",
    "ScoopInstaller/Extras",
    "ScoopInstaller/Versions",
    # ... more repos
)
```

Each repository is cloned into an isolated workspace. Manifests are aggregated,
rewritten, and validated there before the generated `bucket/` and `scripts/`
directories replace the currently published output.

## Proxies

The `proxies` hashtable defines named proxy/mirror URLs:

```powershell
proxies = @{
    Github   = "https://gh-proxy.org"
    Tsinghua = "mirrors.tuna.tsinghua.edu.cn"
    Nju      = "mirrors.nju.edu.cn"
    Ustc     = "mirrors.ustc.edu.cn"
}
```

These variables are referenced in replacement rules using `${VariableName}` syntax.

## Rules

Rules define regex-based URL replacements. Each rule is a hashtable with:

| Property | Description | Example |
|----------|-------------|---------|
| `description` | Human-readable description | `"Proxy: GitHub Releases"` |
| `find` | Regex pattern to match | `'(https?://github\.com/.+/releases/.*download)'` |
| `replace` | Replacement string with variables | `'${Github}/$1'` |
| `enabled` | Whether rule is active | `$true` or `$false` |

### Rule Syntax

- Use PowerShell regex syntax for `find` patterns
- Use `$1`, `$2`, etc. to reference capture groups
- Use `${VariableName}` to reference proxy variables

### Example Rules

**GitHub Releases Proxy:**

```powershell
@{
    description = "Proxy: GitHub Releases Download"
    find        = '(https?://github\.com/.+/releases/.*download)'
    replace     = '${Github}/$1'
    enabled     = $true
}
```

**Mirror Replacement:**

```powershell
@{
    description = "Mirror: Blender"
    find        = 'download\.blender\.org'
    replace     = '${Tsinghua}/blender'
    enabled     = $true
}
```

## Adding New Rules

1. Edit `bin/config.ps1`
2. Add a new hashtable to the `rules` array
3. Test your regex pattern before deploying
4. Set `enabled = $true` to activate

### Testing Regex Patterns

Test your patterns in PowerShell:

```powershell
$pattern = 'https?://example\.com/(.+)'
$testUrl = 'https://example.com/path/to/file'
$testUrl -match $pattern  # Should return True
$matches[1]  # Should contain 'path/to/file'
```

## Rule Priority

Rules are applied in order, so a later rule sees the output produced by earlier rules.

## Post-processing

Post-processing is reserved for explicit file operations that cannot be expressed
as URL replacements. The current `rename` action moves a staged manifest to its
published name; it does not leave both names in the bucket.

## Disabling Rules

Set `enabled = $false` to disable a rule without removing it:

```powershell
@{
    description = "Disabled rule example"
    find        = 'pattern'
    replace     = 'replacement'
    enabled     = $false
}
```

## Best Practices

1. **Be specific with regex** - Avoid overly broad patterns
2. **Test thoroughly** - Test with real manifest URLs
3. **Document purpose** - Use clear descriptions
4. **Handle edge cases** - Consider version numbers, file extensions
5. **Validate JSON** - Ensure replacements produce valid JSON
