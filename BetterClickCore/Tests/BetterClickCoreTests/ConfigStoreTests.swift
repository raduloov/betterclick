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
