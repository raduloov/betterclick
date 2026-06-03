import Foundation
import BetterClickCore

/// Sends haptic triggers to the local HapticWeb plugin.
/// Primary transport: a persistent WebSocket (binary index byte).
/// Fallback: REST POST while the socket is not connected.
///
/// The URLSession is created with `delegateQueue: .main`, so every delegate
/// callback and send/receive completion runs on the main thread — the same
/// context as `connect()` / `fire()`. All mutable state is therefore touched
/// only on the main thread, with no locks.
final class HapticClient: NSObject, URLSessionWebSocketDelegate {
    enum State { case connecting, connected, disconnected }

    private(set) var state: State = .disconnected { didSet { onStateChange?(state) } }
    var onStateChange: ((State) -> Void)?

    private lazy var session: URLSession = {
        URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)
    }()
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
        // state advances to .connected in didOpenWithProtocol once the
        // WebSocket handshake actually completes.
    }

    func fire(_ waveform: Waveform) {
        if let ws, state == .connected {
            let payload = HapticMessage.webSocketPayload(for: waveform)
            ws.send(.data(payload)) { [weak self] error in
                if error != nil { self?.handleFailure(for: ws) }
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
                self.receiveLoop(task)
            case .failure:
                self.handleFailure(for: task)
            }
        }
    }

    /// Tears down the given task (if it is still the current one) and schedules
    /// a reconnect with exponential backoff. Idempotent across the several
    /// callbacks that can report the same failure.
    private func handleFailure(for task: URLSessionWebSocketTask) {
        guard task === ws else { return }   // stale callback from an old socket
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

    // MARK: - URLSessionWebSocketDelegate (all invoked on .main)

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        guard webSocketTask === ws else { return }
        state = .connected
        reconnectDelay = 0.5
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        handleFailure(for: webSocketTask)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        // Catches connection-level failures (server offline, TLS error, etc.).
        if let socket = task as? URLSessionWebSocketTask {
            handleFailure(for: socket)
        }
    }
}
