<#
.SYNOPSIS
    Dependency-free self-test for modules/DetectionCommon.psm1 (runs on Linux and Windows).
.EXAMPLE
    pwsh ./tests/Test-DetectionCommon.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\DetectionCommon.psm1') -Force

$failures = 0
function Assert-Equal($Name, $Expected, $Actual) {
    if ($Expected -eq $Actual) { Write-Output "PASS  $Name" }
    else { Write-Output "FAIL  $Name (expected '$Expected', got '$Actual')"; $script:failures++ }
}

Assert-Equal 'compare 1.2 = 1.2.0.0'        0  (Compare-DetectionVersion '1.2' '1.2.0.0')
Assert-Equal 'compare 1.10 > 1.9'           1  (Compare-DetectionVersion '1.10' '1.9')
Assert-Equal 'compare v2.0.0-beta < 2.0.1' -1  (Compare-DetectionVersion 'v2.0.0-beta' '2.0.1')
Assert-Equal 'comma versions 1,2,3,4'       0  (Compare-DetectionVersion '1,2,3,4' '1.2.3.4')
Assert-Equal 'requirement ge met'        $true  (Test-VersionRequirement -Version '3.0.21' -Required '3.0.20')
Assert-Equal 'requirement ge not met'    $false (Test-VersionRequirement -Version '3.0.19' -Required '3.0.20')
Assert-Equal 'requirement lt'            $true  (Test-VersionRequirement -Version '1.0' -Required '2.0' -Operator lt)
Assert-Equal 'empty version not met'     $false (Test-VersionRequirement -Version '' -Required '1.0')
Assert-Equal 'garbage version not met'   $false (Test-VersionRequirement -Version 'n/a' -Required '1.0')

$tmp = Join-Path ([IO.Path]::GetTempPath()) "dc-$([guid]::NewGuid()).txt"
Set-Content -LiteralPath $tmp -Value 'x'
Assert-Equal 'file exists'               $true  (Test-FileDetection -Path $tmp)
Assert-Equal 'file missing'              $false (Test-FileDetection -Path "$tmp.missing")
Assert-Equal 'Test-FilePaths any'        $true  (Test-FilePaths -Paths @("$tmp.missing", $tmp))
Remove-Item -LiteralPath $tmp

Assert-Equal 'Resolve-Detection true'    0 (Resolve-Detection -Detected $true -Label 'Demo' -NoExit | Select-Object -Last 1)
Assert-Equal 'Resolve-Detection false'   1 (Resolve-Detection -Detected $false -Label 'Demo' -NoExit)

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    Assert-Equal 'registry 64-bit ProgramFilesDir' $true (Test-RegistryDetection -Hive HKLM -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion' -ValueName ProgramFilesDir -View Registry64)
    Assert-Equal 'registry missing key' $false (Test-RegistryDetection -Hive HKLM -Key 'SOFTWARE\DoesNotExist\Nope' -ValueName X)
}
else {
    Assert-Equal 'registry off-Windows returns false' $false (Test-RegistryDetection -Hive HKLM -Key 'SOFTWARE\X' -ValueName Y)
}

Write-Output "Context: $(Get-DetectionContext | ConvertTo-Json -Compress)"

if ($failures -gt 0) {
    Write-Output "$failures test(s) failed."
    exit 1
}
Write-Output 'All DetectionCommon tests passed.'
exit 0
