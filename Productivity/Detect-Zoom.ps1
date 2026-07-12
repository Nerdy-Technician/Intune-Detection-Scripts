# This script detects Zoom Workplace installed at the system level.
# Website: https://www.zoom.com/

Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force

$detected = [bool](Get-AppByName '*Zoom*') -or
    (Test-FilePaths @(
        "$env:ProgramFiles\Zoom\bin\Zoom.exe",
        "${env:ProgramFiles(x86)}\Zoom\bin\Zoom.exe"
    ))

Resolve-Detection -Detected:$detected -Label 'Zoom'
