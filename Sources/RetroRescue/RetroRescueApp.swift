import SwiftUI
import ContainerCracker

@main
struct RetroRescueApp: App {
    @StateObject private var state = VaultState()

    init() {
        // Configure tools from ToolChain
        let tc = ToolChain.shared
        if let unarPath = tc.unar {
            UnarExtractor.overridePath = unarPath
        }
        if let lsarPath = tc.lsar {
            UnarExtractor.lsarOverridePath = lsarPath
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(state)
                .frame(minWidth: 700, minHeight: 450)
        }
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Vault...") {
                    newVaultPanel()
                }
                .keyboardShortcut("n")

                Button("Open Vault...") {
                    openVaultPanel()
                }
                .keyboardShortcut("o")

                Divider()

                Button("Add Files...") {
                    addFilesPanel()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(!state.isOpen)

                Button("Close Vault") {
                    state.closeVault()
                }
                .keyboardShortcut("w")
                .disabled(!state.isOpen)
            }

            // Archive menu
            CommandMenu("Archive") {
                Button("Extract Contents") {
                    state.extractSelected()
                }
                .keyboardShortcut("e")
                .disabled(!state.selectedIsArchive || state.selectedHasExtracted)

                Divider()

                Button("Delete Selected") {
                    state.deleteSelected()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(state.selectedEntry == nil)
            }
        }
    }

    // MARK: - Panels

    private func newVaultPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.retroVault]
        panel.nameFieldStringValue = "Untitled.retrovault"
        if panel.runModal() == .OK, let url = panel.url {
            state.createVault(at: url)
        }
    }

    private func openVaultPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.retroVault]
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            state.openVault(at: url)
        }
    }

    private func addFilesPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            state.addFiles(urls: panel.urls)
        }
    }
}
