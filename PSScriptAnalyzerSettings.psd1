# Shared PSScriptAnalyzer settings. CI fails on Error severity; Warnings are reported only.
# Local: Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Detection scripts must write to STDOUT for Intune; Write-Host is common in older scripts.
        'PSAvoidUsingWriteHost'
        # Legacy helper names (Test-FilePaths) are kept for backwards compatibility.
        'PSUseSingularNouns'
    )
    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            # Intune runs Windows PowerShell 5.1 by default.
            TargetVersions = @('5.1', '7.0')
        }
    }
}
