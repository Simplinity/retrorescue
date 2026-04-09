import SwiftUI
import VaultEngine
import ContainerCracker

@MainActor
final class VaultState: ObservableObject {
    @Published var vault: Vault?
    @Published var entries: [VaultEntry] = []           // top-level vault items
    @Published var selectedEntry: VaultEntry?
    @Published var extractedEntries: [VaultEntry] = []  // children of selected archive
    @Published var extractedTree: [FileTreeNode] = []   // tree nodes for outline view
    @Published var previewingEntry: VaultEntry?          // file being previewed in right panel
    @Published var previewText: String?                  // text content for inline preview
    @Published var previewImage: NSImage?                // image for inline preview (PICT etc.)
    @Published var selectedExtractedID: String?          // selected file in extracted tree
    @Published var error: String?
    @Published var isImporting = false
    @Published var searchText: String = ""
    @Published var searchResults: [VaultEntry]?      // nil = not searching
    @Published var getInfoEntry: VaultEntry?          // entry for Get Info sheet
    @Published var cachedDiskImageInfo: DiskImageParser.ImageInfo?  // cached, not computed

    // Selective import state
    @Published var showSelectiveImport = false
    @Published var selectiveImportItems: [SelectiveImportItem] = []
    @Published var selectiveImportTitle: String?
    @Published var selectiveImportEntryID: String?

    // K12: Filters
    @Published var filterTypeCode: String = ""
    @Published var filterCreatorCode: String = ""
    @Published var filterHasRsrc: Bool? = nil          // nil = any, true = has rsrc, false = no rsrc
    @Published var filterMinSize: Int? = nil
    @Published var filterMaxSize: Int? = nil

    // K13/K14: View mode
    enum ViewMode: String, CaseIterable { case list, grid, columns }
    @Published var viewMode: ViewMode = .list

    // K19: Progress
    @Published var progressMessage: String?
    @Published var progressFraction: Double = 0
    @Published var isProcessing = false

    /// Generic item for selective import (works for both unar and HFS).
    struct SelectiveImportItem: Identifiable, Hashable {
        let id: String
        let name: String
        let path: String         // full path for extraction
        let size: Int64
        let isDirectory: Bool
    }

    var isOpen: Bool { vault != nil }

    var isSearching: Bool {
        !searchText.isEmpty
    }

    // K17: Window title with vault name + count
    var vaultName: String {
        vault?.url.deletingPathExtension().lastPathComponent ?? "RetroRescue"
    }

    var windowTitle: String {
        let name = vaultName
        let count = entries.count
        return count > 0 ? "\(name) — \(count) items" : name
    }

    // K12: Filtered extracted entries
    var filteredExtractedEntries: [VaultEntry] {
        var result = extractedEntries
        if !filterTypeCode.isEmpty {
            result = result.filter { ($0.typeCode ?? "").localizedCaseInsensitiveContains(filterTypeCode) }
        }
        if !filterCreatorCode.isEmpty {
            result = result.filter { ($0.creatorCode ?? "").localizedCaseInsensitiveContains(filterCreatorCode) }
        }
        if let hasRsrc = filterHasRsrc {
            result = result.filter { hasRsrc ? ($0.rsrcForkSize ?? 0) > 0 : ($0.rsrcForkSize ?? 0) == 0 }
        }
        if let min = filterMinSize { result = result.filter { $0.dataForkSize >= Int64(min) } }
        if let max = filterMaxSize { result = result.filter { $0.dataForkSize <= Int64(max) } }
        return result
    }

    var isFiltering: Bool {
        !filterTypeCode.isEmpty || !filterCreatorCode.isEmpty || filterHasRsrc != nil
            || filterMinSize != nil || filterMaxSize != nil
    }

    func clearFilters() {
        filterTypeCode = ""
        filterCreatorCode = ""
        filterHasRsrc = nil
        filterMinSize = nil
        filterMaxSize = nil
    }

    // MARK: - L5/L6: Thumbnails

    /// Generate thumbnails for all extracted entries of the selected archive.
    func generateThumbnailsForSelected() {
        guard let vault, let entry = selectedEntry else { return }
        let kids = (try? vault.entries(parentID: entry.id)) ?? []
        for kid in kids {
            ThumbnailGenerator.generateAndStore(vault: vault, entry: kid)
        }
    }

