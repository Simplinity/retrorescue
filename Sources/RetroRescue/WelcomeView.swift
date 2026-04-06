import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var state: VaultState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "archivebox")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("RetroRescue")
                .font(.largeTitle.weight(.medium))

            Text("Rescue vintage Mac files for the modern world")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("New Vault") { createVault() }
                    .controlSize(.large)
                Button("Open Vault...") { openVault() }
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createVault() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.retroVault]
        panel.nameFieldStringValue = "Untitled.retrovault"
        panel.message = "Choose where to create your vault"
        if panel.runModal() == .OK, let url = panel.url {
            state.createVault(at: url)
        }
    }

    private func openVault() {
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
