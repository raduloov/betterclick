import Foundation

/// Builds the transport payloads HapticWeb expects.
public enum HapticMessage {
    /// One binary byte: the waveform index (0–14), sent over `wss://.../ws`.
    public static func webSocketPayload(for waveform: Waveform) -> Data {
        Data([UInt8(waveform.index)])
    }

    /// REST path for `POST https://local.jmw.nz:41443/haptic/{apiName}`.
    public static func restPath(for waveform: Waveform) -> String {
        "/haptic/\(waveform.apiName)"
    }

    /// Base host for both transports.
    public static let host = "local.jmw.nz"
    public static let port = 41443
}
