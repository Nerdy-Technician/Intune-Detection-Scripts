[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = New-Object System.Collections.Generic.List[string]
$parseTargets = Get-ChildItem -Path $Root -Include '*.ps1', '*.psm1' -File -Recurse |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    Where-Object { $_.FullName -notmatch '[\\/]build[\\/]output[\\/]' } |
    Sort-Object FullName

foreach ($file in $parseTargets) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null

    foreach ($errorRecord in $errors) {
        $relativePath = [IO.Path]::GetRelativePath($Root, $file.FullName)
        $failures.Add("${relativePath}:$($errorRecord.Extent.StartLineNumber): $($errorRecord.Message)")
    }
}

$ignoredScriptNames = @('pack.ps1', 'Test-Repository.ps1')
$detectionScripts = Get-ChildItem -Path $Root -Filter '*.ps1' -File -Recurse |
    Where-Object { $_.DirectoryName -notmatch '[\\/]build$' } |
    Where-Object { $_.FullName -notmatch '[\\/]build[\\/]output[\\/]' } |
    Sort-Object FullName

foreach ($script in $detectionScripts) {
    if ($ignoredScriptNames -contains $script.Name) {
        continue
    }

    $relativePath = [IO.Path]::GetRelativePath($Root, $script.FullName)
    $content = Get-Content -Path $script.FullName -Raw

    $usesResolveDetection = $content -match '(?im)^\s*Resolve-Detection\b'

    if (-not $usesResolveDetection) {
        if ($content -notmatch '(?im)^\s*exit\s+0\b') {
            $failures.Add("${relativePath}: missing exit 0 detection success path")
        }

        if ($content -notmatch '(?im)^\s*exit\s+1\b') {
            $failures.Add("${relativePath}: missing exit 1 detection failure path")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Error "Repository validation failed:`n$($failures -join "`n")"
    exit 1
}

Write-Output "Validated $($parseTargets.Count) PowerShell files and $($detectionScripts.Count) detection scripts."
