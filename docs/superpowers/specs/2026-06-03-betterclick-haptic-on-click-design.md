# betterclick — Design Spec

**Date:** 2026-06-03
**Status:** Approved for planning

## Overview

`betterclick` is a macOS menu-bar app that fires the Logitech MX Master 4's haptic
motor on mouse clicks, configurable per-button and per-app. It detects clicks itself
and delegates the actual haptic pulse to the **HapticWeb** Logi Actions SDK plugin
(running inside Logi Options+) over a local WebSocket.

### Goals

- Fire a haptic pulse on mouse-down, scoped by which button was pressed and which app
  is frontmost.
- Configurable: a global per-button default plus per-app overrides.
- Add **zero perceptible latency** to the click itself.
- Unobtrusive: runs in the menu bar, sensible defaults, easy on/off.

### Non-goals (YAGNI)

- Windows support (macOS only).
- Building our own Logi Actions SDK plugin (we reuse HapticWeb).
- Custom waveform authoring.
- Scroll/gesture haptics.
- Profiles/presets beyond per-app overrides.
- Press/release toggle — **press (mouse-down) only**.
- Cloud sync.

## Feasibility (confirmed 2026-06-03)

- **Logi Actions SDK** officially supports **Windows and macOS** (Node.js or C#) and
  explicitly exposes haptic feedback on the MX Master 4 — the only Logitech mouse with
  a haptic motor controllable via the SDK. Requires Logi Options+ installed.
  <https://logitech.github.io/actions-sdk-docs/>
- **HapticWeb / HapticWebPlugin** is an existing Actions SDK plugin that exposes the
  haptic motor over a **local REST + WebSocket API**, bound to `127.0.0.1` only.
  <https://github.com/Fallstop/HapticWebPlugin> · <https://haptics.jmw.nz/>
- Key constraint: an Actions SDK plugin can fire haptics but **cannot tap arbitrary
  global OS clicks**. So click detection must live in a separate process that signals
  the Logi-hosted plugin. A localhost socket is the documented way through.

### HapticWeb interface (the haptic backend)

- WebSocket: `wss://local.jmw.nz:41443/ws` — send a single byte (0–14) = waveform index.
  No response; connection stays open for repeated triggers.
- REST: `POST /haptic/{waveform}` (requires `Content-Length`; e.g. `curl -d ''`),
  `GET /waveforms`, `GET /` (health).
- `local.jmw.nz` resolves to `127.0.0.1`; binding restricted to loopback. HTTPS/WSS
  mandatory, using a **valid** (not self-signed) cert — standard TLS trust works, no
  pinning needed. CORS open, no auth.
- 15 waveforms (index 0–14): `sharp_collision`, `sharp_state_change`, `knock`,
  `damp_collision`, `mad`, `ringing`, `subtle_collision`, `completed`, `jingle`,
  `damp_state_change`, `firework`, `happy_alert`, `wave`, `angry_alert`, `square`.

## Architecture

Two processes with a clean boundary:

- **HapticWeb** (prerequisite, not ours) — runs inside Logi Options+, exposes the local
  WS/REST API above. User installs it into Logi Options+.
- **betterclick** (what we build) — a Swift menu-bar app that detects clicks and sends
  the right waveform byte over the localhost socket.

The localhost socket is **IPC transport**, kept as-is in this design. It exists because
the haptic motor lives behind another process (the Logi plugin host) and a localhost
socket is the documented way through; traffic never leaves the machine. If we ever build
our own plugin, the IPC mechanism could be swapped, but a local socket would remain the
likely choice.

### Components (each independently testable)

1. **ClickTap** — wraps a *listen-only* `CGEventTap` for `leftMouseDown` /
   `rightMouseDown` / `otherMouseDown`, mapping button numbers to
   `{left, right, middle, back, forward}`. Listen-only means the click passes through
   with zero added latency; the haptic fires asynchronously. Fires on **press**.
   The tap callback does minimal work and dispatches off the event thread.
2. **AppContext** — resolves the frontmost app's bundle ID via `NSWorkspace`, cached and
   refreshed on app-activation notifications (not queried on every click).
3. **RuleEngine** — pure logic. Input `(button, bundleID)` → output `waveform | none`.
   Resolution: **per-app override if present, else global default**. Core logic; most
   heavily unit-tested.
4. **HapticClient** — persistent `URLSessionWebSocketTask` to HapticWeb; sends the
   waveform index byte; auto-reconnects with backoff; REST `POST /haptic/{name}`
   fallback. Standard TLS trust (valid cert), no pinning.
5. **ConfigStore** — `Codable` model persisted to
   `~/Library/Application Support/betterclick/config.json`; loaded at launch, saved on
   edit; seeds defaults on first run.
6. **MenuBarUI** — `NSStatusItem` + SwiftUI settings: master on/off, edit global
   per-button defaults, manage per-app overrides (app picker), pick a waveform per rule
   with a **"Test"** button that fires it live, and permission/connection status.
7. **PermissionsManager** — checks Input Monitoring/Accessibility (required for
   `CGEventTap`) via `IOHIDCheckAccess` / `AXIsProcessTrusted`, and guides the user into
   System Settings on first run.

### Data flow

```
ClickTap (button)
  → AppContext.frontmostBundleID
  → RuleEngine.resolve(button, bundleID)
  → if waveform → HapticClient.send(index)
```

All non-blocking; dropped events are not buffered (haptics are time-sensitive).

## Config model

Chosen model: **global default + per-app overrides.**

```
masterEnabled: Bool
globalDefaults: {
  left:    waveform?
  right:   waveform?
  middle:  waveform?
  back:    waveform?
  forward: waveform?
}
appOverrides: [
  bundleID: { left: waveform?|OFF, right: …, middle: …, back: …, forward: … }
]
```

- Resolution per `(button, bundleID)`: if `appOverrides[bundleID]` has an entry for the
  button, use it (including explicit `OFF`); otherwise fall back to `globalDefaults`.
- **First-run defaults:** `left → subtle_collision`, all other buttons off — does
  something noticeable but unobtrusive out of the box.

## Tech stack

- **Swift 5.9+**, targeting **macOS 14 (Sonoma)+**.
- **SwiftUI** for the settings window; **AppKit** (`NSStatusItem`, `NSApplication`,
  `LSUIElement`) for the menu-bar item and background-app behavior; SwiftUI hosted via
  `NSHostingView`.
- System APIs (all first-party Apple frameworks): **Core Graphics** (`CGEventTap`),
  **AppKit `NSWorkspace`**, **IOKit/ApplicationServices** (`IOHIDCheckAccess` /
  `AXIsProcessTrusted`).
- **Foundation `URLSession`** — `URLSessionWebSocketTask` (primary) + `URLSessionDataTask`
  (REST fallback).
- Persistence: `Codable` → JSON. No database.
- Build/test/packaging: **Xcode** app target (bundling, `Info.plist` permission usage
  strings, code-signing), **Swift Package Manager** for the pure-logic modules
  (`RuleEngine`, `ConfigStore`, `HapticClient`) so they build/test headlessly, **XCTest**
  for unit tests. Codesigning + hardened runtime so Input Monitoring permission persists
  across launches (ad-hoc signing fine for personal use).
- **Zero third-party Swift packages** — everything is Apple frameworks. The only external
  moving part is the HapticWeb plugin, talked to over its documented local WS/REST API.

## Error handling

- **HapticWeb unreachable / Logi Options+ not running** → menu-bar icon shows a degraded
  state with an actionable message ("Launch Logi Options+ / install HapticWeb"); dropped
  events are not buffered.
- **Missing permissions** → tap can't be created; show onboarding instead of failing
  silently.
- **Non-haptic mouse** → HapticWeb errors surfaced gracefully.
- **WS drop** → auto-reconnect with backoff; REST fallback while reconnecting.

## Testing

- **Unit:** `RuleEngine` (override precedence, explicit OFF, default fallback),
  `ConfigStore` (encode/decode round-trip + first-run default seeding), `HapticClient`
  (name→index byte mapping, reconnect logic via mock socket).
- **Manual end-to-end:** click in app X → feel the configured haptic; "Test" buttons in
  settings.
- `ClickTap` / `AppContext` / `PermissionsManager` kept as thin wrappers so the logic
  above them stays unit-testable.
