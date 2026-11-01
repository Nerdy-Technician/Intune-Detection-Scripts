#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for Intune detection scripts.

.DESCRIPTION
    Import-Module this file while developing/testing; Intune
    uploads ONE file, so copy the functions you use into the script before
    upload (see templates/Detect-Template.ps1 and CONTRIBUTING.md).
    All Test-* helpers return [bool] and never throw for "not found" so a
    detection script can always reach an explicit exit 0 / exit 1.

    Intune contract:
      exit 0 + any STDOUT  -> detected / compliant
      exit 1 (or no STDOUT) -> not detected

    Registry views:
      Intune runs the Win32 app detection script in a 64-bit PowerShell only when
      "Run script as 32-bit process on 64-bit clients" is set to No. The helpers
      open the registry with an explicit view so results are identical either way.
#>

Set-StrictMode -Version Latest

#region Existing helpers (kept for backwards compatibility)

function Get-AppByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$NamePattern
    )
    Get-InstalledApp -DisplayName $NamePattern
}

function Test-FilePaths {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string[]]$Paths
    )
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($p))) { return $true }
    }
    return $false
}

function Test-ExecutableInPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string[]]$Names
    )
    foreach ($n in $Names) {
        if (Get-Command $n -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Resolve-Detection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][bool]$Detected,
        [Parameter(Mandatory)][string]$Label,
        [switch]$NoExit
    )
    if ($Detected) {
        Write-Output "$Label detected"
        $code = 0
    }
    else {
        Write-Verbose "$Label not detected"
        $code = 1
    }
    if ($NoExit) { return $code }
    exit $code
}

#endregion

#region Version helpers

function ConvertTo-DetectionVersion {
    <#
    .SYNOPSIS
        Normalises a version string ("1.2", "v1.2.3", "1.2.3-beta", "1,2,3,4") to [version].
        Returns $null when no numeric version can be extracted.
    #>
    [CmdletBinding()]
    [OutputType([version])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$Version
    )
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $clean = $Version.Trim() -replace ',', '.'
    if ($clean -notmatch '(\d+)(\.\d+){0,3}') { return $null }
    $parts = @($Matches[0].Split('.'))
    while ($parts.Count -lt 2) { $parts += '0' }
    return [version]($parts -join '.')
}

function Compare-DetectionVersion {
    <#
    .SYNOPSIS
        Returns -1, 0 or 1 like [version]::CompareTo. Missing parts count as 0
        (so 1.2 equals 1.2.0.0). Throws if either side is not a version.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][string]$ReferenceVersion,
        [Parameter(Mandatory)][string]$DifferenceVersion
    )
    $a = ConvertTo-DetectionVersion $ReferenceVersion
    $b = ConvertTo-DetectionVersion $DifferenceVersion
    if (-not $a -or -not $b) { throw "Cannot compare '$ReferenceVersion' with '$DifferenceVersion'." }
    $pad = { param($v) [version]::new($v.Major, $v.Minor, [math]::Max($v.Build, 0), [math]::Max($v.Revision, 0)) }
    return (& $pad $a).CompareTo((& $pad $b))
}

function Test-VersionRequirement {
    <#
    .SYNOPSIS
        True when -Version satisfies -Operator against -Required (ge is the usual Intune case).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()][AllowEmptyString()][string]$Version,
        [Parameter(Mandatory)][string]$Required,
        [ValidateSet('eq', 'ge', 'gt', 'le', 'lt')][string]$Operator = 'ge'
    )
    if ([string]::IsNullOrWhiteSpace($Version)) { return $false }
    try { $c = Compare-DetectionVersion -ReferenceVersion $Version -DifferenceVersion $Required }
    catch { return $false }
    switch ($Operator) {
        'eq' { return $c -eq 0 }
        'ge' { return $c -ge 0 }
        'gt' { return $c -gt 0 }
        'le' { return $c -le 0 }
        'lt' { return $c -lt 0 }
    }
}

#endregion

#region File helpers

function Get-FileVersion {
    <#
    .SYNOPSIS
        FileVersion (or ProductVersion) of a file, env vars expanded. $null if missing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$ProductVersion
    )
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not (Test-Path -LiteralPath $expanded -PathType Leaf)) { return $null }
    $info = (Get-Item -LiteralPath $expanded).VersionInfo
    $v = if ($ProductVersion) { $info.ProductVersion } else { $info.FileVersion }
    if ([string]::IsNullOrWhiteSpace($v)) { return $null }
    return $v.Trim()
}

function Test-FileDetection {
    <#
    .SYNOPSIS
        True if the file exists and (optionally) its version meets -MinimumVersion.
    .EXAMPLE
        Test-FileDetection -Path '%ProgramFiles%\VideoLAN\VLC\vlc.exe' -MinimumVersion '3.0.20'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$MinimumVersion,
        [switch]$ProductVersion
    )
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not (Test-Path -LiteralPath $expanded -PathType Leaf)) { return $false }
    if (-not $MinimumVersion) { return $true }
    $v = Get-FileVersion -Path $expanded -ProductVersion:$ProductVersion
    return (Test-VersionRequirement -Version $v -Required $MinimumVersion -Operator ge)
}

#endregion

#region Registry helpers

