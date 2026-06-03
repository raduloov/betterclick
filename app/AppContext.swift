import AppKit

/// Tracks the frontmost application's bundle id (used for click-time rule
/// resolution) and, separately, the most recent *non-betterclick* app you used
/// (used by the per-app override UI, since opening our own menu makes us frontmost).
final class AppContext {
    private(set) var frontmostBundleID: String?
    private(set) var lastActiveBundleID: String?
    private(set) var lastActiveAppName: String?

    /// Invoked on the main thread whenever the last-active app changes.
    var onLastActiveChange: (() -> Void)?

    private let selfBundleID = Bundle.main.bundleIdentifier

    init() {
        let app = NSWorkspace.shared.frontmostApplication
        frontmostBundleID = app?.bundleIdentifier
        captureLastActive(app)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
    }

    @objc private func activeAppChanged(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        frontmostBundleID = app?.bundleIdentifier
        captureLastActive(app)
    }

    private func captureLastActive(_ app: NSRunningApplication?) {
        guard let app, let bundleID = app.bundleIdentifier, bundleID != selfBundleID,
              bundleID != lastActiveBundleID else { return }
        lastActiveBundleID = bundleID
        lastActiveAppName = app.localizedName
        onLastActiveChange?()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
