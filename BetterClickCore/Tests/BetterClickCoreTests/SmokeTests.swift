import XCTest
@testable import BetterClickCore

final class SmokeTests: XCTestCase {
    func test_packageLoads() {
        XCTAssertTrue(betterClickCoreLoaded)
    }
}