function Get-RegistryValueData {
    <#
    .SYNOPSIS
        Reads a registry value using an explicit view so WOW64 redirection never applies.
    .PARAMETER Hive
        HKLM or HKCU. HKCU is only meaningful when the script runs in user context.
    .PARAMETER View
        Registry64 (native), Registry32 (WOW6432Node) or Both (64 first, then 32).
    .OUTPUTS
        The value data, or $null when the key/value is missing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('HKLM', 'HKCU')][string]$Hive,
        [Parameter(Mandatory)][string]$Key,
        [AllowEmptyString()][string]$ValueName = '',
        [ValidateSet('Registry64', 'Registry32', 'Both')][string]$View = 'Both'
    )
    if (-not $script:IsWindowsPlatform) { return $null }
    $hiveEnum = if ($Hive -eq 'HKLM') { [Microsoft.Win32.RegistryHive]::LocalMachine } else { [Microsoft.Win32.RegistryHive]::CurrentUser }
    $views = switch ($View) {
        'Registry64' { @([Microsoft.Win32.RegistryView]::Registry64) }
        'Registry32' { @([Microsoft.Win32.RegistryView]::Registry32) }
        default { @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32) }
    }
    $subKey = $Key -replace '^(HKLM|HKCU|HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER):?\\', ''
    foreach ($v in $views) {
        $base = $null; $k = $null
        try {
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hiveEnum, $v)
            $k = $base.OpenSubKey($subKey)
            if ($k) {
                $data = $k.GetValue($ValueName, $null)
                if ($null -ne $data) { return $data }
            }
        }
        catch { Write-Verbose "Registry read failed ($v): $_" }
        finally {
            if ($k) { $k.Dispose() }
            if ($base) { $base.Dispose() }
        }
    }
    return $null
}

function Test-RegistryKeyExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][ValidateSet('HKLM', 'HKCU')][string]$Hive,
        [Parameter(Mandatory)][string]$Key,
        [ValidateSet('Registry64', 'Registry32', 'Both')][string]$View = 'Both'
    )
    if (-not $script:IsWindowsPlatform) { return $false }
    $hiveEnum = if ($Hive -eq 'HKLM') { [Microsoft.Win32.RegistryHive]::LocalMachine } else { [Microsoft.Win32.RegistryHive]::CurrentUser }
    $views = switch ($View) {
        'Registry64' { @([Microsoft.Win32.RegistryView]::Registry64) }
        'Registry32' { @([Microsoft.Win32.RegistryView]::Registry32) }
        default { @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32) }
    }
    $subKey = $Key -replace '^(HKLM|HKCU|HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER):?\\', ''
    foreach ($v in $views) {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hiveEnum, $v)
        try {
            $k = $base.OpenSubKey($subKey)
            if ($k) { $k.Dispose(); return $true }
        }
        finally { $base.Dispose() }
    }
    return $false
}

function Test-RegistryDetection {
    <#
    .SYNOPSIS
        True if a registry value exists, optionally equals -ExpectedValue, or
        (as a version) meets -MinimumVersion.
    .EXAMPLE
        Test-RegistryDetection -Hive HKLM -Key 'SOFTWARE\Contoso\Agent' -ValueName Version -MinimumVersion '2.1'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][ValidateSet('HKLM', 'HKCU')][string]$Hive,
        [Parameter(Mandatory)][string]$Key,
        [AllowEmptyString()][string]$ValueName = '',
        [string]$ExpectedValue,
        [string]$MinimumVersion,
        [ValidateSet('Registry64', 'Registry32', 'Both')][string]$View = 'Both'
    )
    $data = Get-RegistryValueData -Hive $Hive -Key $Key -ValueName $ValueName -View $View
    if ($null -eq $data) { return $false }
    if ($PSBoundParameters.ContainsKey('ExpectedValue') -and ("$data" -ne $ExpectedValue)) { return $false }
    if ($MinimumVersion) { return (Test-VersionRequirement -Version "$data" -Required $MinimumVersion) }
    return $true
}

function Get-InstalledApp {
    <#
    .SYNOPSIS
        Searches the Uninstall keys (64-bit, WOW6432Node, and optionally HKCU for per-user installs).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [switch]$IncludeCurrentUser
    )
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    if ($IncludeCurrentUser) { $roots += 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' }
    foreach ($r in $roots) {
        if (Test-Path $r) {
            Get-ChildItem $r -ErrorAction SilentlyContinue |
                Get-ItemProperty -ErrorAction SilentlyContinue |
                Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -like $DisplayName }
        }
    }
}

function Test-InstalledApp {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [string]$MinimumVersion,
        [switch]$IncludeCurrentUser
    )
    foreach ($app in @(Get-InstalledApp -DisplayName $DisplayName -IncludeCurrentUser:$IncludeCurrentUser)) {
        if (-not $MinimumVersion) { return $true }
        $ver = if ($app.PSObject.Properties['DisplayVersion']) { $app.DisplayVersion } else { $null }
        if (Test-VersionRequirement -Version $ver -Required $MinimumVersion) { return $true }
    }
    return $false
}

#endregion

#region Context helpers

function Get-DetectionContext {
    <#
    .SYNOPSIS
        Describes how the script is running: SYSTEM vs user, 64/32-bit process and OS.
    #>
    [CmdletBinding()]
    param()
    $isSystem = $false
    if ($script:IsWindowsPlatform) {
        $isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
    }
    [PSCustomObject]@{
        IsSystem       = $isSystem
        UserName       = [Environment]::UserName
        Is64BitProcess = [Environment]::Is64BitProcess
        Is64BitOS      = [Environment]::Is64BitOperatingSystem
        IsWow64        = ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess)
    }
}

#endregion

$script:IsWindowsPlatform = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

Export-ModuleMember -Function @(
    'Get-AppByName', 'Test-FilePaths', 'Test-ExecutableInPath', 'Resolve-Detection',
    'ConvertTo-DetectionVersion', 'Compare-DetectionVersion', 'Test-VersionRequirement',
    'Get-FileVersion', 'Test-FileDetection',
    'Get-RegistryValueData', 'Test-RegistryKeyExists', 'Test-RegistryDetection',
    'Get-InstalledApp', 'Test-InstalledApp',
    'Get-DetectionContext'
)
