<#
.SYNOPSIS
    Syntax check + PSScriptAnalyzer for every tracked PowerShell file. Used by CI.
.EXAMPLE
    pwsh ./build/Invoke-Lint.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Push-Location $Root
try {
    $files = @(git ls-files -- '*.ps1' '*.psm1' '*.psd1')
    $gh = [bool]$env:GITHUB_ACTIONS

    # 1) Syntax
    $syntaxErrors = 0
    foreach ($file in $files) {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $file).Path, [ref]$tokens, [ref]$errors) | Out-Null
        foreach ($e in $errors) {
            $syntaxErrors++
            if ($gh) { Write-Output "::error file=$file,line=$($e.Extent.StartLineNumber)::$($e.Message)" }
            else { Write-Output "SYNTAX $($file):$($e.Extent.StartLineNumber) $($e.Message)" }
        }
    }
    Write-Output "Syntax: $($files.Count) files parsed, $syntaxErrors error(s)."

    # 2) PSScriptAnalyzer
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
    }
    Import-Module PSScriptAnalyzer
    $settings = Join-Path $Root 'PSScriptAnalyzerSettings.psd1'
    $errorsFound = 0; $warningsFound = 0
    foreach ($file in $files) {
        foreach ($r in @(Invoke-ScriptAnalyzer -Path $file -Settings $settings)) {
            $sev = "$($r.Severity)"
            if ($sev -eq 'Error' -or $sev -eq 'ParseError') { $errorsFound++; $level = 'error' } else { $warningsFound++; $level = 'warning' }
            if ($gh) { Write-Output "::$level file=$file,line=$($r.Line)::[$($r.RuleName)] $($r.Message)" }
            else { Write-Output ("{0,-7} {1}:{2} [{3}] {4}" -f $level.ToUpper(), $file, $r.Line, $r.RuleName, $r.Message) }
        }
    }
    Write-Output "PSScriptAnalyzer: $($files.Count) files, $errorsFound error(s), $warningsFound warning(s)."

    if ($syntaxErrors -gt 0 -or $errorsFound -gt 0) { exit 1 }
}
finally {
    Pop-Location
}
