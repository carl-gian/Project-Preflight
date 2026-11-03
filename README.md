# Audio-Video Preflight

A step-by-step checklist for the Kingdom Hall AV laptop. Before each meeting it walks the operator through the
cables and Zoom, checks the hardware by itself, then opens OBS, Zoom and Meeting Media Manager and puts every window
in its place.

Built for one sound desk, so anyone can set up a meeting the same way every time.

## What it does

1. **Checks for updates.** If a newer version is on GitHub, it installs it and restarts. This takes a few seconds.
2. **Welcome.** A short overview of the steps.
3. **Zoom.** Start or join the meeting, and share the computer audio. "Show me how" plays a short video.
4. **Equipment Check.** One question per cable, each with a photo of how it should look.
5. **Detection.** Charger, internet, HDMI display, camera and USB audio are checked automatically. Anything
   missing says what to do.
6. **Launch.** Choose Midweek or Weekend. OBS, Zoom and Meeting Media Manager open in order and move to their
   saved positions.

A Non-Zoom flow (for meetings that don't need Zoom) opens Meeting Media Manager or JW Library only.

`Ctrl+Shift+S` closes Preflight at any time without launching anything.

## Install on a laptop

1. Open the [latest release](https://github.com/carl-gian/Project-Preflight/releases/latest) and download
   **PreflightSetup.exe**.
2. Run it. Windows may say it "protected your PC", because the installer isn't signed. Choose **More info**, then
   **Run anyway**.
3. Pick the options you want:
   - **Desktop shortcut**
   - **Start Preflight when Windows starts**, so it opens as soon as someone signs in
4. Leave **Open Preflight now** ticked and choose **Finish**. The first start asks a few questions about this laptop;
   you can change them later in **Settings**.

The installer doesn't need administrator rights. It installs for the signed-in Windows user, in
`%LOCALAPPDATA%\Programs\Audio-Video Preflight`, and adds Preflight to the Start menu.

Requirements: Windows 10 or 11, with the built-in Windows PowerShell 5.1. Nothing else to install.

### Already have Preflight in a folder?

Run the installer anyway. Your settings and window layout are kept, because they live in Documents, not in the
program folder. Afterwards you can delete the old folder, and the old `Run-Preflight.vbs` shortcut if you had one.

### Uninstall

**Settings → Apps → Installed apps → Audio-Video Preflight → Uninstall**. It asks whether to keep your settings;
the answer is No unless you choose Yes.

### Without the installer

Download **Preflight.zip** from the same release, unzip it into a folder you can write to, and run
**Preflight.exe**. Keep `Preflight.exe`, `Preflight.ps1` and the `media` folder together.

## Updates

Preflight checks this repository's latest release each time it starts, before the welcome page.

- A newer version downloads, is checked against its checksum, and installs. Preflight then restarts on it.
- No internet, or GitHub is slow? It starts the current version after a few seconds. The meeting never waits.
- **Skip for now** on the update screen skips it for today.
- Only the files in the release are replaced. Your settings are never touched.
- The files that were replaced are kept in `%LOCALAPPDATA%\AV-Preflight\update\previous`. If a new version can't
  open its window, Preflight puts the previous one back by itself and won't install that version again.
- **Settings → Updates** shows the version, the last result and a **Check now** button. Automatic checks can be
  turned off there.

## Settings

Open **Settings** from the top bar.

| Section | What's in it |
|---|---|
| General | Congregation name, start with Windows, the EMEET virtual camera (off unless you turn it on), Zoom host, separate OBS scenes for Midweek and Weekend |
| Window layout | Where OBS, Zoom and Meeting Media Manager open, the order they open in, and the wait between them |
| Updates | Version, Check now, automatic updates, and which GitHub repository updates come from |
| Advanced | Device names and IDs. Rarely needed |

### Window layout

A small copy of the 1920 × 1080 screen, like the PowerToys FancyZones editor.

- Drag a window to move it. Drag an edge or a corner to resize it.
- Windows snap to the screen edges, the middle of the screen and each other. A coral line shows the snap.
  Hold **Shift** to place a window freely.
- The panel on the right has exact numbers, quick places (Left half, Right half, Centre, Full screen), the opening
  order and the wait after opening.
- **Copy from open windows** reads where the apps are on screen right now.
- **Try it now** moves the open apps to the layout for 6 seconds, without saving.

### Where things are kept

| What | Where |
|---|---|
| Settings | `Documents\Preflight Settings\Preflight.conf` |
| Window layout | `Documents\Preflight Settings\Layout.conf` |
| Log | `%LOCALAPPDATA%\AV-Preflight\preflight.log` |
| Launcher log | `launcher.log`, next to `Preflight.exe` |

Both settings files are plain text and can be edited in Notepad.

## Releasing a new version

You need [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) (`pwsh`),
and NSIS for the installer (`brew install makensis` on a Mac).

1. Raise the version near the top of `Preflight.ps1`:
   ```powershell
   $Script:AppVersion = [version]"5.6.2"
   ```
2. Add a `## [5.6.2] - date` section to [CHANGELOG.md](CHANGELOG.md). It becomes the release notes.
3. Commit and push.
4. Build and publish:
   ```bash
   pwsh ./Publish-Release.ps1 -Publish
   ```
   This checks the script for errors, builds `Preflight.zip`, its checksum and `PreflightSetup.exe` in `dist/`, and
   creates the GitHub release tagged `v5.6.2` with all three attached. It signs in with the GitHub account git
   already uses (or `GH_TOKEN`). Without `-Publish` it only builds.

Every laptop installs it the next time Preflight starts.

## Building the launcher

`Preflight.exe` only starts `Preflight.ps1` from its own folder, without a console window. Updates never need a new
build of it. To rebuild it (needs [Go](https://go.dev)):

```bash
cd launcher
go run ./tools/makeicon -png icon.png      # redraws the icon
go-winres simply --icon icon.png --manifest gui --arch amd64 \
  --product-name "Audio-Video Preflight" --file-description "Audio-Video Preflight launcher" \
  --product-version 5.6.0.0 --file-version 5.6.0.0 --original-filename Preflight.exe
GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-H=windowsgui -s -w" -o ../Preflight.exe .
```

## What's in this repository

| Path | What it is |
|---|---|
| `Preflight.ps1` | The app: screens, checks, launch sequence, settings and updater |
| `Preflight.exe` | The launcher |
| `media/` | Photos, videos and icons the checklist shows |
| `launcher/` | Source for `Preflight.exe` and its icon |
| `installer/` | The NSIS script and artwork for `PreflightSetup.exe` |
| `Publish-Release.ps1` | Builds the release files and publishes them |
| `Run-Preflight.vbs` | The old launcher. Still works; `Preflight.exe` replaces it |

## Design

The look follows **Steward**, the shared design for these tools:
[kingdom-project-design](https://github.com/SymboBingo12/kingdom-project-design). Its colours, buttons, switches and
wording rules are used throughout. The app icon, the update screen and the installer artwork are original.

To redraw the installer artwork:

```bash
cd launcher
go run ./tools/makeicon -ico ../installer/preflight.ico -wizard ../installer/wizard.bmp -header ../installer/header.bmp
```

## Independent

This project is not affiliated with, endorsed by, or connected to Jehovah's Witnesses, JW.ORG, JW Library or the
Watch Tower Bible and Tract Society. No logos, icons, names or font files of theirs are used in the app's branding.
All artwork is original. JW Library is named only as a program Preflight can open.
