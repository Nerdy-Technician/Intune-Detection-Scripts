# This script detects Mozilla Firefox installed at the system level.
# Website: https://www.mozilla.org/firefox/

Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force

$detected = [bool](Get-AppByName '*Mozilla Firefox*') -or
    (Test-FilePaths @(
        "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
        "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
    ))

Resolve-Detection -Detected:$detected -Label 'Mozilla Firefox'
