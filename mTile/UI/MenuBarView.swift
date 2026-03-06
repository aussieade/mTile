import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Toggle Overlay") {
            AppCoordinator.shared?.onAction(.toggle)
        }
        .keyboardShortcut("g", modifiers: [.command, .option])

        Divider()

        Button("Snap to Neighbors") {
            AppCoordinator.shared?.onAction(.grow)
        }

        Divider()

        Button("Settings...") {
            openSettingsWindow()
        }

        Divider()

        Button("Quit mTile") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for window in NSApp.windows where !window.isKind(of: NSPanel.self) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}
