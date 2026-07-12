# This script detects Docker Desktop installed at the system level.
# Website: https://www.docker.com/products/docker-desktop/

Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force

$detected = [bool](Get-AppByName '*Docker Desktop*') -or
    (Test-FilePaths @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    ))

Resolve-Detection -Detected:$detected -Label 'Docker Desktop'
