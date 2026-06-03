import Foundation

/// The five mouse buttons betterclick can react to.
public enum MouseButton: String, CaseIterable, Codable, Hashable {
    case left
    case right
    case middle
    case back
    case forward

    /// Maps a Core Graphics `kCGMouseEventButtonNumber` value to a button.
    /// 0 = left, 1 = right, 2 = middle, 3 = back, 4 = forward.
    public init?(cgButtonNumber: Int) {
        switch cgButtonNumber {
        case 0: self = .left
        case 1: self = .right
        case 2: self = .middle
        case 3: self = .back
        case 4: self = .forward
        default: return nil
        }
    }

    /// Human-readable label for the settings UI.
    public var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .middle: return "Middle"
        case .back: return "Back"
        case .forward: return "Forward"
        }
    }
}
