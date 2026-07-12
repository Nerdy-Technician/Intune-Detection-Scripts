[CmdletBinding()]
param(
    [ValidatePattern('^v?\d+\.\d+\.\d+$')]
    [string]$Version,

    [string]$OutputDir = 'output'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NextVersion {
    try {
        $tags = git tag 2>$null | Where-Object { $_ -match '^v[0-9]+\.[0-9]+\.[0-9]+$' }
        if (-not $tags) {
            return 'v1.0.0'
        }

        $latest = $tags |
            Sort-Object { [version]($_ -replace '^v', '') } |
            Select-Object -Last 1

        $latestVersion = [version]($latest -replace '^v', '')
        return "v$([version]::new($latestVersion.Major, $latestVersion.Minor, $latestVersion.Build + 1))"
    }
    catch {
        return 'v1.0.0'
    }
}

if (-not $Version) {
    $Version = Get-NextVersion
}
elseif ($Version -notmatch '^v') {
    $Version = "v$Version"
}

$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $PSScriptRoot $OutputDir
$ignoredDirectories = @('.git', '.github', 'build', 'Images')

if (Test-Path $out) {
    Remove-Item $out -Recurse -Force
}

New-Item -ItemType Directory -Path $out | Out-Null

$categoryDirectories = Get-ChildItem -Path $root -Directory |
    Where-Object { $ignoredDirectories -notcontains $_.Name } |
    Where-Object {
        $_.Name -eq 'modules' -or
        (Get-ChildItem -Path $_.FullName -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue)
    } |
    Sort-Object Name

foreach ($directory in $categoryDirectories) {
    Copy-Item -Path $directory.FullName -Destination (Join-Path $out $directory.Name) -Recurse -Force
}

$scripts = Get-ChildItem -Path $out -Filter '*.ps1' -File -Recurse |
    Where-Object { $_.FullName -notlike "*$([IO.Path]::DirectorySeparatorChar)$OutputDir$([IO.Path]::DirectorySeparatorChar)*" } |
    Sort-Object FullName |
    ForEach-Object {
        [PSCustomObject]@{
            Path     = [IO.Path]::GetRelativePath($out, $_.FullName).Replace('\', '/')
            Category = Split-Path ([IO.Path]::GetRelativePath($out, $_.FullName)) -Parent
            Name     = $_.BaseName
        }
    }

$manifest = [PSCustomObject]@{
    PackageVersion = $Version
    BuildTimeUtc   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    ScriptCount    = @($scripts).Count
    Scripts        = $scripts
}

$manifestPath = Join-Path $out 'manifest.json'
$manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath $manifestPath -Encoding utf8

$zipName = "Intune-Detection-Scripts-$Version.zip"
$zipPath = Join-Path $out $zipName
$archiveItems = Get-ChildItem -Path $out | Where-Object { $_.FullName -ne $zipPath }
Compress-Archive -Path $archiveItems.FullName -DestinationPath $zipPath -Force

Write-Output "Created $zipPath"

if ($env:GITHUB_OUTPUT) {
    "package_version=$Version" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
}
