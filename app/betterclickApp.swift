import SwiftUI
import BetterClickCore

@main
struct BetterClickApp: App {
    var body: some Scene {
        MenuBarExtra("betterclick", systemImage: "cursorarrow.click.2") {
            // Minimal shell — proves the BetterClickCore link works.
            Text("betterclick — \(Waveform.allCases.count) waveforms")
            Divider()
            Button("Quit betterclick") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.window)
    }
}
