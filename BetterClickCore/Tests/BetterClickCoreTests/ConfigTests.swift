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

    func test_decodesFromHumanReadableJSON() throws {
        let json = Data("""
        {
          "masterEnabled": true,
          "globalDefaults": { "left": "subtleCollision" },
          "appOverrides": {
            "com.apple.dt.Xcode": {
              "left": { "type": "waveform", "waveform": "completed" },
              "right": { "type": "off" }
            }
          }
        }
        """.utf8)
        let cfg = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertTrue(cfg.masterEnabled)
        XCTAssertEqual(cfg.globalDefaults[.left], .subtleCollision)
        XCTAssertEqual(cfg.appOverrides["com.apple.dt.Xcode"]?[.left], .waveform(.completed))
        XCTAssertEqual(cfg.appOverrides["com.apple.dt.Xcode"]?[.right], .off)
    }

    func test_encodesGlobalDefaultsAsButtonKeyedObject() throws {
        let enc = JSONEncoder()
        let data = try enc.encode(Config.default)
        let string = String(data: data, encoding: .utf8)!
        // Button-keyed OBJECT, not an array: the substring "left" appears as a JSON key.
        XCTAssertTrue(string.contains("\"left\""), "globalDefaults must be keyed by button name. Got: \(string)")
        XCTAssertFalse(string.contains("["), "no JSON arrays expected in config encoding. Got: \(string)")
    }

    private func roundTrip(_ s: ButtonSetting) throws -> ButtonSetting {
        try JSONDecoder().decode(ButtonSetting.self, from: JSONEncoder().encode(s))
    }
}
