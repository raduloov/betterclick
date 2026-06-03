import Foundation

/// Per-button setting inside a per-app override: explicitly off, or a waveform.
/// (Absence of a key in an override map means "fall through to global default".)
public enum ButtonSetting: Codable, Hashable {
    case off
    case waveform(Waveform)
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
