# Silenzio

Native macOS menu bar utility that mutes the default input device via CoreAudio. Lives exclusively in the status bar — no Dock icon, no main window.

UI matches the **Silenzio** designs in Wonder (Active / Muted popovers + Preferences).

## Requirements

- macOS 14+
- Apple Silicon (`arm64`) only
- **Xcode** (recommended) — scripts auto-use `/Applications/Xcode.app` via `DEVELOPER_DIR`

Optional (so `xcodebuild` / `swift` resolve without env vars):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Build

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Compile (arm64)
xcrun swift build -c release --arch arm64

# Package as a proper .app (sets LSUIElement, ad-hoc codesign)
chmod +x Scripts/package-app.sh Scripts/run.sh
./Scripts/package-app.sh
```

The app bundle is written to `dist/Silenzio.app`.

## Run

```bash
# One-shot: build debug bundle and open it
./Scripts/run.sh

# Or open a release build
open dist/Silenzio.app
```

Running the raw SPM binary works for quick tests, but **microphone TCC prompts attach correctly only when you launch the `.app` bundle**.

## Permissions

On first launch macOS may ask for:

1. **Microphone** — live level meter in the popover (`NSMicrophoneUsageDescription`).
2. **Accessibility** — recommended for push-to-talk key-up detection. Silenzio calls `AXIsProcessTrustedWithOptions` and can open System Settings → Privacy & Security → Accessibility.

Grant access to **Silenzio.app**, then click the menu bar icon again (or relaunch).

```bash
# Optional reset while debugging
tccutil reset Accessibility com.silenzio.app
tccutil reset Microphone com.silenzio.app
```

## Usage

| Action | How |
| --- | --- |
| Toggle mute | Click the green/red toggle in the popover, or press **⌥ Space** |
| Change shortcut | Preferences → Shortcuts → Change |
| Push-to-talk | Preferences → Mute Mode → Push-to-Talk (hold shortcut) |
| Preferences | Popover → Preferences, or **⌘,** |
| Quit | Popover → Quit, or **⌘Q** |

Status bar icon:

- Live: `mic.fill`
- Muted: `mic.slash.fill` (red-tinted)

## Architecture

| File | Role |
| --- | --- |
| `SilenzioApp.swift` | `MenuBarExtra` agent app (`LSUIElement`) |
| `MicController.swift` | CoreAudio mute + volume fallback + property listeners + meter |
| `HotkeyManager.swift` | Carbon global hotkey + Accessibility prompt + shortcut recorder |
| `SettingsStore.swift` | Mute mode, status bar style, launch-at-login |
| `Views/` | Popover + Preferences matching Wonder designs |

Mute strategy:

1. Prefer `kAudioDevicePropertyMute` on the default input device.
2. If unavailable, set `kAudioDevicePropertyVolumeScalar` to `0` and restore the previous level on unmute.
3. Listen for hardware property changes so the icon stays in sync with System Settings / other apps.

## Project layout

```
Package.swift
Resources/Info.plist          # LSUIElement = true
Scripts/package-app.sh
Scripts/run.sh
Sources/Silenzio/
  SilenzioApp.swift
  MicController.swift
  HotkeyManager.swift
  SettingsStore.swift
  Theme/SilenzioTheme.swift
  Views/…
```
