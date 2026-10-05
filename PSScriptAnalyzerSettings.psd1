@{
    Severity     = @('Error', 'Warning')

    # Workflow-style rules that don't fit this project:
    # - PSUseShouldProcessForStateChangingFunctions: no function here changes state; the one script
    #   that does (Grant-GraphAppRole.ps1) supports -WhatIf.
    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.2')
        }
    }
}
