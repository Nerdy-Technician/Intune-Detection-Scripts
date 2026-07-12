# This script detects Microsoft Teams installed at the system level.
# Website: https://www.microsoft.com/microsoft-teams/

Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force

$detected = [bool](Get-AppByName '*Microsoft Teams*') -or
    [bool](Get-AppByName '*Teams Machine-Wide Installer*') -or
    (Test-FilePaths @(
        "$env:ProgramFiles\Teams Installer\Teams.exe",
        "${env:ProgramFiles(x86)}\Teams Installer\Teams.exe"
    ))

Resolve-Detection -Detected:$detected -Label 'Microsoft Teams'
