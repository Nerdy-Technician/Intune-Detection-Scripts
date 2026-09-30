# Wazuh Agent - Intune Detection Script

$exePath = "C:\Program Files (x86)\ossec-agent\wazuh-agent.exe"

if (Test-Path $exePath) {
    Write-Output "Wazuh Agent is installed."
    exit 0 
}
else {
    Write-Output "Wazuh Agent is NOT installed."
    exit 1 
}
