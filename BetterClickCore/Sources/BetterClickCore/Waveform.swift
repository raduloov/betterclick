import Foundation

/// The 15 haptic waveforms exposed by HapticWeb, in its index order (0–14).
public enum Waveform: String, CaseIterable, Codable, Hashable {
    case sharpCollision
    case sharpStateChange
    case knock
    case dampCollision
    case mad
    case ringing
    case subtleCollision
    case completed
    case jingle
    case dampStateChange
    case firework
    case happyAlert
    case wave
    case angryAlert
    case square

    /// Binary index sent over the WebSocket (matches HapticWeb's order exactly).
    public var index: Int {
        Waveform.allCases.firstIndex(of: self)!
    }

    /// snake_case name used by the REST endpoint `/haptic/{apiName}`.
    public var apiName: String {
        switch self {
        case .sharpCollision: return "sharp_collision"
        case .sharpStateChange: return "sharp_state_change"
        case .knock: return "knock"
        case .dampCollision: return "damp_collision"
        case .mad: return "mad"
        case .ringing: return "ringing"
        case .subtleCollision: return "subtle_collision"
        case .completed: return "completed"
        case .jingle: return "jingle"
        case .dampStateChange: return "damp_state_change"
        case .firework: return "firework"
        case .happyAlert: return "happy_alert"
        case .wave: return "wave"
        case .angryAlert: return "angry_alert"
        case .square: return "square"
        }
    }

    public init?(apiName: String) {
        guard let match = Waveform.allCases.first(where: { $0.apiName == apiName }) else {
            return nil
        }
        self = match
    }
}
