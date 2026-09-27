# Install-Extensions.ps1

A PowerShell script that reads a list of Visual Studio extensions from `extensions.json`, downloads each `.vsix` package from the Visual Studio Marketplace, and installs it silently via `VSIXInstaller.exe`.

## What it does

1. Loads `extensions.json` — an array of objects like:
   ```json
   { "name": "ML.NET Model Builder 2022", "url": "https://marketplace.visualstudio.com/items?itemName=MLNET.ModelBuilder2022" }
   ```
2. Skips any entry with no `url` field (built-in VS components or extensions without a resolvable Marketplace page).
3. Converts each Marketplace `items?itemName=...` link into its direct `.vsix` download URL.
4. Downloads the `.vsix` files into a local `vsix-downloads` folder.
5. Locates `VSIXInstaller.exe` automatically using `vswhere.exe`.
6. Installs each `.vsix` silently (`/quiet`).
7. Prints a summary of what was installed, failed, or skipped.

## Requirements

- Windows with **Visual Studio 2019/2022 installed** (the script locates `VSIXInstaller.exe` through `vswhere.exe`, which ships with the VS Installer).
- PowerShell 5.1+ (or PowerShell 7+).
- Internet access to `marketplace.visualstudio.com`.
- **Visual Studio must be closed** before running — VSIXInstaller cannot install while VS is open.
- An elevated (Administrator) PowerShell session is recommended, especially for extensions installed for all users.

## Files

| File | Purpose |
|---|---|
| `Install-Extensions.ps1` | The script |
| `extensions.json` | The list of extensions to install |

Keep both files in the same folder, or pass a custom path with `-JsonPath` (see below).

## Usage

1. Open an **elevated PowerShell** window (Run as Administrator).
2. Navigate to the folder containing the script and `extensions.json`:
   ```powershell
   cd C:\path\to\folder
   ```
3. If script execution is restricted, allow it for this session only:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Run the script:
   ```powershell
   .\Install-Extensions.ps1
   ```

Bypass Windows' script execution policy blocking unsigned scripts

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Extensions.ps1
```

### Optional parameters

| Parameter | Default | Description |
|---|---|---|
| `-JsonPath` | `.\extensions.json` | Path to the extensions JSON file |
| `-DownloadFolder` | `.\vsix-downloads` | Folder where downloaded `.vsix` files are stored |

Examples:

```powershell
# Use a JSON file from a different location
.\Install-Extensions.ps1 -JsonPath "C:\temp\extensions.json"

# Download vsix files to a custom folder
.\Install-Extensions.ps1 -DownloadFolder "D:\vs-extensions"

# Both
.\Install-Extensions.ps1 -JsonPath "C:\temp\extensions.json" -DownloadFolder "D:\vs-extensions"
```

## Output

While running, the script prints progress for each extension (downloading, installing, success/failure). At the end it prints a summary, e.g.:

```
===== Summary =====
Installed (1): ML.NET Model Builder 2022 ...
Failed (0):
Skipped (0):
```

- **Installed** — downloaded and installed successfully.
- **Failed** — download or install error (see the red text above the summary for details).
- **Skipped** — no usable Marketplace URL in `extensions.json` (built-in components, or placeholder links that aren't real Marketplace pages).

## Known limitations

- Only works for extensions that have a genuine `marketplace.visualstudio.com/items?itemName=...` URL. Entries with placeholder links (e.g. `https://visualstudio.com`) or no `url` at all are skipped — install those manually via **Extensions → Manage Extensions** in Visual Studio.
- Installs the **latest** version of each extension; it doesn't pin specific versions.
- Some extensions may prompt for a VS restart after installation — restart Visual Studio once the script finishes.
- If `VSIXInstaller.exe` can't be found, confirm Visual Studio is installed and `vswhere.exe` exists at:
  `%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe`

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `vswhere.exe not found` | Visual Studio isn't installed, or is installed in a non-standard location. |
| `VSIXInstaller.exe not found` | Corrupt/partial VS install — repair via Visual Studio Installer. |
| Install fails with exit code other than `0` or `1001` | Close all running Visual Studio instances and re-run. Check the `.vsix` in `vsix-downloads` isn't corrupted (delete and re-run to force a fresh download). |
| Script won't run at all | Execution policy is blocking it — run the `Set-ExecutionPolicy` command above, or run `powershell -ExecutionPolicy Bypass -File .\Install-Extensions.ps1`. |
