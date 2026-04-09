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
        if entry.isDirectory {
            self.children = []  // expandable, loaded on demand
        } else if Self.isExtractableType(entry.name) {
            // Archives might have extracted children — mark as expandable
            self.children = []  // will check lazily
        } else {
            self.children = nil  // leaf
        }
    }

    private static func isExtractableType(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["img", "image", "dsk", "disk", "hfs", "hfv", "iso", "toast",
                "sit", "sit", "zip", "rar", "7z", "cpt", "sea", "bin",
                "2mg", "2img", "po", "do", "bny", "bqy", "acu"].contains(ext)
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
        let topLevel = (try? vault.entries(parentID: parentID)) ?? []
        return topLevel.map { entry in
            let node = FileTreeNode(entry: entry, vault: vault)
            if node.children != nil {
                let kids = (try? vault.entries(parentID: entry.id)) ?? []
                if kids.isEmpty {
                    node.children = nil  // no disclosure triangle
                } else if kids.count <= 200 {
                    node.children = kids.map { FileTreeNode(entry: $0, vault: vault) }
                } else {
                    // >200 children: flat nodes, no further nesting
                    node.children = kids.map { FileTreeNode(entry: $0, vault: nil) }
                }
            }
            return node
        }
    }
}
