# MuteKey

**Global keyboard shortcuts for microphone and camera in Microsoft Teams, Slack, and Zoom — right from your Mac menu bar.**

![MuteKey menu bar icon](AppIcon/32.png)

---

## What it does

MuteKey sits in your menu bar and lets you mute/unmute your microphone and toggle your camera with a single keystroke — no matter which app is in the foreground. Works across Teams, Slack Huddles, and Zoom simultaneously.

- **Global shortcuts** — work from any app, at any time
- **Smart status display** — colored pill icon shows your current mic/camera state in real time
- **Multi-call aware** — handles multiple active calls at once
- **Automatic updates** — built-in updater via Sparkle

---

## Supported apps

| App | Microphone | Camera |
|---|---|---|
| Microsoft Teams (Enterprise) | ✅ Real status via WebSocket API | ✅ Real status via WebSocket API |
| Microsoft Teams (Personal) | ✅ Keyboard injection | ✅ Keyboard injection |
| Slack Huddle | ✅ Keyboard injection | — Not supported by Slack |
| Zoom | ✅ Real status via Accessibility API | ✅ Real status via Accessibility API |

---

## Requirements

- macOS 15.0 or later
- Microsoft Teams, Slack, or Zoom installed

---

## Installation

1. Download the latest `MuteKey.dmg` from the [Releases](https://github.com/BenZackBumm/MuteKey/releases) page
2. Open the DMG and drag `MuteKey.app` to your `/Applications` folder
3. Launch MuteKey — the setup wizard walks you through the rest

---

## Setup

### Accessibility Permission
MuteKey needs Accessibility access to send keyboard shortcuts to Teams, Slack, and Zoom. macOS will prompt you automatically on first launch.

### Microsoft Teams (Enterprise)
For real-time mic/camera status in Teams, enable the third-party app API once:

> Teams → Settings → Privacy → enable **"Third-party app API"**

MuteKey connects automatically when your next meeting starts.

### Keyboard Shortcuts
Default shortcuts:
- **Microphone:** `F19`
- **Camera:** `F16`

Both can be customized in **Settings → Keyboard Shortcuts**.

---

## Menu bar icon

| State | Icon |
|---|---|
| No active meeting | Monochrome icon (adapts to Light/Dark Mode) |
| Active Teams or Zoom meeting | Red/green pill showing real mic and camera state |
| Active Slack Huddle or Personal Teams | Blue pill |
| Multiple calls active | Blue pill with warning |

---

## Building from source

Requires Xcode 16+ and macOS 15 SDK.

```bash
git clone https://github.com/BenZackBumm/MuteKey.git
cd MuteKey
open MuteKey.xcodeproj
```

Dependencies are resolved automatically via Swift Package Manager (KeyboardShortcuts, Sparkle).

---

## Credits

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Sindre Sorhus
- [Sparkle](https://sparkle-project.org) — Sparkle Project

---

## License

MIT License — see [LICENSE](LICENSE) for details.  
Copyright © 2026 Benjamin Krammer
