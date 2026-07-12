# This script detects Adobe Acrobat Reader installed at the system level.
# Website: https://www.adobe.com/acrobat/pdf-reader.html

Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force

$detected = [bool](Get-AppByName '*Adobe Acrobat*Reader*') -or
    (Test-FilePaths @(
        "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    ))

Resolve-Detection -Detected:$detected -Label 'Adobe Acrobat Reader'
