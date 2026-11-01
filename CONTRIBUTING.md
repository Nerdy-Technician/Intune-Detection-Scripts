# Contributing

Thanks for adding or fixing a detection script. Every script in this repo is an
**Intune Win32 app custom detection script**: one `.ps1`, uploaded on its own.

## The Intune contract

| Result | Exit code | STDOUT |
| --- | --- | --- |
| Detected / installed / compliant | `exit 0` | must write at least one line (`Write-Output`) |
| Not detected | `exit 1` | ignored |

- Exit 0 with **no** STDOUT is treated as *not detected*.
- Anything on STDERR, or an unhandled exception, is *not detected*. Wrap checks in `try/catch` and fall through to `exit 1`.
- Every script must contain an explicit `exit 0` and `exit 1` path (or use `Resolve-Detection`). `build/Test-Repository.ps1` enforces this.

## User vs machine (SYSTEM) context

The context comes from the Win32 app's *Install behaviour*:

- **System** — runs as `NT AUTHORITY\SYSTEM`. `HKCU` and `%LOCALAPPDATA%` point at the SYSTEM profile, not the user. Check `HKLM`, `%ProgramFiles%`, `%ProgramData%`.
- **User** — runs as the signed-in user. Use this for per-user installs (`%LOCALAPPDATA%\Programs\...`, `HKCU\Software\...`, `HKCU` Uninstall key).

Say which context the script expects in its comment header.

## 64-bit vs 32-bit (WOW64)

- Set **Run script as 32-bit process on 64-bit clients = No** on the app.
- In a 32-bit process, `%ProgramFiles%` → `Program Files (x86)` and `HKLM\SOFTWARE` → `HKLM\SOFTWARE\WOW6432Node`.
- 32-bit apps on 64-bit Windows register under `WOW6432Node`. The module's registry helpers take `-View Registry64 | Registry32 | Both` (default `Both`) and open the hive with an explicit view, so the result is the same whichever bitness Intune uses.
- Check both `%ProgramFiles%` and `%ProgramFiles(x86)%` when an app ships in both builds.

## Shared module and template

- `modules/DetectionCommon.psm1` — helpers:
  - Files: `Test-FileDetection -Path -MinimumVersion`, `Get-FileVersion`, `Test-FilePaths`
  - Registry: `Get-RegistryValueData`, `Test-RegistryKeyExists`, `Test-RegistryDetection -Hive HKLM|HKCU -Key -ValueName [-ExpectedValue] [-MinimumVersion] [-View]`
  - Installed apps: `Get-InstalledApp`, `Test-InstalledApp -DisplayName 'App*' [-MinimumVersion] [-IncludeCurrentUser]`
  - Versions: `ConvertTo-DetectionVersion`, `Compare-DetectionVersion`, `Test-VersionRequirement -Operator eq|ge|gt|le|lt`
  - Context: `Get-DetectionContext` (SYSTEM?, 64-bit process?, WOW64?)
  - Exit: `Resolve-Detection -Detected $bool -Label 'App'`
- `templates/Detect-Template.ps1` — copy into the right category folder, rename to `Detect-<App>.ps1`, fill in the *Configure* block.

Intune uploads a single file, so before uploading paste the module functions your
script calls into its *Helpers* region. The `Import-Module` line is only for local testing.

## Adding a script

1. Copy the template to `<Category>/Detect-<App>.ps1`.
2. Header: app name, vendor URL, expected context (System/User).
3. Prefer a versioned check (`-MinimumVersion`) over plain existence when the deployment pins a version.
4. Run the checks below.
5. Scripts are listed in the contents table in `README.md`. That table is generated, so don't edit it by hand. Regenerate it with `build/Update-ReadmeIndex.ps1` when that script is in your checkout.

## Checks (same as CI)

PowerShell 7.4.6+ is needed for PSScriptAnalyzer.

```powershell
pwsh ./build/Invoke-Lint.ps1              # syntax + PSScriptAnalyzer (PSScriptAnalyzerSettings.psd1)
pwsh ./tests/Test-DetectionCommon.ps1     # module self-test
pwsh ./build/Test-Repository.ps1          # exit 0/1 paths
```

CI (`.github/workflows/ci.yml`) runs these on every pull request. Syntax errors or PSScriptAnalyzer **Error** findings fail the build. Warnings are shown as annotations.
