import Foundation

/// Per-button setting inside a per-app override: explicitly off, or a waveform.
/// (Absence of a key in an override map means "fall through to global default".)
public enum ButtonSetting: Hashable {
    case off
    case waveform(Waveform)
}

// MARK: - Explicit stable Codable for ButtonSetting
//
// On-disk format:
//   off:      { "type": "off" }
//   waveform: { "type": "waveform", "waveform": "<rawValue>" }
//
// We do NOT rely on synthesised Codable here because Swift synthesises
// enum-with-associated-values Codable as {"caseName": {"_0": value}},
// which is fragile and not human-readable.
extension ButtonSetting: Codable {
    private enum CodingKeys: String, CodingKey { case type, waveform }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "off":
            self = .off
        case "waveform":
            self = .waveform(try c.decode(Waveform.self, forKey: .waveform))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c,
                debugDescription: "Unknown ButtonSetting type: \(other)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .off:
            try c.encode("off", forKey: .type)
        case .waveform(let w):
            try c.encode("waveform", forKey: .type)
            try c.encode(w, forKey: .waveform)
        }
    }
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
