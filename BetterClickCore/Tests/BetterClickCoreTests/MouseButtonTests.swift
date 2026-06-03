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
