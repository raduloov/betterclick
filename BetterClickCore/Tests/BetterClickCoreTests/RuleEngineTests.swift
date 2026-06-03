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

    func test_buttonAbsentFromOverrideFallsThroughToGlobal() {
        let cfg = Config(masterEnabled: true,
                         globalDefaults: [.left: .subtleCollision, .right: .knock],
                         appOverrides: ["com.app": [.left: .off]])
        let engine = RuleEngine(config: cfg)
        // .right is not in the override → falls through to global default
        XCTAssertEqual(engine.resolve(button: .right, bundleID: "com.app"), .knock)
        // .left IS overridden off
        XCTAssertNil(engine.resolve(button: .left, bundleID: "com.app"))
    }
}
