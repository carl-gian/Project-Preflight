# Changelog

What changed in each version of Preflight. The newest is at the top.

## [5.6.1] - 2026-11-02

### Added

- **Installer.** `PreflightSetup.exe` installs Preflight for the signed-in Windows user, with no administrator
  rights. It adds Preflight to the Start menu, can add a Desktop shortcut and start Preflight with Windows, and
  opens it when it finishes. Settings from an earlier copy are kept.
- **Uninstall** from Windows Settings → Apps. It asks before removing your settings, and keeps them unless you
  choose otherwise.
- Releases now include the installer, and `Publish-Release.ps1 -Publish` creates the GitHub release itself.

### Changed

- After an automatic update, Windows' list of installed apps shows the new version number.

## [5.6.0] - 2026-11-02

### Added

- **Automatic updates.** Preflight checks GitHub for a newer version each time it starts, before the welcome page.
  A new version downloads, is checked against its checksum and installs, then Preflight restarts on it.
  No internet, or a slow connection, never holds up the meeting.
- **Safe updates.** The new script is checked for errors before it's installed, the replaced files are backed up,
  and a version that can't open its window is rolled back by itself and not installed again.
- **Update screen** with progress, and **Skip for now**.
- **Settings → Updates**: version, last result, **Check now**, automatic updates on or off, and the GitHub
  repository updates come from.
- **New Settings window** with a side menu: General, Window layout, Updates and Advanced.
- **Window layout editor.** Drag windows on a copy of the screen to move them, and drag edges or corners to resize
  them. Windows snap to the screen edges, the middle and each other (hold Shift to place freely). Includes exact
  numbers, quick places, opening order, **Copy from open windows** and **Try it now**.
- **Preflight.exe**, a small launcher with its own icon. It replaces `Run-Preflight.vbs`.
- **Start Preflight when Windows starts**, a switch in Settings → General.
- `Publish-Release.ps1`, which builds a release package and its checksum.
- The version number in the top bar.

### Changed

- New look, following the Steward design: calmer dark colours, rounded buttons and switches, clearer contrast,
  and a visible focus ring for keyboard users.
- Wording is plainer and in sentence case, with no all-caps labels.
- **Cancel** in Settings now really discards window layout changes, and **Reset to defaults** waits for **Save**.

### Fixed

- **Save** in Settings failed every time before writing anything, because it called a function that didn't exist.

### Removed

- Unfinished layout buttons ("Auto-Align" and "Copy App Settings", both marked "coming soon") and the separate
  layout preview window. The new editor replaces them.

## [5.5] and earlier

Before this changelog. 5.5 added the EMEET integration.

[5.6.1]: https://github.com/carl-gian/Project-Preflight/releases/tag/v5.6.1
[5.6.0]: https://github.com/carl-gian/Project-Preflight/releases/tag/v5.6.0
