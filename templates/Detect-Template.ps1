<#
.SYNOPSIS
    Detects <AppName> for an Intune Win32 app (custom detection script).

.DESCRIPTION
    Website: <https://vendor.example>

    Intune exit contract
      exit 0 AND write something to STDOUT  -> app DETECTED (installed / compliant)
      exit 1 (STDOUT ignored)               -> app NOT detected
    Anything written to STDERR or an unhandled throw counts as NOT detected.

    Run context (set on the Win32 app, not in this script)
      - Install behaviour "System": runs as SYSTEM. HKCU = SYSTEM's hive and
        $env:LOCALAPPDATA = systemprofile. Use HKLM / Program Files.
      - Install behaviour "User": runs as the signed-in user. Use HKCU,
        %LOCALAPPDATA%, %APPDATA% for per-user installs (Teams, Spotify, etc).
      - "Run script as 32-bit process on 64-bit clients": leave at No. The
        DetectionCommon registry helpers use explicit 64/32-bit views anyway, but
        %ProgramFiles% resolves to Program Files (x86) in a 32-bit process.

    Before uploading to Intune: Intune accepts a single .ps1, so paste the
    DetectionCommon functions you use into the "Helpers" region below (or keep
    the Import-Module line only for local testing).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

#region Helpers
$modulePath = Join-Path $PSScriptRoot '..\modules\DetectionCommon.psm1'
if (Test-Path -LiteralPath $modulePath) {
    Import-Module $modulePath -Force
}
#endregion

# ---- Configure -------------------------------------------------------------
$AppLabel       = '<AppName>'
$MinimumVersion = ''   # e.g. '3.0.20' ; empty = any version
$FilePaths      = @(
    '%ProgramFiles%\<Vendor>\<App>\<app>.exe'
    '%ProgramFiles(x86)%\<Vendor>\<App>\<app>.exe'
)
$UninstallName  = '<AppName>*'   # DisplayName wildcard in Uninstall keys
# ---------------------------------------------------------------------------

try {
    $detected = $false

    foreach ($path in $FilePaths) {
        if (Test-FileDetection -Path $path -MinimumVersion $MinimumVersion) { $detected = $true; break }
    }

    if (-not $detected) {
        $detected = Test-InstalledApp -DisplayName $UninstallName -MinimumVersion $MinimumVersion -IncludeCurrentUser
    }
}
catch {
    Write-Verbose "Detection error: $_"
    $detected = $false
}

if ($detected) {
    Write-Output "$AppLabel detected"
    exit 0
}
else {
    exit 1
}
