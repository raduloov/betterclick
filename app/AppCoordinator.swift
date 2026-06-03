import SwiftUI
import AppKit
import BetterClickCore

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var config: Config
    @Published var hapticState: HapticClient.State = .disconnected
    @Published var hasPermission: Bool = PermissionsManager.hasInputMonitoring()

    private let store: ConfigStore
    private let context = AppContext()
    private let haptics = HapticClient()
    private var clickTap: ClickTap?

    init() {
        let store = ConfigStore(fileURL: ConfigStore.defaultFileURL())
        self.store = store
        config = (try? store.load()) ?? .default
    }

    func start() {
        haptics.onStateChange = { [weak self] state in
            Task { @MainActor in self?.hapticState = state }
        }
        haptics.connect()

        if !PermissionsManager.hasInputMonitoring() {
            PermissionsManager.requestInputMonitoring()
        }
        armClickTap()

        // Re-arm when the user returns to the app after granting permission.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissionAndArm() }
        }
    }

    /// Re-check Input Monitoring access and arm the tap if it isn't running yet.
    /// Safe to call repeatedly (e.g. from the settings window's onAppear).
    func refreshPermissionAndArm() {
        hasPermission = PermissionsManager.hasInputMonitoring()
        if clickTap == nil { armClickTap() }
    }

    private func armClickTap() {
        hasPermission = PermissionsManager.hasInputMonitoring()
        guard hasPermission else { return }
        let tap = ClickTap { [weak self] button in
            MainActor.assumeIsolated { self?.handlePress(button) }
        }
        if tap.start() {
            clickTap = tap
        } else {
            NSLog("betterclick: Input Monitoring granted but event tap creation failed")
        }
    }

    /// Called on the main run loop from the tap; resolve and fire.
    private func handlePress(_ button: MouseButton) {
        let engine = RuleEngine(config: config)
        guard let waveform = engine.resolve(button: button,
                                            bundleID: context.frontmostBundleID) else { return }
        haptics.fire(waveform)
    }

    // MARK: - Mutations from the settings UI

    func setMasterEnabled(_ on: Bool) {
        config.masterEnabled = on
        persist()
    }

    func setGlobalDefault(_ button: MouseButton, _ waveform: Waveform?) {
        if let waveform { config.globalDefaults[button] = waveform }
        else { config.globalDefaults[button] = nil }
        persist()
    }

    func setOverride(bundleID: String, button: MouseButton, setting: ButtonSetting?) {
        var override = config.appOverrides[bundleID] ?? [:]
        if let setting { override[button] = setting } else { override[button] = nil }
        if override.isEmpty { config.appOverrides[bundleID] = nil }
        else { config.appOverrides[bundleID] = override }
        persist()
    }

    func test(_ waveform: Waveform) {
        haptics.fire(waveform)
    }

    private func persist() {
        try? store.save(config)
    }
}
