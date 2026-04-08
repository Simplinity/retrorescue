import Foundation
import VaultEngine
import ContainerCracker

/// A tree node wrapping a VaultEntry with lazy-loaded children.
/// Used to drive SwiftUI's outline List for Finder-style file browsing.
class FileTreeNode: Identifiable, ObservableObject {
    let entry: VaultEntry
    private let vault: Vault?
    var id: String { entry.id }

    @Published var children: [FileTreeNode]?

    var isExtractable: Bool {
        !entry.isDirectory
            && (UnarExtractor.canHandle(filename: entry.name)
                || HFSExtractor.canHandle(filename: entry.name))
            && (children == nil || children!.isEmpty)
    }

    init(entry: VaultEntry, vault: Vault?) {
        self.entry = entry
        self.vault = vault
        // No DB queries in init! Determine expandability from entry properties only.
        if entry.isDirectory {
            self.children = []  // expandable
        } else {
            self.children = nil  // leaf — children loaded on demand via reloadChildren()
        }
    }

    /// Load children on demand (called when user expands a node).
    func loadChildrenIfNeeded() {
        guard let vault else { return }
        // Only load once — if children is empty array (placeholder), fill it
        guard let existing = children, existing.isEmpty else { return }
        let kids = (try? vault.entries(parentID: entry.id)) ?? []
        self.children = kids.isEmpty ? [] : kids.map { FileTreeNode(entry: $0, vault: vault) }
    }

    /// Reload children from vault (after extraction).
    func reloadChildren() {
        guard let vault else { return }
        let kids = (try? vault.entries(parentID: entry.id)) ?? []
        if !kids.isEmpty {
            self.children = kids.map { FileTreeNode(entry: $0, vault: vault) }
        }
    }

    /// Build a flat tree of nodes for a given parent.
    static func buildTree(parentID: String, vault: Vault) -> [FileTreeNode] {
        let entries = (try? vault.entries(parentID: parentID)) ?? []
        return entries.map { FileTreeNode(entry: $0, vault: vault) }
    }
}
