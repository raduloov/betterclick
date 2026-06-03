import SwiftUI
import BetterClickCore

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("betterclick").font(.headline)
                Spacer()
                statusBadge
            }

            Toggle("Enabled", isOn: Binding(
                get: { coordinator.config.masterEnabled },
                set: { coordinator.setMasterEnabled($0) }))

            if !coordinator.hasPermission {
                Button("Grant Input Monitoring…") {
                    PermissionsManager.openInputMonitoringSettings()
                }
                .foregroundColor(.orange)
            }

            Divider()
            Text("Global defaults").font(.subheadline).bold()
            ForEach(MouseButton.allCases, id: \.self) { button in
                buttonRow(button)
            }

            Divider()
            Button("Quit betterclick") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 300)
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

    private func buttonRow(_ button: MouseButton) -> some View {
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
}
