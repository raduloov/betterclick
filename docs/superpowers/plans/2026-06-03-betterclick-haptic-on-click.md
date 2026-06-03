# betterclick Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu-bar app that fires the MX Master 4 haptic motor on mouse-down, configurable per-button and per-app, by sending a waveform byte to the local HapticWeb plugin.

**Architecture:** A pure-logic Swift package (`BetterClickCore`: waveforms, buttons, config, rule resolution, persistence, message encoding) fully unit-tested with TDD, wrapped by a thin Xcode app target (`betterclick`) that supplies the un-unit-testable system glue: a listen-only `CGEventTap` for clicks, `NSWorkspace` for the frontmost app, a `URLSessionWebSocketTask` to HapticWeb, a permissions flow, and a SwiftUI/`MenuBarExtra` settings UI.

**Tech Stack:** Swift 5.9+, macOS 14+, SwiftUI + AppKit (`MenuBarExtra`/`NSStatusItem`, `LSUIElement`), Core Graphics (`CGEventTap`), `NSWorkspace`, `Foundation.URLSession` (`URLSessionWebSocketTask` + REST fallback), `Codable`→JSON, IOKit/ApplicationServices for permissions. Swift Package Manager + XCTest for the core; Xcode app target for the shell. Zero third-party Swift packages.

**Prerequisite (runtime, not built here):** The user must install the **HapticWeb** plugin (<https://github.com/Fallstop/HapticWebPlugin>) into Logi Options+. It exposes `wss://local.jmw.nz:41443/ws` (send one **binary** byte 0–14 = waveform index) and `POST https://local.jmw.nz:41443/haptic/{name}` (empty body). `local.jmw.nz` → `127.0.0.1`, valid TLS cert, loopback-only.

**Waveform index order (from HapticWeb):** `0 sharp_collision, 1 sharp_state_change, 2 knock, 3 damp_collision, 4 mad, 5 ringing, 6 subtle_collision, 7 completed, 8 jingle, 9 damp_state_change, 10 firework, 11 happy_alert, 12 wave, 13 angry_alert, 14 square`.

---

## File Structure

**Swift package `BetterClickCore/`** (pure logic, headless-testable):
- `Package.swift` — package manifest, library + test target.
- `Sources/BetterClickCore/Waveform.swift` — the 15 waveforms with stable index + name.
- `Sources/BetterClickCore/MouseButton.swift` — `{left,right,middle,back,forward}` + mapping from a CG button number.
- `Sources/BetterClickCore/Config.swift` — `Config`, `ButtonMap`, `AppOverride`, default seeding.
- `Sources/BetterClickCore/RuleEngine.swift` — `resolve(button:bundleID:) -> Waveform?`.
- `Sources/BetterClickCore/ConfigStore.swift` — load/save JSON at an injectable URL.
- `Sources/BetterClickCore/HapticMessage.swift` — encode a `Waveform` to the WS binary payload + REST path.
- `Tests/BetterClickCoreTests/*` — one test file per source unit.

**Xcode app target `app/` (`betterclick`)** (system glue, integration/manual-tested):
- `betterclickApp.swift` — `@main`, `MenuBarExtra`, owns the coordinator.
- `AppCoordinator.swift` — wires ClickTap → AppContext → RuleEngine → HapticClient; holds `ConfigStore`.
- `ClickTap.swift` — listen-only `CGEventTap` wrapper, emits `MouseButton`.
- `AppContext.swift` — frontmost bundle ID via `NSWorkspace`, cached.
- `HapticClient.swift` — `URLSessionWebSocketTask` send + REST fallback + reconnect.
- `PermissionsManager.swift` — Input Monitoring/Accessibility check + prompt.
- `SettingsView.swift` — SwiftUI settings (master toggle, global defaults, per-app overrides, Test buttons, status).
- `Info.plist` — `LSUIElement = YES`, permission usage strings.

---

## Task 1: Scaffold the package and repo

**Files:**
- Create: `BetterClickCore/Package.swift`
- Create: `BetterClickCore/Sources/BetterClickCore/Placeholder.swift`
- Create: `BetterClickCore/Tests/BetterClickCoreTests/SmokeTests.swift`
- Create: `.gitignore`

- [ ] **Step 1: Initialize git and gitignore**

```bash
cd /Users/yavorradulov/dev/betterclick
git init
printf '.DS_Store\n.build/\nDerivedData/\n*.xcuserstate\n' > .gitignore
```

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BetterClickCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BetterClickCore", targets: ["BetterClickCore"]),
    ],
    targets: [
        .target(name: "BetterClickCore"),
        .testTarget(name: "BetterClickCoreTests", dependencies: ["BetterClickCore"]),
    ]
)
```

- [ ] **Step 3: Write a placeholder source + smoke test**

`BetterClickCore/Sources/BetterClickCore/Placeholder.swift`:
```swift
public let betterClickCoreLoaded = true
```

`BetterClickCore/Tests/BetterClickCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import BetterClickCore

