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
