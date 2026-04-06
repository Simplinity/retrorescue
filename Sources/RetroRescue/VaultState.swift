import SwiftUI
import VaultEngine
import ContainerCracker

@MainActor
final class VaultState: ObservableObject {
    @Published var vault: Vault?
    @Published var entries: [VaultEntry] = []           // top-level vault items
    @Published var selectedEntry: VaultEntry?
    @Published var extractedEntries: [VaultEntry] = []  // children of selected archive
    @Published var error: String?
    @Published var isImporting = false

    var isOpen: Bool { vault != nil }

    var vaultName: String {
        vault?.url.deletingPathExtension().lastPathComponent ?? "RetroRescue"
    }

    /// Is the selected entry an archive we can extract?
    var selectedIsArchive: Bool {
        guard let entry = selectedEntry, !entry.isDirectory else { return false }
        return UnarExtractor.canHandle(filename: entry.name)
    }

    /// Does the selected entry have extracted children?
    var selectedHasExtracted: Bool {
        !extractedEntries.isEmpty
    }

    // MARK: - Vault lifecycle

    func createVault(at url: URL) {
        do {
            vault = try Vault.create(at: url)
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func openVault(at url: URL) {
        do {
            vault = try Vault.open(at: url)
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func closeVault() {
        vault = nil
        entries = []
        selectedEntry = nil
        extractedEntries = []
    }

    func refreshEntries() {
        guard let vault else { return }
        do {
            // Only show root-level entries (no parentID)
            entries = try vault.entries(parentID: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Selection

    func select(_ entry: VaultEntry?) {
        selectedEntry = entry
        loadExtractedEntries()
    }

    private func loadExtractedEntries() {
        guard let vault, let entry = selectedEntry else {
            extractedEntries = []
            return
        }
        do {
            extractedEntries = try vault.entries(parentID: entry.id)
        } catch {
            extractedEntries = []
        }
    }

    /// Load children of a specific entry (for tree expansion in right panel).
    func children(of parentID: String) -> [VaultEntry] {
        guard let vault else { return [] }
        return (try? vault.entries(parentID: parentID)) ?? []
    }

    // MARK: - Add files

    func addFiles(urls: [URL]) {
        guard let vault else { return }
        isImporting = true
        defer { isImporting = false }

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent

                // Unwrap encoding wrappers (MacBinary, BinHex)
                if let unwrapped = try? ContainerCracker.extract(data: data, filename: filename) {
                    try vault.addFile(
                        name: unwrapped.name,
                        data: unwrapped.dataFork,
                        rsrc: unwrapped.rsrcFork.isEmpty ? nil : unwrapped.rsrcFork,
                        typeCode: unwrapped.typeCode,
                        creatorCode: unwrapped.creatorCode,
                        finderFlags: unwrapped.finderFlags,
                        created: unwrapped.created,
                        modified: unwrapped.modified
                    )
                } else {
                    // Store as-is
                    let rsrc: Data? = {
                        let rsrcURL = url.appendingPathComponent("..namedfork/rsrc")
                        return try? Data(contentsOf: rsrcURL)
                    }()
                    try vault.addFile(name: filename, data: data, rsrc: rsrc)
                }
            } catch {
                self.error = "Failed to add \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
        refreshEntries()
    }

    // MARK: - Delete

    func deleteSelected() {
        guard let vault, let entry = selectedEntry else { return }
        do {
            // Delete extracted children first
            for child in extractedEntries {
                try vault.delete(id: child.id)
            }
            try vault.delete(id: entry.id)
            selectedEntry = nil
            extractedEntries = []
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Extract archive

    func extractSelected() {
        guard let vault, let entry = selectedEntry else { return }
        isImporting = true
        defer { isImporting = false }

        do {
            let archiveData = try vault.dataFork(for: entry.id)
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(entry.name)
            try archiveData.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            let extracted = try UnarExtractor.extract(archiveURL: tempFile)
            guard !extracted.isEmpty else {
                self.error = "Archive appears to be empty"
                return
            }

            // Store extracted files as children of the archive
            for file in extracted {
                try vault.addFile(
                    name: file.name,
                    data: file.dataFork,
                    rsrc: file.rsrcFork.isEmpty ? nil : file.rsrcFork,
                    typeCode: file.typeCode,
                    creatorCode: file.creatorCode,
                    finderFlags: file.finderFlags,
                    sourceArchive: entry.name,
                    parentID: entry.id
                )
            }

            loadExtractedEntries()
        } catch {
            self.error = "Extract failed: \(error.localizedDescription)"
        }
    }
}