final class SmokeTests: XCTestCase {
    func test_packageLoads() {
        XCTAssertTrue(betterClickCoreLoaded)
    }
}
```

- [ ] **Step 4: Run tests to verify the toolchain works**

Run: `cd /Users/yavorradulov/dev/betterclick/BetterClickCore && swift test`
Expected: builds and PASSES (1 test).

- [ ] **Step 5: Commit**

```bash
cd /Users/yavorradulov/dev/betterclick
git add -A
git commit -m "chore: scaffold BetterClickCore package"
```

---

## Task 2: Waveform enum

**Files:**
- Create: `BetterClickCore/Sources/BetterClickCore/Waveform.swift`
- Test: `BetterClickCore/Tests/BetterClickCoreTests/WaveformTests.swift`

- [ ] **Step 1: Write the failing test**

`WaveformTests.swift`:
```swift
import XCTest
@testable import BetterClickCore

final class WaveformTests: XCTestCase {
    func test_indicesMatchHapticWebOrder() {
        XCTAssertEqual(Waveform.sharpCollision.index, 0)
        XCTAssertEqual(Waveform.subtleCollision.index, 6)
        XCTAssertEqual(Waveform.completed.index, 7)
        XCTAssertEqual(Waveform.square.index, 14)
    }

    func test_allCasesAreContiguous0to14() {
        let indices = Waveform.allCases.map(\.index).sorted()
        XCTAssertEqual(indices, Array(0...14))
    }

    func test_apiNameIsSnakeCase() {
        XCTAssertEqual(Waveform.sharpCollision.apiName, "sharp_collision")
        XCTAssertEqual(Waveform.dampStateChange.apiName, "damp_state_change")
    }

