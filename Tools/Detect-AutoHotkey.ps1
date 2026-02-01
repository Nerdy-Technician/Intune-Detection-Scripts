# This Script Will Detect AutoHotkey

$AutoHotkeyPath = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

#Check if AutoHotkey is installed

if (Test-Path "$AutoHotkeyPath") {
    Write-Output "AutoHotkey is present."
    exit 0
} else {
    Write-Output "AutoHotkey is not present."
    exit 1
}