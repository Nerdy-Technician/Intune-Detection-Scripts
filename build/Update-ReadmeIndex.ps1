<#
.SYNOPSIS
    Regenerates the Contents table in README.md from the category folders.
.DESCRIPTION
    Scans top-level category folders, counts the .ps1 detection scripts in each,
    and rewrites the block between the README index markers.
.EXAMPLE
    pwsh ./build/Update-ReadmeIndex.ps1
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$excluded = @('Images', 'modules', 'build', '.github', '.git')
$startMarker = '<!-- INDEX:START -->'
$endMarker = '<!-- INDEX:END -->'
$readmePath = Join-Path $RepositoryRoot 'README.md'

$categories = Get-ChildItem -LiteralPath $RepositoryRoot -Directory |
    Where-Object { $excluded -notcontains $_.Name -and -not $_.Name.StartsWith('.') } |
    Sort-Object Name

$lines = @(
    $startMarker
    '| Category | Scripts |'
    '| --- | ---: |'
)
foreach ($category in $categories) {
    $count = @(Get-ChildItem -LiteralPath $category.FullName -Filter '*.ps1' -File -Recurse).Count
    if ($count -eq 0) { continue }
    $link = './' + [uri]::EscapeDataString($category.Name) + '/'
    $lines += "| [$($category.Name)]($link) | $count |"
}
$lines += $endMarker
$block = $lines -join "`n"

$readme = (Get-Content -LiteralPath $readmePath -Raw) -replace "`r`n", "`n"
$pattern = '(?s)' + [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)
if ($readme -notmatch $pattern) {
    throw "README.md is missing the $startMarker / $endMarker markers."
}
$updated = [regex]::Replace($readme, $pattern, { param($m) $block })

if ($updated -ne $readme) {
    [System.IO.File]::WriteAllText($readmePath, $updated)
    Write-Host 'README.md index updated.'
} else {
    Write-Host 'README.md index already up to date.'
}
