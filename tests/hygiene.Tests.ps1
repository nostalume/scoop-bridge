#Requires -Module Pester

Describe 'Tracked text line endings' {
    It 'stores every text source with LF in the index' {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $listing = git -C $root ls-files --eol -- '*.ps1' '*.psm1' '*.psd1' '*.json' '*.yml' '*.yaml' '*.md'
        if ($LASTEXITCODE -ne 0) {
            throw "git ls-files --eol failed with exit code $LASTEXITCODE"
        }

        $offenders = @(
            foreach ($entry in $listing) {
                if ($entry -notmatch '^i/lf\s') { ($entry -split "`t")[-1] }
            }
        )

        $offenders | Should -BeEmpty -Because "CRLF in the index makes Git skip normalization: $($offenders -join ', ')"
    }
}
