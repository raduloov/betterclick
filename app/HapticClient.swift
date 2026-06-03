import Foundation
import BetterClickCore

/// Sends haptic triggers to the local HapticWeb plugin.
/// Primary transport: a persistent WebSocket (binary index byte).
/// Fallback: REST POST while the socket is reconnecting.
final class HapticClient {
    enum State { case connecting, connected, disconnected }

    private(set) var state: State = .disconnected { didSet { onStateChange?(state) } }
    var onStateChange: ((State) -> Void)?

    private let session = URLSession(configuration: .ephemeral)
    private var ws: URLSessionWebSocketTask?
    private var reconnectDelay: TimeInterval = 0.5
    private let maxReconnectDelay: TimeInterval = 10
    private var wsURL: URL {
        URL(string: "wss://\(HapticMessage.host):\(HapticMessage.port)/ws")!
    }

    func connect() {
        state = .connecting
        let task = session.webSocketTask(with: wsURL)
        ws = task
        task.resume()
        receiveLoop(task)
        // A successful handshake is implied once the first receive succeeds or
        // a send completes; mark connected optimistically and let errors reset it.
        state = .connected
        reconnectDelay = 0.5
    }

    func fire(_ waveform: Waveform) {
        if let ws, state == .connected {
            let payload = HapticMessage.webSocketPayload(for: waveform)
            ws.send(.data(payload)) { [weak self] error in
                if error != nil { self?.handleFailure() }
            }
        } else {
            sendREST(waveform)
        }
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.receiveLoop(task)            // keep listening
            case .failure:
                self.handleFailure()
            }
        }
    }

    private func handleFailure() {
        ws?.cancel(with: .goingAway, reason: nil)
        ws = nil
        state = .disconnected
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }

    /// REST fallback: POST with an empty body (Content-Length: 0 required).
    private func sendREST(_ waveform: Waveform) {
        let urlString = "https://\(HapticMessage.host):\(HapticMessage.port)\(HapticMessage.restPath(for: waveform))"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        request.httpBody = Data()
        session.dataTask(with: request).resume()
    }
}
