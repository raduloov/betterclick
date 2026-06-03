# betterclick

A macOS menu-bar app that fires the **Logitech MX Master 4**'s haptic motor on
mouse-down — configurable per button and per app.

betterclick detects clicks itself (a listen-only `CGEventTap`, so it adds **zero
latency** to your clicks) and delegates the actual haptic pulse to the
[HapticWeb](https://github.com/Fallstop/HapticWebPlugin) plugin running inside
Logi Options+, over a local WebSocket.

## How it works

```
click  ──▶  betterclick (CGEventTap, listen-only)
              │  resolves (button, frontmost app) → waveform
              ▼
        HapticWeb plugin  ──▶  MX Master 4 haptic motor
        (wss://local.jmw.nz:41443/ws, one byte = waveform index)
```

The haptic motor can only be driven by code running inside the Logi Options+
plugin host, so betterclick talks to HapticWeb over a **loopback** socket
(`127.0.0.1`, never leaves the machine).

## Prerequisites

1. A **Logitech MX Master 4** mouse (the only MX mouse with a haptic motor).
2. **Logi Options+** installed.
3. The **HapticWeb** plugin installed into Logi Options+:
   <https://github.com/Fallstop/HapticWebPlugin>
   (this is what exposes the local API betterclick sends to).
4. **macOS 14 (Sonoma) or later.**

## Permissions

betterclick needs **Input Monitoring** to detect clicks
(System Settings → Privacy & Security → Input Monitoring). It prompts on first
launch. After you grant it, just **reopen the menu-bar window** — betterclick
re-checks and arms itself automatically (no relaunch needed).

## Build & run

The Xcode project is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is **not** checked in.

```bash
# one-time: install the generator
brew install xcodegen

# core logic tests (no hardware needed)
cd BetterClickCore && swift test && cd ..

# generate the Xcode project
xcodegen generate

# build the app
xcodebuild -project betterclick.xcodeproj -scheme betterclick \
  -configuration Debug -derivedDataPath .build-xcode build

# the built app:
open .build-xcode/Build/Products/Debug/betterclick.app
```

Or, after `xcodegen generate`, open `betterclick.xcodeproj` in Xcode and run the
`betterclick` scheme.

A `Makefile` wraps the common commands: `make test`, `make build`, `make run`,
`make install`, `make clean`.

The app is **ad-hoc signed** ("Sign to Run Locally"), which is fine for personal
use. For Input Monitoring to persist cleanly across rebuilds, keep a stable build
location.

## Stable signing (persistent Input Monitoring)

macOS ties the Input Monitoring grant to the app's **code signature**. An ad-hoc
signature changes on every build, so each reinstall would force you to re-grant.
To avoid that, betterclick is signed with a **stable self-signed identity**
(`betterclick-selfsign`) whose designated requirement stays constant across builds.

One-time setup (creates the identity in your login keychain):

```bash
./scripts/make-signing-cert.sh
```

After that, `make install` re-signs the installed app with it automatically. Grant
Input Monitoring **once** to the signed app and it persists across all future
reinstalls. (If you skip this, the app still works — you'll just re-grant Input
Monitoring after each reinstall.)

> Switching an already-installed app from ad-hoc to the stable identity changes its
> identity once, so you grant Input Monitoring one final time after the switch.

## Install to /Applications (recommended for daily use)

Running from the build folder is fragile (the path moves on rebuild, which resets
the Input Monitoring grant). To install a stable copy:

```bash
./scripts/make-signing-cert.sh   # one-time, for a persistent Input Monitoring grant
make install                     # builds Release, installs to /Applications, signs it
```

Then grant **Input Monitoring** to the `/Applications` copy when prompted.

### Launch at login

The settings window has a **Launch at login** toggle (backed by `SMAppService`).

> **Signing note:** `SMAppService` login-item registration requires the app to be
> code-signed. The self-signed identity above may satisfy it; if the toggle doesn't
> stick (a failure is logged via `NSLog`), a full Apple Developer identity is the
> reliable path. Use the toggle on the **`/Applications`** copy, not the dev build —
> otherwise the login item would point at the build folder.

## Using it

Click the menu-bar cursor icon to open the window:

- **Enabled** — master on/off.
- **Connection badge** — Connected / Connecting… / Offline (HapticWeb status).
- **Global defaults** — pick a waveform per mouse button (Left / Right / Middle /
  Back / Forward), each with a **Test** button. "Off" means no haptic.

Out of the box: **left-click → `subtle_collision`**, all other buttons off.

### Per-app overrides

Per-app overrides are supported by the engine and config file, but the v1 UI only
edits **global defaults**. To override a specific app, edit the config file (see
below) — an override for a button wins over the global default, including an
explicit "off".

### Config file

Stored at:

```
~/Library/Application Support/betterclick/config.json
```

Human-readable and hand-editable. Bundle IDs key the overrides; button names key
each map:

```json
{
  "masterEnabled" : true,
  "globalDefaults" : {
    "left" : "subtleCollision"
  },
  "appOverrides" : {
    "com.apple.dt.Xcode" : {
      "left" : { "type" : "waveform", "waveform" : "completed" },
      "right" : { "type" : "off" }
    }
  }
}
```

Available waveforms (15): `sharpCollision`, `sharpStateChange`, `knock`,
`dampCollision`, `mad`, `ringing`, `subtleCollision`, `completed`, `jingle`,
`dampStateChange`, `firework`, `happyAlert`, `wave`, `angryAlert`, `square`.

## Architecture

- **`BetterClickCore`** — a pure-logic Swift package (waveforms, buttons, config,
  rule resolution, JSON persistence, transport encoding). Fully unit-tested
  (`swift test`, 26 tests), no system dependencies.
- **`app/`** — the macOS app target (the system glue): `ClickTap` (CGEventTap),
  `AppContext` (frontmost app via NSWorkspace), `HapticClient` (WebSocket +
  REST fallback), `PermissionsManager`, `AppCoordinator`, `SettingsView`.

## Known v1 limitations

- **Per-app overrides are config-file-only** — no UI for them yet.
- **First click after a cold start may not fire** if it lands before the
  WebSocket finishes its TLS handshake (~1s). The REST fallback covers most of
  this window; if a click is missed, the next one works.
- **No per-rule press/release choice** — haptics fire on **press** (mouse-down).
- **Config errors fail soft** — a corrupted config file silently resets to
  defaults.
- **Requires HapticWeb's valid TLS cert** on `local.jmw.nz`; if HapticWeb ever
  switched to a self-signed cert, the WebSocket would fail.
- macOS only.
