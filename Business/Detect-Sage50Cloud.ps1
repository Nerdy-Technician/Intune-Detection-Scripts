#ThiS Script will Detect Sage 50 Cloud Accounting Software on Windows
#Sage 50 Cloud Accounting Website: https://www.sage.com/en-ca/products/sage-50-cloud/

# Path to the Sage 50 Cloud executable
$SageInstallPath = "C:\Program Files (x86)\Sage\Sage 50 Accounting 2021"

#Check if Sage 50 Cloud Accounting Software is installed
if (Test-Path -Path $SageInstallPath) {
    Write-Output "Sage 50 Cloud Accounting Software is installed."
    exit 0
} else {
    Write-Output "Sage 50 Cloud Accounting Software is not installed."
    exit 1
}
