import SwiftUI
import VaultEngine
import ContainerCracker

/// Observable state managing the currently open vault.
@MainActor
final class VaultState: ObservableObject {
    @Published var vault: Vault?
    @Published var entries: [VaultEntry] = []
    @Published var selectedEntry: VaultEntry?
    @Published var currentParentID: String?
    @Published var breadcrumb: [(id: String?, name: String)] = []
    @Published var error: String?
    @Published var isImporting = false

    var isOpen: Bool { vault != nil }
    var vaultName: String {
        vault?.url.deletingPathExtension().lastPathComponent ?? "RetroRescue"
    }

    func createVault(at url: URL) {
        do {
            vault = try Vault.create(at: url)
            currentParentID = nil
            breadcrumb = [(nil, vaultName)]
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func openVault(at url: URL) {
        do {
            vault = try Vault.open(at: url)
            currentParentID = nil
            breadcrumb = [(nil, vaultName)]
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func closeVault() {
        vault = nil
        entries = []
        selectedEntry = nil
        currentParentID = nil
        breadcrumb = []
    }

    func refreshEntries() {
        guard let vault else { return }
        do {
            entries = try vault.entries(parentID: currentParentID)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func navigateInto(_ entry: VaultEntry) {
        guard entry.isDirectory else { return }
        currentParentID = entry.id
        breadcrumb.append((entry.id, entry.name))
        selectedEntry = nil
        refreshEntries()
    }

    func navigateUp() {
        guard breadcrumb.count > 1 else { return }
        breadcrumb.removeLast()
        currentParentID = breadcrumb.last?.id
        selectedEntry = nil
        refreshEntries()
    }

    func addFiles(urls: [URL]) {
        guard let vault else { return }
        isImporting = true
        defer { isImporting = false }

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent

                // Try to detect and unwrap classic Mac containers
                if let extracted = try ContainerCracker.extract(data: data, filename: filename) {
                    try vault.addFile(
                        name: extracted.name,
                        data: extracted.dataFork,
                        rsrc: extracted.rsrcFork.isEmpty ? nil : extracted.rsrcFork,
                        typeCode: extracted.typeCode,
                        creatorCode: extracted.creatorCode,
                        finderFlags: extracted.finderFlags,
                        created: extracted.created,
                        modified: extracted.modified,
                        parentID: currentParentID
                    )
                } else if let archiveFiles = try ContainerCracker.extractArchive(url: url) {
                    // Archive with multiple files — add all to vault
                    for file in archiveFiles {
                        try vault.addFile(
                            name: file.name,
                            data: file.dataFork,
                            rsrc: file.rsrcFork.isEmpty ? nil : file.rsrcFork,
                            typeCode: file.typeCode,
                            creatorCode: file.creatorCode,
                            finderFlags: file.finderFlags,
                            created: file.created,
                            modified: file.modified,
                            sourceArchive: filename,
                            parentID: currentParentID
                        )
                    }
                } else {
                    // Not a container — add as raw file
                    let rsrc: Data? = {
                        let rsrcURL = url.appendingPathComponent("..namedfork/rsrc")
                        return try? Data(contentsOf: rsrcURL)
                    }()
                    try vault.addFile(
                        name: filename,
                        data: data,
                        rsrc: rsrc,
                        parentID: currentParentID
                    )
                }
            } catch {
                self.error = "Failed to add \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
        refreshEntries()
    }

    func deleteSelected() {
        guard let vault, let entry = selectedEntry else { return }
        do {
            try vault.delete(id: entry.id)
            selectedEntry = nil
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
