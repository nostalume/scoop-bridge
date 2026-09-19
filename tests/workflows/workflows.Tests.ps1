#Requires -Module Pester

BeforeAll {
    $workflowsDirectory = Join-Path (Join-Path (Join-Path $PSScriptRoot '..') '..') '.github'
    $script:WorkflowsDirectory = Join-Path $workflowsDirectory 'workflows'
    $script:AutoUpdate = Get-Content -Raw (Join-Path $script:WorkflowsDirectory 'auto-update.yml')
    $script:Codeberg = Get-Content -Raw (Join-Path $script:WorkflowsDirectory 'codeberg.yml')
    $script:Verify = Get-Content -Raw (Join-Path $script:WorkflowsDirectory 'verify.yml')
}

Describe 'Workflow security and responsibilities' {
    It 'keeps generated updates off the push trigger' {
        $eventSection = $script:AutoUpdate -split 'permissions:', 2 | Select-Object -First 1
        $eventSection | Should -Not -Match '(?m)^\s+push:'
        $eventSection | Should -Match '(?m)^\s+schedule:'
        $eventSection | Should -Match '(?m)^\s+workflow_dispatch:'
    }

    It 'stages only generated output' {
        $script:AutoUpdate | Should -Match 'git add -- bucket scripts'
        $script:AutoUpdate | Should -Not -Match 'git add --all'
    }

    It 'does not use force push' {
        $script:AutoUpdate | Should -Not -Match 'git\s+push\s+(-f|--force)'
    }

    It 'gives only the update job write permission' {
        $script:AutoUpdate | Should -Match '(?ms)permissions:\s+contents: write'
        $script:Codeberg | Should -Match '(?ms)permissions:\s+contents: read'
        $script:Verify | Should -Match '(?ms)permissions:\s+contents: read'
    }

    It 'pins third-party actions to commit SHAs' {
        foreach ($content in @($script:AutoUpdate, $script:Codeberg, $script:Verify)) {
            $content | Should -Not -Match 'uses:\s+[^\s]+@(main|master|v\d+(\.\d+){0,2})\s*$'
        }
    }

    It 'does not disable SSH host verification' {
        $script:Codeberg | Should -Not -Match 'GIT_SSH_NO_VERIFY_HOST'
    }

    It 'verifies Windows PowerShell and PowerShell 7 on pushes and pull requests' {
        $script:Verify | Should -Match '(?m)^\s+push:'
        $script:Verify | Should -Match '(?m)^\s+pull_request:'
        $script:Verify | Should -Match '(?m)^\s+- powershell$'
        $script:Verify | Should -Match '(?m)^\s+- pwsh$'
    }

    It 'mirrors only after a push' {
        $eventSection = $script:Codeberg -split 'permissions:', 2 | Select-Object -First 1
        $eventSection | Should -Match '(?m)^\s+push:'
        $eventSection | Should -Not -Match '(?m)^\s+schedule:'
    }
}
