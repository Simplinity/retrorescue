import SwiftUI

@main
struct RetroRescueApp: App {
    @StateObject private var state = VaultState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(state)
                .frame(minWidth: 700, minHeight: 450)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Vault...") {
                    openVaultPanel()
                }
                .keyboardShortcut("o")
            }
        }
    }

    private func openVaultPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.retroVault]
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Choose a .retrovault bundle"
        if panel.runModal() == .OK, let url = panel.url {
            state.openVault(at: url)
        }
    }
}
