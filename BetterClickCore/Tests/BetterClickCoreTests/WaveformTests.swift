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

    func test_initFromUnknownApiNameIsNil() {
        XCTAssertNil(Waveform(apiName: "does_not_exist"))
        XCTAssertNil(Waveform(apiName: ""))
    }
}
