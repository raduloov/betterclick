import ApplicationServices
import IOKit.hid
import AppKit

/// Checks and requests the access a CGEventTap needs.
enum PermissionsManager {
    /// True when the process may receive mouse events via an event tap.
    static func hasInputMonitoring() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Prompts the user for Input Monitoring (no-op if already decided).
    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Opens System Settings at the Input Monitoring pane.
    static func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
}