    func test_roundTripsThroughApiName() {
        for wf in Waveform.allCases {
            XCTAssertEqual(Waveform(apiName: wf.apiName), wf)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BetterClickCore && swift test --filter WaveformTests`
Expected: FAIL — `Waveform` is undefined.

- [ ] **Step 3: Write the implementation**

`Waveform.swift`:
```swift
import Foundation

/// The 15 haptic waveforms exposed by HapticWeb, in its index order (0–14).
public enum Waveform: String, CaseIterable, Codable, Hashable {
    case sharpCollision
    case sharpStateChange
    case knock
    case dampCollision
    case mad
    case ringing
    case subtleCollision
    case completed
    case jingle
    case dampStateChange
    case firework
    case happyAlert
    case wave
    case angryAlert
    case square

    /// Binary index sent over the WebSocket (matches HapticWeb's order exactly).
    public var index: Int {
        Waveform.allCases.firstIndex(of: self)!
    }

    /// snake_case name used by the REST endpoint `/haptic/{apiName}`.
    public var apiName: String {
        switch self {
        case .sharpCollision: return "sharp_collision"
        case .sharpStateChange: return "sharp_state_change"
        case .knock: return "knock"
        case .dampCollision: return "damp_collision"
        case .mad: return "mad"
        case .ringing: return "ringing"
        case .subtleCollision: return "subtle_collision"
        case .completed: return "completed"
        case .jingle: return "jingle"
        case .dampStateChange: return "damp_state_change"
        case .firework: return "firework"
        case .happyAlert: return "happy_alert"
        case .wave: return "wave"
        case .angryAlert: return "angry_alert"
        case .square: return "square"
        }
    }

    public init?(apiName: String) {
        guard let match = Waveform.allCases.first(where: { $0.apiName == apiName }) else {
            return nil
        }
        self = match
    }
}
```

Note: `allCases` is declared in waveform-index order, so `index` is stable as long as cases are not reordered. The contiguity test guards against accidental reordering.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BetterClickCore && swift test --filter WaveformTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add BetterClickCore/Sources/BetterClickCore/Waveform.swift BetterClickCore/Tests/BetterClickCoreTests/WaveformTests.swift
git commit -m "feat: add Waveform enum with HapticWeb index mapping"
```

---

## Task 3: MouseButton enum

**Files:**
- Create: `BetterClickCore/Sources/BetterClickCore/MouseButton.swift`
- Test: `BetterClickCore/Tests/BetterClickCoreTests/MouseButtonTests.swift`

CG button numbers (from `kCGMouseEventButtonNumber`): 0 = left, 1 = right, 2 = middle/center, 3 = back, 4 = forward.

- [ ] **Step 1: Write the failing test**

`MouseButtonTests.swift`:
```swift
import XCTest
@testable import BetterClickCore

final class MouseButtonTests: XCTestCase {
    func test_mapsCGButtonNumbers() {
        XCTAssertEqual(MouseButton(cgButtonNumber: 0), .left)
        XCTAssertEqual(MouseButton(cgButtonNumber: 1), .right)
        XCTAssertEqual(MouseButton(cgButtonNumber: 2), .middle)
        XCTAssertEqual(MouseButton(cgButtonNumber: 3), .back)
        XCTAssertEqual(MouseButton(cgButtonNumber: 4), .forward)
    }

    func test_unknownButtonNumberIsNil() {
        XCTAssertNil(MouseButton(cgButtonNumber: 5))
        XCTAssertNil(MouseButton(cgButtonNumber: -1))
    }

    func test_allCasesCount() {
        XCTAssertEqual(MouseButton.allCases.count, 5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BetterClickCore && swift test --filter MouseButtonTests`
Expected: FAIL — `MouseButton` is undefined.

- [ ] **Step 3: Write the implementation**

`MouseButton.swift`:
```swift
import Foundation

/// The five mouse buttons betterclick can react to.
public enum MouseButton: String, CaseIterable, Codable, Hashable {
    case left
    case right
    case middle
    case back
    case forward

    /// Maps a Core Graphics `kCGMouseEventButtonNumber` value to a button.
    /// 0 = left, 1 = right, 2 = middle, 3 = back, 4 = forward.
    public init?(cgButtonNumber: Int) {
        switch cgButtonNumber {
        case 0: self = .left
        case 1: self = .right
        case 2: self = .middle
        case 3: self = .back
        case 4: self = .forward
        default: return nil
        }
    }

    /// Human-readable label for the settings UI.
    public var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .middle: return "Middle"
        case .back: return "Back"
        case .forward: return "Forward"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BetterClickCore && swift test --filter MouseButtonTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add BetterClickCore/Sources/BetterClickCore/MouseButton.swift BetterClickCore/Tests/BetterClickCoreTests/MouseButtonTests.swift
git commit -m "feat: add MouseButton enum with CG button-number mapping"
```

---

## Task 4: Config model

**Files:**
- Create: `BetterClickCore/Sources/BetterClickCore/Config.swift`
- Test: `BetterClickCore/Tests/BetterClickCoreTests/ConfigTests.swift`

Model: `masterEnabled`, a global `ButtonMap` (button → optional waveform), and `appOverrides` keyed by bundle ID. An override stores, per button, one of: unset (fall through), `OFF` (explicitly silence), or a waveform. We model this with `ButtonSetting`.

- [ ] **Step 1: Write the failing test**

`ConfigTests.swift`:
```swift
import XCTest
@testable import BetterClickCore

final class ConfigTests: XCTestCase {
    func test_defaultSeedsLeftSubtleRestOff() {
        let c = Config.default
        XCTAssertTrue(c.masterEnabled)
        XCTAssertEqual(c.globalDefaults[.left], .subtleCollision)
        XCTAssertNil(c.globalDefaults[.right])
        XCTAssertNil(c.globalDefaults[.middle])
        XCTAssertTrue(c.appOverrides.isEmpty)
    }

    func test_codableRoundTrip() throws {
        var c = Config.default
        c.appOverrides["com.apple.dt.Xcode"] = [
            .left: .waveform(.completed),
            .right: .off,
        ]
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func test_buttonSettingEncodesOffAndWaveform() throws {
        let off = ButtonSetting.off
        let wf = ButtonSetting.waveform(.knock)
        XCTAssertEqual(try roundTrip(off), off)
        XCTAssertEqual(try roundTrip(wf), wf)
    }

    private func roundTrip(_ s: ButtonSetting) throws -> ButtonSetting {
        try JSONDecoder().decode(ButtonSetting.self, from: JSONEncoder().encode(s))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BetterClickCore && swift test --filter ConfigTests`
Expected: FAIL — `Config`/`ButtonSetting` undefined.

- [ ] **Step 3: Write the implementation**

`Config.swift`:
```swift
import Foundation

/// Per-button setting inside a per-app override: explicitly off, or a waveform.
/// (Absence of a key in an override map means "fall through to global default".)
public enum ButtonSetting: Codable, Hashable {
    case off
    case waveform(Waveform)
}

/// A global mapping of button → optional waveform (nil = no haptic).
public typealias ButtonMap = [MouseButton: Waveform]

/// A per-app override map. A present key wins over the global default,
/// including an explicit `.off`.
public typealias AppOverride = [MouseButton: ButtonSetting]

public struct Config: Codable, Hashable {
    public var masterEnabled: Bool
    public var globalDefaults: ButtonMap
    public var appOverrides: [String: AppOverride]   // keyed by bundle identifier

    public init(masterEnabled: Bool,
                globalDefaults: ButtonMap,
                appOverrides: [String: AppOverride]) {
        self.masterEnabled = masterEnabled
        self.globalDefaults = globalDefaults
        self.appOverrides = appOverrides
    }

    /// First-run defaults: left-click → subtle_collision, everything else off.
    public static var `default`: Config {
        Config(masterEnabled: true,
               globalDefaults: [.left: .subtleCollision],
               appOverrides: [:])
    }
}
```

Note: `MouseButton` and `Waveform` are `Codable` with `String` raw values, so dictionaries keyed by them encode as JSON objects automatically. `ButtonSetting`'s synthesized `Codable` produces `{"off": {}}` / `{"waveform": {"_0": "subtleCollision"}}` — adequate; the round-trip test is the contract.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BetterClickCore && swift test --filter ConfigTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add BetterClickCore/Sources/BetterClickCore/Config.swift BetterClickCore/Tests/BetterClickCoreTests/ConfigTests.swift
git commit -m "feat: add Config model with default seeding"
```

---

## Task 5: RuleEngine

**Files:**
- Create: `BetterClickCore/Sources/BetterClickCore/RuleEngine.swift`
- Test: `BetterClickCore/Tests/BetterClickCoreTests/RuleEngineTests.swift`

Resolution order for `(button, bundleID)`:
1. If `masterEnabled == false` → `nil`.
2. If an override exists for `bundleID` and contains the button → `.off` yields `nil`, `.waveform(w)` yields `w`.
3. Else → `globalDefaults[button]` (may be `nil`).

- [ ] **Step 1: Write the failing test**

`RuleEngineTests.swift`:
```swift
import XCTest
@testable import BetterClickCore

final class RuleEngineTests: XCTestCase {
    func test_fallsBackToGlobalDefault() {
        let cfg = Config(masterEnabled: true,
                         globalDefaults: [.left: .subtleCollision],
                         appOverrides: [:])
        let engine = RuleEngine(config: cfg)
        XCTAssertEqual(engine.resolve(button: .left, bundleID: "com.any.app"), .subtleCollision)
        XCTAssertNil(engine.resolve(button: .right, bundleID: "com.any.app"))
    }

    func test_appOverrideWaveformWins() {
        let cfg = Config(masterEnabled: true,
                         globalDefaults: [.left: .subtleCollision],
                         appOverrides: ["com.apple.dt.Xcode": [.left: .waveform(.completed)]])
        let engine = RuleEngine(config: cfg)
        XCTAssertEqual(engine.resolve(button: .left, bundleID: "com.apple.dt.Xcode"), .completed)
        XCTAssertEqual(engine.resolve(button: .left, bundleID: "com.other"), .subtleCollision)
    }

    func test_appOverrideOffSilencesEvenWithGlobalDefault() {
        let cfg = Config(masterEnabled: true,
                         globalDefaults: [.left: .subtleCollision],
                         appOverrides: ["com.apple.dt.Xcode": [.left: .off]])
        let engine = RuleEngine(config: cfg)
        XCTAssertNil(engine.resolve(button: .left, bundleID: "com.apple.dt.Xcode"))
    }

    func test_masterDisabledSilencesEverything() {
        let cfg = Config(masterEnabled: false,
                         globalDefaults: [.left: .subtleCollision],
                         appOverrides: ["x": [.left: .waveform(.completed)]])
        let engine = RuleEngine(config: cfg)
        XCTAssertNil(engine.resolve(button: .left, bundleID: "x"))
    }

    func test_nilBundleIDUsesGlobalDefault() {
        let cfg = Config(masterEnabled: true,
                         globalDefaults: [.left: .subtleCollision],
                         appOverrides: ["x": [.left: .off]])
        let engine = RuleEngine(config: cfg)
        XCTAssertEqual(engine.resolve(button: .left, bundleID: nil), .subtleCollision)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BetterClickCore && swift test --filter RuleEngineTests`
Expected: FAIL — `RuleEngine` undefined.

- [ ] **Step 3: Write the implementation**

`RuleEngine.swift`:
```swift
import Foundation

/// Pure resolver: given a button and the frontmost app's bundle ID,
/// decides which waveform (if any) to fire.
public struct RuleEngine {
    public let config: Config

    public init(config: Config) {
        self.config = config
    }

    public func resolve(button: MouseButton, bundleID: String?) -> Waveform? {
        guard config.masterEnabled else { return nil }

        if let bundleID, let override = config.appOverrides[bundleID],
           let setting = override[button] {
            switch setting {
            case .off: return nil
            case .waveform(let w): return w
            }
        }

        return config.globalDefaults[button]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BetterClickCore && swift test --filter RuleEngineTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add BetterClickCore/Sources/BetterClickCore/RuleEngine.swift BetterClickCore/Tests/BetterClickCoreTests/RuleEngineTests.swift
git commit -m "feat: add RuleEngine resolution logic"
```

---

## Task 6: ConfigStore

**Files:**
- Create: `BetterClickCore/Sources/BetterClickCore/ConfigStore.swift`
- Test: `BetterClickCore/Tests/BetterClickCoreTests/ConfigStoreTests.swift`

`ConfigStore` loads/saves JSON at an injectable file URL. Missing file → returns `Config.default` and writes it. The app target will construct it with `~/Library/Application Support/betterclick/config.json`; tests inject a temp file.

- [ ] **Step 1: Write the failing test**

`ConfigStoreTests.swift`:
```swift
import XCTest
@testable import BetterClickCore

final class ConfigStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("betterclick-test-\(UUID().uuidString)")
            .appendingPathComponent("config.json")
    }

    func test_loadMissingFileSeedsAndWritesDefault() throws {
        let url = tempURL()
        let store = ConfigStore(fileURL: url)
        let loaded = try store.load()
        XCTAssertEqual(loaded, .default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_saveThenLoadRoundTrips() throws {
        let url = tempURL()
        let store = ConfigStore(fileURL: url)
        var cfg = Config.default
        cfg.appOverrides["com.apple.dt.Xcode"] = [.left: .waveform(.completed)]
        try store.save(cfg)
        let reloaded = try store.load()
        XCTAssertEqual(reloaded, cfg)
    }

    func test_loadCorruptFileThrows() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = ConfigStore(fileURL: url)
        XCTAssertThrowsError(try store.load())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BetterClickCore && swift test --filter ConfigStoreTests`
Expected: FAIL — `ConfigStore` undefined.

- [ ] **Step 3: Write the implementation**

`ConfigStore.swift`:
```swift
import Foundation

/// Persists `Config` as pretty-printed JSON at a given file URL.
/// A missing file is treated as first run: seeds and writes `Config.default`.
public struct ConfigStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> Config {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let seeded = Config.default
            try save(seeded)
            return seeded
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    public func save(_ config: Config) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: fileURL, options: .atomic)
    }

    /// Convenience location used by the app target.
    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("betterclick").appendingPathComponent("config.json")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BetterClickCore && swift test --filter ConfigStoreTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add BetterClickCore/Sources/BetterClickCore/ConfigStore.swift BetterClickCore/Tests/BetterClickCoreTests/ConfigStoreTests.swift
git commit -m "feat: add ConfigStore JSON persistence"
```

---

## Task 7: HapticMessage encoder

**Files:**
- Create: `BetterClickCore/Sources/BetterClickCore/HapticMessage.swift`
- Test: `BetterClickCore/Tests/BetterClickCoreTests/HapticMessageTests.swift`

Encodes a `Waveform` into the two transport forms HapticWeb accepts: the WS binary payload (one byte = index) and the REST path.

- [ ] **Step 1: Write the failing test**

`HapticMessageTests.swift`:
```swift
import XCTest
@testable import BetterClickCore

final class HapticMessageTests: XCTestCase {
    func test_webSocketPayloadIsSingleIndexByte() {
        XCTAssertEqual(HapticMessage.webSocketPayload(for: .sharpCollision), Data([0]))
        XCTAssertEqual(HapticMessage.webSocketPayload(for: .subtleCollision), Data([6]))
        XCTAssertEqual(HapticMessage.webSocketPayload(for: .square), Data([14]))
    }

    func test_restPathUsesApiName() {
        XCTAssertEqual(HapticMessage.restPath(for: .dampStateChange), "/haptic/damp_state_change")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BetterClickCore && swift test --filter HapticMessageTests`
Expected: FAIL — `HapticMessage` undefined.

- [ ] **Step 3: Write the implementation**

`HapticMessage.swift`:
```swift
import Foundation

/// Builds the transport payloads HapticWeb expects.
public enum HapticMessage {
    /// One binary byte: the waveform index (0–14), sent over `wss://.../ws`.
    public static func webSocketPayload(for waveform: Waveform) -> Data {
        Data([UInt8(waveform.index)])
    }

    /// REST path for `POST https://local.jmw.nz:41443/haptic/{apiName}`.
    public static func restPath(for waveform: Waveform) -> String {
        "/haptic/\(waveform.apiName)"
    }

    /// Base host for both transports.
    public static let host = "local.jmw.nz"
    public static let port = 41443
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BetterClickCore && swift test --filter HapticMessageTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add BetterClickCore/Sources/BetterClickCore/HapticMessage.swift BetterClickCore/Tests/BetterClickCoreTests/HapticMessageTests.swift
git commit -m "feat: add HapticMessage transport encoder"
```

- [ ] **Step 6: Run the full core suite**

Run: `cd BetterClickCore && swift test`
Expected: ALL PASS (Waveform, MouseButton, Config, RuleEngine, ConfigStore, HapticMessage, Smoke).

---

## Task 8: Create the Xcode app target

**Files:**
- Create: Xcode project `betterclick.xcodeproj` with app target `betterclick`.
- Create: `app/betterclickApp.swift`
- Modify: `app/Info.plist`

This task is GUI-driven in Xcode; verification is "the app launches and shows a menu-bar item." No unit test.

- [ ] **Step 1: Create the app project**

In Xcode: File → New → Project → macOS → App.
- Product Name: `betterclick`
- Interface: SwiftUI, Language: Swift
- Save into `/Users/yavorradulov/dev/betterclick/` (so project sits at repo root, sources under `betterclick/`).

Then add the local package: File → Add Package Dependencies → Add Local → select `BetterClickCore/`. Add `BetterClickCore` to the app target's frameworks.

- [ ] **Step 2: Make it a menu-bar (agent) app**

In the target's `Info.plist`, add:
- `Application is agent (UIElement)` (`LSUIElement`) = `YES`

- [ ] **Step 3: Replace the generated `@main` with a MenuBarExtra shell**

`app/betterclickApp.swift`:
```swift
import SwiftUI

@main
struct BetterClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("betterclick", systemImage: "cursorarrow.click.2") {
            SettingsView(coordinator: appDelegate.coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }
}
```

Note: `AppCoordinator` and `SettingsView` are created in later tasks. To compile now, add temporary stubs (replaced in Tasks 9–14):
```swift
// TEMP stub — replaced in Task 13.
import SwiftUI
final class AppCoordinator: ObservableObject { func start() {} }
struct SettingsView: View {
    let coordinator: AppCoordinator
    var body: some View { Text("betterclick").padding() }
}
```
Put the stubs in `app/_TempStubs.swift` so they are easy to delete.

- [ ] **Step 4: Build and run**

Run from Xcode (⌘R). Expected: no Dock icon, a menu-bar cursor icon appears; clicking it shows a small "betterclick" window.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: add betterclick Xcode app target with menu-bar shell"
```

---

## Task 9: AppContext (frontmost app)

**Files:**
- Create: `app/AppContext.swift`

`NSWorkspace`-based; cached and refreshed on activation notifications so we never query inside the click hot path. Verified manually.

- [ ] **Step 1: Implement AppContext**

`app/AppContext.swift`:
```swift
import AppKit

/// Tracks the frontmost application's bundle identifier, updated on app
/// activation so reads inside the click path are O(1) and lock-free.
final class AppContext {
    private(set) var frontmostBundleID: String?

    init() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
    }

    @objc private func activeAppChanged(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        frontmostBundleID = app?.bundleIdentifier
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run from Xcode (⌘B). Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add app/AppContext.swift
git commit -m "feat: add AppContext tracking frontmost bundle id"
```

---

## Task 10: PermissionsManager

**Files:**
- Create: `app/PermissionsManager.swift`

`CGEventTap` requires the app to be granted **Input Monitoring** (and/or Accessibility). This checks status and can prompt.

- [ ] **Step 1: Implement PermissionsManager**

`app/PermissionsManager.swift`:
```swift
import ApplicationServices
import IOKit.hid
import AppKit

/// Checks and requests the access a CGEventTap needs.
enum PermissionsManager {
    /// True when the process may receive mouse events via an event tap.
    static func hasInputMonitoring() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Prompts the user for Input Monitoring (no-op if already decided).
    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Opens System Settings at the Input Monitoring pane.
    static func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run from Xcode (⌘B). Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add app/PermissionsManager.swift
git commit -m "feat: add PermissionsManager for Input Monitoring"
```

---

## Task 11: ClickTap (CGEventTap)

**Files:**
- Create: `app/ClickTap.swift`

Listen-only tap on mouse-down events. The callback maps the CG button number to a `MouseButton` and calls a handler. Listen-only means clicks are never delayed. Verified manually via a log line.

- [ ] **Step 1: Implement ClickTap**

`app/ClickTap.swift`:
```swift
import CoreGraphics
import Foundation
import BetterClickCore

/// Listen-only global tap for mouse-down events. Emits a `MouseButton`
/// for each press without delaying or modifying the click.
final class ClickTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onPress: (MouseButton) -> Void

    init(onPress: @escaping (MouseButton) -> Void) {
        self.onPress = onPress
    }

    /// Returns false if the tap could not be created (missing permission).
    @discardableResult
    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<ClickTap>.fromOpaque(refcon).takeUnretainedValue()
            me.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)   // pass through unchanged
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // Re-enable if the system disabled the tap (e.g. timeout).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard let button = MouseButton(cgButtonNumber: number) else { return }
        onPress(button)
    }
}
```

- [ ] **Step 2: Temporary manual smoke check**

Temporarily, in `AppCoordinator.start()` (stub), create a `ClickTap { print("press: \($0)") }` and `start()` it. Run, grant Input Monitoring when prompted, click each button, confirm console prints `press: left/right/middle/back/forward`. Then remove the temporary code.

- [ ] **Step 3: Commit**

```bash
git add app/ClickTap.swift
git commit -m "feat: add listen-only CGEventTap click detection"
```

---

## Task 12: HapticClient

**Files:**
- Create: `app/HapticClient.swift`

Maintains a persistent WebSocket to HapticWeb; sends the index byte on `fire`; auto-reconnects with backoff; falls back to a REST POST when the socket isn't ready. Exposes a `connectionState` for the UI. Standard TLS trust (valid cert) — no custom `URLSessionDelegate` needed.

- [ ] **Step 1: Implement HapticClient**

`app/HapticClient.swift`:
```swift
import Foundation
import BetterClickCore

/// Sends haptic triggers to the local HapticWeb plugin.
/// Primary transport: a persistent WebSocket (binary index byte).
/// Fallback: REST POST while the socket is reconnecting.
final class HapticClient {
    enum State { case connecting, connected, disconnected }

    private(set) var state: State = .disconnected { didSet { onStateChange?(state) } }
    var onStateChange: ((State) -> Void)?

    private let session = URLSession(configuration: .ephemeral)
    private var ws: URLSessionWebSocketTask?
    private var reconnectDelay: TimeInterval = 0.5
    private let maxReconnectDelay: TimeInterval = 10
    private var wsURL: URL {
        URL(string: "wss://\(HapticMessage.host):\(HapticMessage.port)/ws")!
    }

    func connect() {
        state = .connecting
        let task = session.webSocketTask(with: wsURL)
        ws = task
        task.resume()
        receiveLoop(task)
        // A successful handshake is implied once the first receive succeeds or
        // a send completes; mark connected optimistically and let errors reset it.
        state = .connected
        reconnectDelay = 0.5
    }

    func fire(_ waveform: Waveform) {
        if let ws, state == .connected {
            let payload = HapticMessage.webSocketPayload(for: waveform)
            ws.send(.data(payload)) { [weak self] error in
                if error != nil { self?.handleFailure() }
            }
        } else {
            sendREST(waveform)
        }
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.receiveLoop(task)            // keep listening
            case .failure:
                self.handleFailure()
            }
        }
    }

    private func handleFailure() {
        ws?.cancel(with: .goingAway, reason: nil)
        ws = nil
        state = .disconnected
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }

    /// REST fallback: POST with an empty body (Content-Length: 0 required).
    private func sendREST(_ waveform: Waveform) {
        let urlString = "https://\(HapticMessage.host):\(HapticMessage.port)\(HapticMessage.restPath(for: waveform))"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        request.httpBody = Data()
        session.dataTask(with: request).resume()
    }
}
```

- [ ] **Step 2: Manual smoke check (requires HapticWeb running)**

Temporarily call `let h = HapticClient(); h.connect()` then after 1s `h.fire(.completed)` from `AppCoordinator.start()`. With Logi Options+ + HapticWeb installed and the MX Master 4 connected, confirm you feel the `completed` waveform. Remove the temporary code afterward.

- [ ] **Step 3: Commit**

```bash
git add app/HapticClient.swift
git commit -m "feat: add HapticClient WebSocket + REST fallback"
```

---

## Task 13: AppCoordinator (wire it together)

**Files:**
- Create: `app/AppCoordinator.swift`
- Delete: the `AppCoordinator` stub from `app/_TempStubs.swift`

Owns config, the rule engine, the click tap, app context, the haptic client, and permission state; turns each press into a haptic. Publishes config to the UI.

- [ ] **Step 1: Implement AppCoordinator**

`app/AppCoordinator.swift`:
```swift
import SwiftUI
import BetterClickCore

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var config: Config
    @Published var hapticState: HapticClient.State = .disconnected
    @Published var hasPermission: Bool = PermissionsManager.hasInputMonitoring()

    private let store = ConfigStore(fileURL: ConfigStore.defaultFileURL())
    private let context = AppContext()
    private let haptics = HapticClient()
    private var clickTap: ClickTap?

    init() {
        config = (try? ConfigStore(fileURL: ConfigStore.defaultFileURL()).load()) ?? .default
    }

    func start() {
        haptics.onStateChange = { [weak self] state in
            Task { @MainActor in self?.hapticState = state }
        }
        haptics.connect()

        if !PermissionsManager.hasInputMonitoring() {
            PermissionsManager.requestInputMonitoring()
        }
        hasPermission = PermissionsManager.hasInputMonitoring()

        let tap = ClickTap { [weak self] button in
            self?.handlePress(button)
        }
        clickTap = tap
        _ = tap.start()
    }

    /// Called on the main run loop from the tap; resolve and fire.
    private func handlePress(_ button: MouseButton) {
        let engine = RuleEngine(config: config)
        guard let waveform = engine.resolve(button: button,
                                            bundleID: context.frontmostBundleID) else { return }
        haptics.fire(waveform)
    }

    // MARK: - Mutations from the settings UI

    func setMasterEnabled(_ on: Bool) {
        config.masterEnabled = on
        persist()
    }

    func setGlobalDefault(_ button: MouseButton, _ waveform: Waveform?) {
        if let waveform { config.globalDefaults[button] = waveform }
        else { config.globalDefaults[button] = nil }
        persist()
    }

    func setOverride(bundleID: String, button: MouseButton, setting: ButtonSetting?) {
        var override = config.appOverrides[bundleID] ?? [:]
        if let setting { override[button] = setting } else { override[button] = nil }
        if override.isEmpty { config.appOverrides[bundleID] = nil }
        else { config.appOverrides[bundleID] = override }
        persist()
    }

    func test(_ waveform: Waveform) {
        haptics.fire(waveform)
    }

    private func persist() {
        try? store.save(config)
    }
}
```

- [ ] **Step 2: Remove the AppCoordinator stub**

Delete the `AppCoordinator` class from `app/_TempStubs.swift` (leave the `SettingsView` stub until Task 14).

- [ ] **Step 3: Build and run end-to-end**

Run (⌘R) with HapticWeb running. With the default config (left → subtle_collision), click the left button in any app and confirm you feel the haptic. Toggle by editing config (next task) — for now confirm the wired path fires.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire ClickTap -> RuleEngine -> HapticClient in AppCoordinator"
```

---

## Task 14: SettingsView (UI)

**Files:**
- Create: `app/SettingsView.swift`
- Delete: `app/_TempStubs.swift`

Menu-bar window: master toggle, connection/permission status, global per-button waveform pickers (with a Test button each), and per-app overrides for the current frontmost app.

- [ ] **Step 1: Implement SettingsView**

`app/SettingsView.swift`:
```swift
import SwiftUI
import BetterClickCore

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("betterclick").font(.headline)
                Spacer()
                statusBadge
            }

            Toggle("Enabled", isOn: Binding(
                get: { coordinator.config.masterEnabled },
                set: { coordinator.setMasterEnabled($0) }))

            if !coordinator.hasPermission {
                Button("Grant Input Monitoring…") {
                    PermissionsManager.openInputMonitoringSettings()
                }
                .foregroundColor(.orange)
            }

            Divider()
            Text("Global defaults").font(.subheadline).bold()
            ForEach(MouseButton.allCases, id: \.self) { button in
                buttonRow(button)
            }

            Divider()
            Button("Quit betterclick") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 300)
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch coordinator.hapticState {
            case .connected: return ("Connected", .green)
            case .connecting: return ("Connecting…", .yellow)
            case .disconnected: return ("Offline", .red)
            }
        }()
        return Text(text).font(.caption).foregroundColor(color)
    }

    private func buttonRow(_ button: MouseButton) -> some View {
        HStack {
            Text(button.displayName).frame(width: 60, alignment: .leading)
            Picker("", selection: Binding(
                get: { coordinator.config.globalDefaults[button] },
                set: { coordinator.setGlobalDefault(button, $0) })) {
                Text("Off").tag(Waveform?.none)
                ForEach(Waveform.allCases, id: \.self) { wf in
                    Text(wf.apiName).tag(Waveform?.some(wf))
                }
            }
            .labelsHidden()
            Button("Test") {
                if let wf = coordinator.config.globalDefaults[button] { coordinator.test(wf) }
            }
            .disabled(coordinator.config.globalDefaults[button] == nil)
        }
    }
}
```

Note: per-app overrides for the frontmost app can be added as a follow-up row group using `coordinator.setOverride(bundleID:button:setting:)`; the global-defaults UI above is the minimum that exercises the full config path. Keep the first version focused (YAGNI) and extend if desired.

- [ ] **Step 2: Delete the temp stubs file**

```bash
rm app/_TempStubs.swift
```
Remove its reference from the Xcode project if present.

- [ ] **Step 3: Build and run full end-to-end**

Run (⌘R) with HapticWeb running:
- Status badge shows "Connected".
- Toggle Enabled off → clicks produce no haptic; on → they resume.
- Change Left's waveform, press Test → feel that waveform; left-click in any app → feel it.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add SettingsView menu-bar UI"
```

---

## Task 15: Packaging notes

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README with setup + signing notes**

`README.md`:
```markdown
# betterclick

Fires the Logitech MX Master 4 haptic motor on mouse-down, configurable per button
and per app. macOS menu-bar app.

## Prerequisites
1. Logitech MX Master 4 + Logi Options+ installed.
2. Install the **HapticWeb** plugin into Logi Options+:
   https://github.com/Fallstop/HapticWebPlugin
   (it exposes the local API betterclick sends to).

## Permissions
betterclick needs **Input Monitoring** (System Settings → Privacy & Security →
Input Monitoring) to detect clicks. It will prompt on first launch.

## Build
- Core logic: `cd BetterClickCore && swift test`
- App: open `betterclick.xcodeproj` in Xcode, run the `betterclick` scheme.
- For permission to persist across launches, sign the app (ad-hoc is fine for
  personal use): target → Signing & Capabilities → enable "Automatically manage
  signing", enable Hardened Runtime.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with setup and signing notes"
```

---

## Self-Review Notes (for the planner)

- **Spec coverage:** ClickTap (T11), AppContext (T9), RuleEngine (T5), HapticClient (T12), ConfigStore (T6), MenuBarUI (T14), PermissionsManager (T10), config model incl. global default + per-app override + first-run seeding (T4/T6), error handling for offline/permissions (T12/T14), zero-latency listen-only tap (T11), press-only (T11). All present.
- **Transport accuracy:** WS binary one-byte index (T7/T12), REST empty-body POST with Content-Length (T7/T12) — matches HapticWeb docs.
- **Type consistency:** `Waveform`, `MouseButton`, `Config`, `ButtonSetting`, `ButtonMap`, `AppOverride`, `RuleEngine.resolve(button:bundleID:)`, `ConfigStore.load/save`, `HapticMessage.webSocketPayload/restPath`, `HapticClient.fire/connect/State`, `AppCoordinator` mutation methods — names used consistently across tasks.
- **Known follow-ups (intentionally deferred, YAGNI):** per-app override UI rows (logic exists via `setOverride`); a richer offline banner. Noted in T14.
