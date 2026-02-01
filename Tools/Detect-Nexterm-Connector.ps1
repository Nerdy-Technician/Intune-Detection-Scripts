# Checks to see if Nexterm Connector is installed

NextermInstallLocation = "C:\Program Files\Nexterm Connector\nexterm-connector.exe"

#Check if Nexterm Connector is installed
if (Test-Path "$NextermInstallLocation") {
    Write-Output "Nexterm Connector is present."
    exit 0
} else {
    Write-Output "Nexterm Connector is not present."
    exit 1
}


