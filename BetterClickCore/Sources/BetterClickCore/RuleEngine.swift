import Foundation

/// Pure resolver: given a button and the frontmost app's bundle ID,
/// decides which waveform (if any) to fire.
public struct RuleEngine {
    public let config: Config

    public init(config: Config) {
        self.config = config
    }

    public func resolve(button: MouseButton, bundleID: String?) -> Waveform? {
        guard config.masterEnabled else { return nil }

        if let bundleID, let override = config.appOverrides[bundleID],
           let setting = override[button] {
            switch setting {
            case .off: return nil
            case .waveform(let w): return w
            }
        }

        return config.globalDefaults[button]
    }
}
