![Intune](/Images/Intune.png)

Welcome to the repository for Intune Detection Scripts for EXE Software. This repository contains PowerShell scripts designed to detect the presence of specific executable software on client machines managed by Microsoft Intune.



##  📋Table of Contents

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Contents](#contents)
- [Contributing](#contributing)
- [License](#license)

##  🌟 Introduction

This repository provides a collection of detection scripts that can be used with Microsoft Intune to check for the presence of specific executable software on managed devices. These scripts can be useful for ensuring compliance, software inventory, and management tasks.

## 🚀 Getting Started

To get started with these detection scripts, you'll need:

- Microsoft Intune
- Administrative privileges on the devices you want to manage
- PowerShell


### 📄 Usage
1. Clone this repository to your local machine:

```shell
git clone https://github.com/Nerdy-Technician/intune-detection-scripts.git
```

2. Navigate to the scripts directory:

```shell
cd intune-detection-scripts
```
## Contents

```plaintext
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 AV
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Browsers (System)
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Buisness
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Developer
-rw-r--r-- 1 runner docker  35K Aug 14 01:56 LICENSE
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Media
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Monitoring
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Network Tools
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Productivity
-rw-r--r-- 1 runner docker 2.4K Aug 14 01:56 README.md
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 RMM
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 Tools
drwxr-xr-x 2 runner docker 4.0K Aug 14 01:56 VPN
```


### 🤝 Contributing
Contributions are welcome! If you have any improvements or additional scripts to share, please fork the repository and submit a pull request.

- 🍴 Fork the repository
- 🌿 Create your feature branch (git checkout -b feature/AmazingFeature)
- 💾 Commit your changes (git commit -m 'Add some AmazingFeature')
- 📤 Push to the branch (git push origin feature/AmazingFeature)
- 🔄 Open a pull request

### 📜 License
Distributed under the MIT License. See LICENSE for more information.

## 🔧 Architecture & Organization

```
Intune-Detection-Scripts/
  AV/
  Browsers (System)/
  Buisness/
  Developer/
  Media/
  Monitoring/
  Network Tools/
  Productivity/
  RMM/
  Tools/
  VPN/
  modules/
    DetectionCommon.psm1
  build/
    pack.ps1
  .github/workflows/
    auto-release.yml
```

- `modules/DetectionCommon.psm1`: Shared helper functions used by individual detection scripts (registry search, file path checks, PATH executable lookup, standardized exit codes).
- Individual script folders remain for logical grouping. Each script should import the module if it benefits from shared logic.
- `build/pack.ps1`: Packages all scripts + module into a versioned zip with a JSON manifest.
- GitHub Actions workflow auto-tags and publishes a release zip on every push to `main`.

## 🧪 Detection Script Conventions

Each detection script MUST:
- Exit with code `0` if the target application is detected.
- Exit with code `1` if not detected.
- Optionally write a single line like `AppName detected` for diagnostic clarity.

Recommended template:
```powershell
Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force
$detected = [bool](Get-AppByName '*App Name*') -or (Test-FilePaths @('C:\Program Files\App\app.exe')) -or (Test-ExecutableInPath @('app'))
Resolve-Detection -Detected:$detected -Label 'App Name'
```
### Manual Trigger
You can also trigger the workflow via the Actions UI (`workflow_dispatch`) to force a new patch release.

## 🚀 Using in Intune
For Win32 detection logic:
1. Include the desired script (and the module if needed) in your Win32 package source.
2. Configure detection rule to run the script.
3. Intune interprets exit code: `0 = installed`, `1 = not installed`.

## 🛠 Future Improvements
- Add remediation scripts (Install if missing) alongside detection.
- Generate per-category zip bundles.
- Add Pester tests for module functions.
- Offer optional JSON output mode for richer telemetry.

Feel free to open issues for any of these enhancements.


