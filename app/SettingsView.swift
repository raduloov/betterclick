import SwiftUI
import BetterClickCore

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("betterclick").font(.headline)
                    Spacer()
                    statusBadge
                }

                Toggle("Enabled", isOn: Binding(
                    get: { coordinator.config.masterEnabled },
                    set: { coordinator.setMasterEnabled($0) }))

                Toggle("Launch at login", isOn: Binding(
                    get: { coordinator.launchAtLogin },
                    set: { coordinator.setLaunchAtLogin($0) }))

                if !coordinator.hasPermission {
                    Button("Grant Input Monitoring…") {
                        PermissionsManager.openInputMonitoringSettings()
                    }
                    .foregroundColor(.orange)
                }

                Divider()
                Text("Global defaults").font(.subheadline).bold()
                ForEach(MouseButton.allCases, id: \.self) { button in
                    globalRow(button)
                }

                Divider()
                perAppSection

                if !configuredApps.isEmpty {
                    Divider()
                    Text("Configured apps").font(.subheadline).bold()
                    ForEach(configuredApps, id: \.self) { bundleID in
                        configuredAppRow(bundleID)
                    }
                }

                Divider()
                Button("Quit betterclick") { NSApplication.shared.terminate(nil) }
            }
            .padding()
            .frame(width: 300)
        }
        .frame(width: 300, height: 520)
        .onAppear { coordinator.refreshPermissionAndArm() }
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch coordinator.hapticState {
            case .connected: return ("Connected", .green)
            case .connecting: return ("Connecting…", .yellow)
            case .disconnected: return ("Offline", .red)
            }
        }()
        return Text(text).font(.caption).foregroundColor(color)
    }

    // MARK: - Global defaults

    private func globalRow(_ button: MouseButton) -> some View {
        HStack {
            Text(button.displayName).frame(width: 60, alignment: .leading)
            Picker("", selection: Binding(
                get: { coordinator.config.globalDefaults[button] },
                set: { coordinator.setGlobalDefault(button, $0) })) {
                Text("Off").tag(Waveform?.none)
                ForEach(Waveform.allCases, id: \.self) { wf in
                    Text(wf.apiName).tag(Waveform?.some(wf))
                }
            }
            .labelsHidden()
            Button("Test") {
                if let wf = coordinator.config.globalDefaults[button] { coordinator.test(wf) }
            }
            .disabled(coordinator.config.globalDefaults[button] == nil)
        }
    }

    // MARK: - Per-app override (targets the last app you used)

    @ViewBuilder
    private var perAppSection: some View {
        Text("Per-app override").font(.subheadline).bold()
        if let bundleID = coordinator.lastActiveBundleID {
            Text(coordinator.appName(for: bundleID))
                .font(.caption).foregroundColor(.secondary)
            ForEach(MouseButton.allCases, id: \.self) { button in
                overrideRow(button, bundleID: bundleID)
            }
        } else {
            Text("Switch to an app, then reopen this menu to configure it.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private func overrideRow(_ button: MouseButton, bundleID: String) -> some View {
        HStack {
            Text(button.displayName).frame(width: 60, alignment: .leading)
            Picker("", selection: Binding(
                get: { coordinator.overrideSetting(for: bundleID, button: button) },
                set: { coordinator.setOverride(bundleID: bundleID, button: button, setting: $0) })) {
                Text("Use default").tag(ButtonSetting?.none)
                Text("Off").tag(ButtonSetting?.some(ButtonSetting.off))
                ForEach(Waveform.allCases, id: \.self) { wf in
                    Text(wf.apiName).tag(ButtonSetting?.some(ButtonSetting.waveform(wf)))
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - Configured apps list

    private var configuredApps: [String] {
        coordinator.config.appOverrides.keys.sorted()
    }

    private func configuredAppRow(_ bundleID: String) -> some View {
        HStack {
            Text(coordinator.appName(for: bundleID)).lineLimit(1)
            Spacer()
            Button(role: .destructive) {
                coordinator.clearOverrides(for: bundleID)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
