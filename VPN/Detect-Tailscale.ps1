# This script detects Tailscale installed at the system level.
# Website: https://tailscale.com/

Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force

$detected = [bool](Get-AppByName '*Tailscale*') -or
    (Test-FilePaths @(
        "$env:ProgramFiles\Tailscale\tailscale-ipn.exe",
        "${env:ProgramFiles(x86)}\Tailscale\tailscale-ipn.exe"
    ))

Resolve-Detection -Detected:$detected -Label 'Tailscale'
