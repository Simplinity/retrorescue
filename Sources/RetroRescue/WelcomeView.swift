import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var state: VaultState
    @ObservedObject var library = VaultLibrary.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "archivebox")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("RetroRescue")
                    .font(.title.weight(.medium))

                Text("Rescue vintage Mac files for the modern world")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            HStack(spacing: 12) {
                Button("New Vault") { createVault() }
                Button("Open Vault...") { openVault() }
            }
            .padding(.bottom, 24)

            // Recent vaults
            if !library.vaults.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recent Vaults")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    List(library.vaults) { vault in
                        VaultListRow(vault: vault)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if vault.exists {
                                    state.openVault(at: URL(fileURLWithPath: vault.path))
                                }
                            }
                            .contextMenu {
                                if vault.exists {
                                    Button("Open") {
                                        state.openVault(at: URL(fileURLWithPath: vault.path))
                                    }
                                }
                                Button("Remove from List") {
                                    library.remove(path: vault.path)
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createVault() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.retroVault]
        panel.nameFieldStringValue = "Untitled.retrovault"
        if panel.runModal() == .OK, let url = panel.url {
            state.createVault(at: url)
        }
    }

    private func openVault() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.retroVault]
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            state.openVault(at: url)
        }
    }
}

struct VaultListRow: View {
    let vault: VaultLibrary.KnownVault

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.title2)
                .foregroundStyle(vault.exists ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(vault.name)
                    .fontWeight(.medium)
                    .foregroundStyle(vault.exists ? .primary : .secondary)

                Text(vault.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if !vault.exists {
                Text("Missing")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(vault.lastOpened, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .opacity(vault.exists ? 1 : 0.6)
    }
}
