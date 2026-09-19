# Contributing to ScoopBridge

Thank you for your interest in contributing to ScoopBridge. This document provides guidelines for contributing.

## Types of Contributions

- **New Mirror Rules** - Add URL replacement rules for new packages
- **Bug Fixes** - Fix issues with existing rules or code
- **Documentation** - Improve docs, add examples
- **Tests** - Add test coverage

## Adding New Mirror Rules

### When to Add a Rule

Add a rule when:

- A package downloads from a URL that needs proxy/mirror replacement
- The URL is not already covered by existing rules
- The package is in one of the aggregated buckets

### How to Add a Rule

1. **Identify the pattern**: Find the URL pattern in the original manifest
2. **Create the regex**: Write a regex that matches the pattern
3. **Define the replacement**: Determine the mirror URL
4. **Add to config.ps1**: Insert the rule in the appropriate section
5. **Test**: Verify the rule works with real manifests

### Rule Template

```powershell
@{
    description = "Mirror/Purpose: Package Name"
    find        = 'regex-pattern-here'
    replace     = '${ProxyVariable}/replacement'
    enabled     = $true
}
```

### Testing Your Rule

Create a test manifest and run the replacement:

```powershell
# Test your regex
$pattern = 'your-regex-here'
$testUrl = 'https://example.com/path/to/file'
$testUrl -match $pattern

# Test the full aggregation without publishing generated files
.\bin\auto-update.ps1 -DryRun
```

## Code Style

### PowerShell

- Use 4 spaces for indentation
- Use PascalCase for function names
- Use camelCase for variables
- Prefer direct PowerShell functions, hashtables, and `[PSCustomObject]` values
- Add `[CmdletBinding()]` only when advanced-function behavior is required
- Check `$LASTEXITCODE` after native commands
- Use `$null` checks, not `$var -eq $null`

### YAML (Workflows)

- Use 2 spaces for indentation
- Quote string values
- Keep lines under 100 characters

## Commit Messages

Follow conventional commits:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `test:` - Tests
- `chore:` - Maintenance

Examples:

```text
feat(rules): add mirror for ExamplePackage
fix(lib): handle edge case in URL replacement
docs: update configuration guide
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests
5. Update documentation
6. Submit PR with clear description

## Testing

Run the test suite before submitting:

```powershell
.\tests\Run-Tests.ps1
```

All tests must pass.

## Questions?

- Check existing issues first
- Create a new issue for discussion
- Join community discussions

## Code of Conduct

- Be respectful
- Be constructive
- Help others learn
- Focus on the work, not the person
