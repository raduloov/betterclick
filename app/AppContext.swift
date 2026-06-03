import AppKit

/// Tracks the frontmost application's bundle identifier, updated on app
/// activation so reads inside the click path are O(1) and lock-free.
final class AppContext {
    private(set) var frontmostBundleID: String?

    init() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
    }

    @objc private func activeAppChanged(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        frontmostBundleID = app?.bundleIdentifier
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