    /// Rebuild all thumbnails in the vault.
    func rebuildAllThumbnails() {
        guard let vault else { return }
        isProcessing = true
        progressMessage = "Generating thumbnails…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (generated, _) = ThumbnailGenerator.rebuildAll(vault: vault) { name, fraction in
                DispatchQueue.main.async {
                    self?.progressMessage = "Thumbnail: \(name)"
                    self?.progressFraction = fraction
                }
            }
            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.progressMessage = nil
                self?.error = "Generated \(generated) thumbnails."
            }
        }
    }

    /// Is the selected entry an archive we can extract?
    var selectedIsArchive: Bool {
        guard let entry = selectedEntry, !entry.isDirectory else { return false }
        return Self.isExtractable(entry.name)
    }

    /// Does the selected entry have extracted children?
    var selectedHasExtracted: Bool {
        !extractedEntries.isEmpty
    }

    /// Is the selected extracted file itself an extractable archive?
    var selectedExtractedIsArchive: Bool {
        guard let id = selectedExtractedID,
              let vault,
              let entry = try? vault.entry(id: id) else { return false }
        let hasKids = !((try? vault.entries(parentID: id)) ?? []).isEmpty
        return !hasKids && Self.isExtractable(entry.name)
    }

    /// Refresh cached disk image info for the selected entry.
    /// Called once on selection change for disk image extensions only.
    func refreshDiskImageInfo() {
        guard let vault, let entry = selectedEntry else {
            cachedDiskImageInfo = nil
            return
        }
        // Read only enough for header detection (84 bytes for DC42, 64 for 2IMG)
        // Skip checksum validation here (that's for Get Info)
        guard let data = try? vault.dataFork(for: entry.id) else {
            cachedDiskImageInfo = nil
            return
        }
        let format = DiskImageParser.detect(data: data)
        switch format {
        case .diskCopy42:
            // Parse header only (no full checksum — too slow for UI)
            var info = DiskImageParser.parseDiskCopy42(data)
            info?.checksumValid = true  // assume valid, verify in Get Info
            cachedDiskImageInfo = info
        case .twoIMG:
            cachedDiskImageInfo = DiskImageParser.parse2IMG(data)
        case .woz, .moof:
            cachedDiskImageInfo = DiskImageParser.parseWozMoofInfo(data)
        default:
            cachedDiskImageInfo = nil
        }
    }

    // MARK: - Vault lifecycle

    func createVault(at url: URL) {
        do {
            vault = try Vault.create(at: url)
            VaultLibrary.shared.register(url: url)
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func openVault(at url: URL) {
        do {
            vault = try Vault.open(at: url)
            VaultLibrary.shared.register(url: url)
            refreshEntries()
            // L8: Index vault contents for Spotlight search
            if let vault { SpotlightIndexer.shared.indexVault(vault) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func closeVault() {
        vault = nil
        entries = []
        selectedEntry = nil
        extractedEntries = []
        extractedTree = []
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
        cachedDiskImageInfo = nil
        loadExtractedEntries()
        if let e = entry, Self.isDiskImageExtension(e.name) {
            refreshDiskImageInfo()
        }
    }

    /// Check if filename has a disk image extension (not archive).
    private static func isDiskImageExtension(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        let diskExts: Set<String> = ["img", "image", "dsk", "disk", "hfs", "hfv",
                                      "dart", "dc42", "2mg", "2img", "po", "do",
                                      "d13", "woz", "moof"]
        return diskExts.contains(ext)
    }

    private func loadExtractedEntries() {
        guard let vault, let entry = selectedEntry else {
            extractedEntries = []
            extractedTree = []
            selectedExtractedID = nil
            previewingEntry = nil
            previewText = nil
            previewImage = nil
            return
        }
        do {
            extractedEntries = try vault.entries(parentID: entry.id)
            extractedTree = FileTreeNode.buildTree(parentID: entry.id, vault: vault)
        } catch {
            extractedEntries = []
            extractedTree = []
        }
    }

    /// Load children of a specific entry (for tree expansion in right panel).
    func children(of parentID: String) -> [VaultEntry] {
        guard let vault else { return [] }
        return (try? vault.entries(parentID: parentID)) ?? []
    }

    // MARK: - Search

    func performSearch() {
        guard let vault else {
            searchResults = nil
            return
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            searchResults = nil
            return
        }
        do {
            searchResults = try vault.search(query: query)
        } catch {
            searchResults = []
        }
    }

    func clearSearch() {
        searchText = ""
        searchResults = nil
        previewingEntry = nil
        previewText = nil
        previewImage = nil
    }

    /// Select a search result — show its info in the inspector.
    func selectSearchResult(_ entry: VaultEntry) {
        previewFile(entry)
    }

    // MARK: - Add files

    func addFiles(urls: [URL]) {
        guard let vault else { return }
        isProcessing = true
        progressMessage = "Importing \(urls.count) file(s)…"
        progressFraction = 0.1
        defer { isProcessing = false; progressMessage = nil }

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

    // MARK: - M1: Download from URL

    func downloadFromURL(_ url: URL) {
        guard let vault else { return }
        isProcessing = true
        progressMessage = "Downloading \(url.lastPathComponent)…"
        progressFraction = 0.1

        Task {
            do {
                let entryID = try await WebDownloader.shared.downloadAndImport(
                    url: url, vault: vault) { [weak self] msg, fraction in
                        DispatchQueue.main.async {
                            self?.progressMessage = msg
                            self?.progressFraction = fraction
                        }
                    }
                await MainActor.run {
                    isProcessing = false
                    progressMessage = nil
                    refreshEntries()
                    // Auto-extract if it's an archive
                    if let entry = try? vault.entry(id: entryID),
                       Self.isExtractable(entry.name) {
                        select(entry)
                        extractEntry(id: entryID)
                    }
                    // Re-index for Spotlight
                    SpotlightIndexer.shared.reindexVault(vault)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    progressMessage = nil
                    self.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Delete

    func deleteSelected() {
        guard let vault, let entry = selectedEntry else { return }
        do {
            // Recursively delete all descendants first
            try deleteDescendants(of: entry.id)
            try vault.delete(id: entry.id)
            selectedEntry = nil
            extractedEntries = []
            extractedTree = []
            refreshEntries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Recursively delete all children and their children.
    private func deleteDescendants(of parentID: String) throws {
        guard let vault else { return }
        let kids = try vault.entries(parentID: parentID)
        for child in kids {
            try deleteDescendants(of: child.id)
            try vault.delete(id: child.id)
        }
    }

    // MARK: - Extract archive

    /// Check if a file is extractable (archive, disk image, etc.)
    static func isExtractable(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        if ext == "bny" || ext == "bqy" || ext == "acu" { return true } // Native parsers
        return UnarExtractor.canHandle(filename: name)
            || (HFSExtractor.canHandle(filename: name) && ToolChain.shared.canExtractHFS)
    }

    // MARK: - Preview & Open

    /// Called when a file is selected in the extracted tree.
    /// Auto-previews if the file is previewable.
    func selectExtractedFile(id: String?) {
        selectedExtractedID = id
        guard let vault, let id else {
            previewingEntry = nil
            previewText = nil
            previewImage = nil
            return
        }
        guard let entry = try? vault.entry(id: id),
              !entry.isDirectory else {
            previewingEntry = nil
            previewText = nil
            previewImage = nil
            return
        }
        // Delegate to unified preview cascade (I6-I12)
        previewFile(entry)
    }

    /// Preview a file from the extracted tree.
    func previewFile(_ entry: VaultEntry) {
        previewingEntry = entry
        previewText = nil
        previewImage = nil

        guard let vault else { return }

        // 1. Text preview (highest priority)
        if FilePreviewHelper.isTextPreviewable(entry: entry) {
            previewText = FilePreviewHelper.readTextContent(vault: vault, entry: entry)
            return
        }

        // 2. MacPaint (.PNTG) — I7
        if FilePreviewHelper.isMacPaint(entry: entry) {
            previewImage = FilePreviewHelper.decodeMacPaint(vault: vault, entry: entry)
            if previewImage != nil { return }
        }

        // 3. PICT conversion
        if FilePreviewHelper.isPICT(entry: entry) {
            if let pngData = FilePreviewHelper.convertPICTtoPNG(vault: vault, entry: entry) {
                previewImage = NSImage(data: pngData)
                if previewImage != nil { return }
            }
        }

        // 4. Icon from resource fork — I8
        if let icon = FilePreviewHelper.iconFromResourceFork(vault: vault, entry: entry) {
            previewImage = icon
            return
        }

        // 5. Resource fork overview — I12
        if let overview = FilePreviewHelper.resourceForkOverview(vault: vault, entry: entry) {
            previewText = overview
            return
        }

        // 6. Font preview — I10
        if let fontInfo = FilePreviewHelper.fontPreview(vault: vault, entry: entry) {
            previewText = fontInfo
            return
        }

        // 7. Hex dump fallback — I6 (CRITICAL: every file gets SOMETHING)
        previewText = FilePreviewHelper.hexDumpPreview(vault: vault, entry: entry)
    }

    /// Quick Look a file using macOS Quick Look.
    func quickLook(_ entry: VaultEntry) {
        guard let vault else { return }
        guard let qlPath = ToolChain.shared.qlmanage else {
            self.error = "Quick Look not available"
            return
        }
        guard let url = try? FilePreviewHelper.writeTempFile(vault: vault, entry: entry) else {
            self.error = "Could not write temp file for preview"
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: qlPath)
        process.arguments = ["-p", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    /// Open a file in the default macOS app.
    func openInDefaultApp(_ entry: VaultEntry) {
        guard let vault else { return }
        FilePreviewHelper.openInDefaultApp(vault: vault, entry: entry)
    }

    /// Check if an entry has already been extracted.
    func isAlreadyExtracted(id: String) -> Bool {
        guard let vault else { return false }
        let kids = (try? vault.entries(parentID: id)) ?? []
        return !kids.isEmpty
    }

    func extractSelected() {
        guard let entry = selectedEntry else { return }
        extractEntry(id: entry.id)
    }

    /// Extract any entry by ID. Works recursively — extracted files that are
    /// themselves archives can be extracted again, building a deeper tree.
    /// Extract all files from an entry (the "Extract" action).
    func extractEntry(id: String) {
        guard let vault else { return }
        guard let entry = try? vault.entry(id: id) else { return }
        let existing = (try? vault.entries(parentID: id)) ?? []
        guard existing.isEmpty else { return }
        extractAllFromEntry(id: id)
    }

    /// Show the selective import sheet (the "Extract Selected…" action).
    func showSelectiveImportSheet(id: String) {
        guard let vault else { return }
        guard let entry = try? vault.entry(id: id) else { return }

        do {
            let archiveData = try vault.dataFork(for: id)
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(entry.name)
            try archiveData.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            var items: [SelectiveImportItem] = []
            var title = entry.name
            let ext1 = (entry.name as NSString).pathExtension.lowercased()

            if ext1 == "bny" || ext1 == "bqy" {
                let allFiles = try BinaryIIParser.parseAll(archiveData)
                items = allFiles.enumerated().map { (i, f) in
                    SelectiveImportItem(id: String(i), name: f.name, path: f.name,
                                       size: Int64(f.dataFork.count), isDirectory: false)
                }
            } else if ext1 == "acu" {
                let allFiles = try AppleLinkParser.parseAll(archiveData)
                items = allFiles.enumerated().map { (i, f) in
                    SelectiveImportItem(id: String(i), name: f.name, path: f.name,
                                       size: Int64(f.dataFork.count), isDirectory: false)
                }
            } else if UnarExtractor.canHandle(filename: entry.name) {
                let archiveItems = try UnarExtractor.listContents(archiveURL: tempFile)
                items = archiveItems.map { item in
                    SelectiveImportItem(id: item.id, name: item.name, path: item.name,
                                       size: item.size, isDirectory: false)
                }
            } else if HFSExtractor.canHandle(filename: entry.name),
                      let hm = ToolChain.shared.hmount,
                      let hl = ToolChain.shared.hls,
                      let hu = ToolChain.shared.humount {
                let (hfsItems, volName) = try HFSExtractor.listContents(
                    imageURL: tempFile, hmountPath: hm, hlsPath: hl, humountPath: hu)
                items = hfsItems.map { item in
                    SelectiveImportItem(id: item.id, name: item.name, path: item.path,
                                       size: 0, isDirectory: item.isDirectory)
                }
                title = volName ?? entry.name
            }

            selectiveImportItems = items
            selectiveImportTitle = title
            selectiveImportEntryID = id
            showSelectiveImport = true
        } catch {
            self.error = "Could not list contents: \(error.localizedDescription)"
        }
    }

    /// Import selected files from the selective import sheet.
    func performSelectiveImport(selectedPaths: [String]) {
        guard let vault, let entryID = selectiveImportEntryID else { return }
        guard let entry = try? vault.entry(id: entryID) else { return }

        showSelectiveImport = false
        isProcessing = true
        progressMessage = "Importing selected files…"
        progressFraction = 0.1
        defer { isProcessing = false; progressMessage = nil }

        do {
            let archiveData = try vault.dataFork(for: entryID)
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(entry.name)
            try archiveData.write(to: tempFile)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            let extracted: [ExtractedFile]
            let ext2 = (entry.name as NSString).pathExtension.lowercased()

            if ext2 == "bny" || ext2 == "bqy" {
                let allFiles = try BinaryIIParser.parseAll(archiveData)
                extracted = allFiles.filter { selectedPaths.contains($0.name) }
            } else if ext2 == "acu" {
                let allFiles = try AppleLinkParser.parseAll(archiveData)
                extracted = allFiles.filter { selectedPaths.contains($0.name) }
            } else if UnarExtractor.canHandle(filename: entry.name) {
                extracted = try UnarExtractor.extract(archiveURL: tempFile, onlyFiles: selectedPaths)
            } else if HFSExtractor.canHandle(filename: entry.name),
                      let hm = ToolChain.shared.hmount,
                      let hl = ToolChain.shared.hls,
                      let hc = ToolChain.shared.hcopy,
                      let hu = ToolChain.shared.humount {
                extracted = try HFSExtractor.extractSelected(
                    imageURL: tempFile, selectedPaths: selectedPaths,
                    hmountPath: hm, hlsPath: hl, hcopyPath: hc, humountPath: hu)
            } else {
                self.error = "No extraction tool available"
                return
            }

            for file in extracted {
                try vault.addFile(
                    name: file.name,
                    data: file.dataFork,
                    rsrc: file.rsrcFork.isEmpty ? nil : file.rsrcFork,
                    typeCode: file.typeCode,
                    creatorCode: file.creatorCode,
                    finderFlags: file.finderFlags,
                    sourceArchive: entry.name,
                    parentID: entryID
                )
            }
            loadExtractedEntries()
        } catch {
            self.error = "Import failed: \(error.localizedDescription)"
        }
    }

    /// Extract all files from an entry (archives, not HFS).
    private func extractAllFromEntry(id: String) {
        guard let vault else { return }
        guard let entry = try? vault.entry(id: id) else { return }

        // Prevent double extraction
        let existing = (try? vault.entries(parentID: id)) ?? []
        guard existing.isEmpty else { return }

        isProcessing = true
        progressMessage = "Extracting \(entry.name)…"
        progressFraction = 0.1

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let archiveData = try vault.dataFork(for: id)
                let tempFile = FileManager.default.temporaryDirectory
                    .appendingPathComponent(entry.name)
                try archiveData.write(to: tempFile)
                defer { try? FileManager.default.removeItem(at: tempFile) }

                DispatchQueue.main.async { self.progressMessage = "Parsing \(entry.name)…"; self.progressFraction = 0.2 }

                let extracted: [ExtractedFile]
                let ext = (entry.name as NSString).pathExtension.lowercased()

            if ext == "bny" || ext == "bqy" {
                extracted = try BinaryIIParser.parseAll(archiveData)
            } else if ext == "acu" {
                extracted = try AppleLinkParser.parseAll(archiveData)
            } else if UnarExtractor.canHandle(filename: entry.name) {
                extracted = try UnarExtractor.extract(archiveURL: tempFile)
            } else if HFSExtractor.canHandle(filename: entry.name),
                      let hm = ToolChain.shared.hmount,
                      let hl = ToolChain.shared.hls,
                      let hc = ToolChain.shared.hcopy,
                      let hu = ToolChain.shared.humount {
                extracted = try HFSExtractor.extract(
                    imageURL: tempFile,
                    hmountPath: hm, hlsPath: hl,
                    hcopyPath: hc, humountPath: hu)
            } else {
                self.error = "No extraction tool available for \(entry.name)"
                return
            }
            guard !extracted.isEmpty else {
                DispatchQueue.main.async { self.isProcessing = false; self.progressMessage = nil; self.error = "Archive appears to be empty" }
                return
            }

            let total = extracted.count
            DispatchQueue.main.async { self.progressMessage = "Storing \(total) files…"; self.progressFraction = 0.5 }

            for (i, file) in extracted.enumerated() {
                try vault.addFile(
                    name: file.name,
                    data: file.dataFork,
                    rsrc: file.rsrcFork.isEmpty ? nil : file.rsrcFork,
                    typeCode: file.typeCode,
                    creatorCode: file.creatorCode,
                    finderFlags: file.finderFlags,
                    sourceArchive: entry.name,
                    parentID: id
                )
                if i % 10 == 0 {
                    let frac = 0.5 + 0.4 * Double(i) / Double(max(1, total))
                    DispatchQueue.main.async { self.progressFraction = frac; self.progressMessage = "Storing file \(i+1)/\(total)…" }
                }
            }

            DispatchQueue.main.async {
                self.progressMessage = "Finalizing…"
                self.progressFraction = 0.95
                self.loadExtractedEntries()
                // L5: Auto-generate thumbnails for newly extracted files
                self.generateThumbnailsForSelected()
                // L8: Re-index vault for Spotlight
                SpotlightIndexer.shared.reindexVault(vault)
                self.isProcessing = false
                self.progressMessage = nil
            }
            } catch {
                DispatchQueue.main.async { self.isProcessing = false; self.progressMessage = nil; self.error = "Extract failed: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: - Convert to modern format

    /// Write a vault entry to a temp file for dragging/Quick Look.
    /// Restores resource fork via extended attribute if present.
    func writeTempFileForExport(_ entry: VaultEntry) -> URL? {
        guard let vault else { return nil }
        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("retrorescue-export")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let destURL = tempDir.appendingPathComponent(entry.name)
            // Remove old file if exists
            try? FileManager.default.removeItem(at: destURL)
            // Write data fork
            let data = try vault.dataFork(for: entry.id)
            try data.write(to: destURL)
            // Write resource fork as extended attribute
            if entry.hasResourceFork {
                let rsrc = try vault.rsrcFork(for: entry.id)
                if !rsrc.isEmpty {
                    try destURL.withUnsafeFileSystemRepresentation { path in
                        guard let path else { return }
                        rsrc.withUnsafeBytes { buf in
                            setxattr(path, "com.apple.ResourceFork", buf.baseAddress, rsrc.count, 0, 0)
                        }
                    }
                }
            }
            return destURL
        } catch {
            self.error = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Export a file to a user-chosen location via NSSavePanel.
    func exportToFinder(_ entry: VaultEntry) {
        guard let tempURL = writeTempFileForExport(entry) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = entry.name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        do {
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.copyItem(at: tempURL, to: destURL)
        } catch {
            self.error = "Export failed: \(error.localizedDescription)"
        }
    }

    /// Export a file to temp and reveal it in Finder.
    func revealInFinder(_ entry: VaultEntry) {
        guard let tempURL = writeTempFileForExport(entry) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([tempURL])
    }

    /// Convert a file to a modern format (e.g. PICT → PNG).
    /// The converted file is added to the vault next to the original.
    func convertToModernFormat(entry: VaultEntry) {
        guard let vault else { return }

        guard let (fileName, convertedData) = ConversionEngine.convert(entry: entry, vault: vault) else {
            self.error = "No converter available for this file type."
            return
        }
        do {
            try vault.addFile(
                name: fileName,
                data: convertedData,
                sourceArchive: entry.name,
                parentID: entry.parentID
            )
            loadExtractedEntries()
        } catch {
            self.error = "Failed to save converted file: \(error.localizedDescription)"
        }
    }
}
