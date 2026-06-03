import SwiftUI
import BetterClickCore

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var config: Config
    @Published var hapticState: HapticClient.State = .disconnected
    @Published var hasPermission: Bool = PermissionsManager.hasInputMonitoring()

    private let store = ConfigStore(fileURL: ConfigStore.defaultFileURL())
    private let context = AppContext()
    private let haptics = HapticClient()
    private var clickTap: ClickTap?

    init() {
        config = (try? ConfigStore(fileURL: ConfigStore.defaultFileURL()).load()) ?? .default
    }

    func start() {
        haptics.onStateChange = { [weak self] state in
            Task { @MainActor in self?.hapticState = state }
        }
        haptics.connect()

        if !PermissionsManager.hasInputMonitoring() {
            PermissionsManager.requestInputMonitoring()
        }
        hasPermission = PermissionsManager.hasInputMonitoring()

        let tap = ClickTap { [weak self] button in
            MainActor.assumeIsolated {
                self?.handlePress(button)
            }
        }
        clickTap = tap
        _ = tap.start()
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
