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
