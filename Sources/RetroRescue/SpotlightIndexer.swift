import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import VaultEngine

/// L8: Spotlight indexer for RetroRescue vaults.
/// Indexes vault contents so files are searchable via macOS Spotlight (⌘Space).
///
/// Uses Core Spotlight API (CSSearchableIndex) — the modern approach for app-bundled
/// document types. Index persists even when the app is closed.
public class SpotlightIndexer {

    /// Shared instance for the app.
    public static let shared = SpotlightIndexer()

    private let index = CSSearchableIndex(name: "com.simplinity.retrorescue")
    private let domainID = "com.simplinity.retrorescue.vault"

    private init() {}

    // MARK: - Index a Vault

    /// Index all contents of a vault for Spotlight search.
    /// Call this when a vault is opened or after extraction.
    public func indexVault(_ vault: Vault) {
        let vaultName = vault.url.deletingPathExtension().lastPathComponent
        let vaultID = vault.url.path

        guard let entries = try? vault.entries() else { return }

        // Collect all entries (top-level + children)
        var allEntries: [VaultEntry] = []
        for entry in entries {
            allEntries.append(entry)
            if let kids = try? vault.entries(parentID: entry.id) {
                allEntries.append(contentsOf: kids)
            }
        }

        // Build searchable items
        var items: [CSSearchableItem] = []

        // 1. Index the vault itself
        let vaultAttrs = CSSearchableItemAttributeSet(contentType: .package)
        vaultAttrs.title = vaultName
        vaultAttrs.contentDescription = "\(allEntries.count) files in RetroVault archive"
        vaultAttrs.kind = "RetroVault Archive"
        vaultAttrs.contentURL = vault.url
        let vaultItem = CSSearchableItem(
            uniqueIdentifier: "vault:\(vaultID)",
            domainIdentifier: domainID,
            attributeSet: vaultAttrs)
        items.append(vaultItem)

        // 2. Index each file in the vault
        for entry in allEntries where !entry.isDirectory {
            let attrs = CSSearchableItemAttributeSet(contentType: .data)
            attrs.title = entry.name
            attrs.displayName = entry.name

            // Searchable metadata
            var description: [String] = []
            if let tc = entry.typeCode, !tc.isEmpty { description.append("Type: \(tc)") }
            if let cc = entry.creatorCode, !cc.isEmpty { description.append("Creator: \(cc)") }
            description.append("Size: \(ByteCountFormatter.string(fromByteCount: entry.dataForkSize, countStyle: .file))")
            if entry.rsrcForkSize > 0 {
                description.append("Resource fork: \(ByteCountFormatter.string(fromByteCount: entry.rsrcForkSize, countStyle: .file))")
            }
            attrs.contentDescription = description.joined(separator: " · ")
            attrs.kind = FilePreviewHelper.fileTypeDescription(entry: entry) ?? "Classic Mac File"

            // Additional searchable fields
            attrs.contentURL = vault.url
            if let tc = entry.typeCode { attrs.addedDate = nil; attrs.comment = tc }

            // Keywords for search: filename parts, type code, creator, vault name
            var keywords = entry.name.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            if let tc = entry.typeCode { keywords.append(tc) }
            if let cc = entry.creatorCode { keywords.append(cc) }
            keywords.append(vaultName)
            keywords.append("retro")
            keywords.append("classic mac")
            attrs.keywords = keywords

            // Thumbnail if available
            if let thumbData = vault.thumbnail(for: entry.id) {
                attrs.thumbnailData = thumbData
            }

            let item = CSSearchableItem(
                uniqueIdentifier: "file:\(vaultID)/\(entry.id)",
                domainIdentifier: domainID,
                attributeSet: attrs)
            // Items expire after 30 days if not re-indexed
            item.expirationDate = Date().addingTimeInterval(30 * 24 * 3600)
            items.append(item)
        }

        // Submit to Spotlight index
        index.indexSearchableItems(items) { error in
            if let error {
                print("Spotlight indexing error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Remove from Index

    /// Remove all Spotlight entries for a specific vault.
    public func deindexVault(at url: URL) {
        let vaultID = url.path
        index.deleteSearchableItems(withIdentifiers: ["vault:\(vaultID)"]) { _ in }
        // Delete all file entries for this vault
        index.deleteSearchableItems(withDomainIdentifiers: [domainID]) { _ in }
    }

    /// Remove all RetroRescue entries from Spotlight.
    public func deindexAll() {
        index.deleteAllSearchableItems { error in
            if let error {
                print("Spotlight deindex error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Re-index

    /// Re-index a vault (delete old entries, then index fresh).
    public func reindexVault(_ vault: Vault) {
        let vaultID = vault.url.path
        index.deleteSearchableItems(withIdentifiers: ["vault:\(vaultID)"]) { [weak self] _ in
            self?.indexVault(vault)
        }
    }

    /// Handle Spotlight continuation (when user taps a search result).
    /// Returns the vault URL and entry ID from the activity's userInfo.
    public static func parseSpotlightActivity(_ activity: NSUserActivity) -> (vaultURL: URL, entryID: String?)? {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }

        if identifier.hasPrefix("vault:") {
            let path = String(identifier.dropFirst(6))
            return (URL(fileURLWithPath: path), nil)
        } else if identifier.hasPrefix("file:") {
            let parts = String(identifier.dropFirst(5)).components(separatedBy: "/")
            if parts.count >= 2 {
                let vaultPath = parts.dropLast().joined(separator: "/")
                let entryID = parts.last!
                return (URL(fileURLWithPath: vaultPath), entryID)
            }
        }
        return nil
    }
}
