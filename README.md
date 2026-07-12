![Intune](/Images/Intune.png)

# Intune Detection Scripts

PowerShell detection scripts for Microsoft Intune Win32 apps. Each script checks whether a specific application is present and returns the exit codes Intune expects:

- `0`: detected / installed
- `1`: not detected / missing

The scripts are grouped by application type and can be used individually or packaged with the shared helper module in `modules/DetectionCommon.psm1`.

## Contents

| Category | Scripts |
| --- | ---: |
| AV | 2 |
| Browsers (System) | 3 |
| Buisness | 1 |
| Developer | 13 |
| Media | 3 |
| Monitoring | 1 |
| Network Tools | 1 |
| Productivity | 17 |
| RMM | 8 |
| Tools | 14 |
| VPN | 6 |

> Note: `Buisness` is kept as-is for compatibility with existing paths.

## Usage

1. Choose the detection script for the application you want to detect.
2. If the script imports `modules/DetectionCommon.psm1`, include the `modules` folder in the same package source.
3. In Intune, configure the Win32 app detection rule to run the script.
4. Use PowerShell detection behavior where `0` means installed and `1` means not installed.

Example shared-module pattern:

```powershell
Import-Module "$PSScriptRoot/../modules/DetectionCommon.psm1" -Force

$detected = [bool](Get-AppByName '*App Name*') -or
    (Test-FilePaths @('C:\Program Files\App\app.exe')) -or
    (Test-ExecutableInPath @('app.exe'))

Resolve-Detection -Detected:$detected -Label 'App Name'
```

## Development

Run repository validation before opening a pull request:

```powershell
pwsh ./build/Test-Repository.ps1
```

Create a release package locally:

```powershell
pwsh ./build/pack.ps1 -Version v1.0.0
```

The package is written to `build/output/` and includes:

- detection scripts grouped by category
- `modules/DetectionCommon.psm1`
- `manifest.json` with package version, build time, script count, and script paths

## Detection Script Conventions

Detection scripts should:

- use `exit 0` when the target app is detected
- use `exit 1` when the target app is not detected
- write short diagnostic output for local troubleshooting
- prefer `DetectionCommon.psm1` for registry, file path, PATH lookup, and standardized exit behavior

## Automation

GitHub Actions validates the repository on pull requests and pushes to `main`. The release workflow packages the scripts, tags the repository, and publishes a release zip when changes land on `main` or when manually triggered.

## Contributing

Contributions are welcome. Please keep detection behavior simple, deterministic, and compatible with Intune's exit-code expectations.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
