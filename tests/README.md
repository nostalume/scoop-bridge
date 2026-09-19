# ScoopBridge Test Suite

This directory contains the Pester-based test suite for ScoopBridge.

## Running Tests

```powershell
# Run all tests
.\tests\Run-Tests.ps1

# Run specific test file
.\tests\Run-Tests.ps1 -TestPath .\tests\lib.Tests.ps1

# Run with verbose output
.\tests\Run-Tests.ps1 -VerboseOutput
```

## Test Structure

- `lib.Tests.ps1` - Tests for bin/lib.ps1 functions
- `config.Tests.ps1` - Tests for bin/config.ps1 rules
- `installer.Tests.ps1` - Tests for safe installation and migration behavior
- `workflows/` - Workflow validation tests
