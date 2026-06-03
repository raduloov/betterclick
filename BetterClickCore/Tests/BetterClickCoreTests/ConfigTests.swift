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
