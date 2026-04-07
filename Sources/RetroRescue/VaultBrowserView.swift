import SwiftUI
import VaultEngine
import ContainerCracker

struct VaultBrowserView: View {
    @EnvironmentObject var state: VaultState

    var body: some View {
        NavigationSplitView {
            archiveList
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 350)
        } detail: {
            detailPanel
        }
        .navigationTitle(state.vaultName)
        .searchable(text: $state.searchText, prompt: "Search files…")
        .onSubmit(of: .search) { state.performSearch() }
        .onChange(of: state.searchText) { _, newValue in
            if newValue.isEmpty {
                state.clearSearch()
            } else {
                state.performSearch()
            }
        }
        .toolbar { toolbarContent }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .sheet(isPresented: $state.showSelectiveImport) {
            SelectiveImportView()
                .environmentObject(state)
        }
    }

    // MARK: - Left panel: archive list

    private var archiveList: some View {
        VStack(spacing: 0) {
            if state.entries.isEmpty {
                emptyDropZone
            } else {
                List(state.entries, selection: Binding(
                    get: { state.selectedEntry?.id },
                    set: { id in
                        let entry = state.entries.first { $0.id == id }
                        state.select(entry)
                    }
                )) { entry in
                    FileRowView(entry: entry, isExtracted: state.isAlreadyExtracted(id: entry.id))
                        .contextMenu { sidebarContextMenu(for: entry) }
                }
            }
            statusBar
        }
    }

    private var emptyDropZone: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Drop files here")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("or click + to add")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Right panel: detail + file browser

    private var detailPanel: some View {
        Group {
            if state.isSearching {
                searchResultsPanel
            } else if let entry = state.selectedEntry {
                VStack(spacing: 0) {
                    // Info section: auto-sizes to content, NOT resizable
                    archiveInfoSection(entry)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    if state.selectedIsArchive && !state.selectedHasExtracted {
                        extractPromptCard(entry)
                            .padding(.horizontal)
                        Spacer(minLength: 0)
                    }

                    if state.selectedHasExtracted {
                        Divider()

                        if state.previewingEntry != nil {
                            // File browser + preview: resizable divider between them
                            VSplitView {
                                extractedFilesSection
                                    .frame(maxWidth: .infinity, minHeight: 100, idealHeight: 300, maxHeight: .infinity)

                                filePreviewSection(state.previewingEntry!)
                                    .frame(maxWidth: .infinity, minHeight: 80, idealHeight: 200, maxHeight: .infinity)
                            }
                        } else {
                            // File browser only: takes all remaining space
                            extractedFilesSection
                        }
                    }

                    if !state.selectedHasExtracted && !state.selectedIsArchive {
                        Spacer(minLength: 0)
                    }
                }
            } else if state.entries.isEmpty {
                ContentUnavailableView {
                    Label("Empty vault", systemImage: "archivebox")
                } description: {
                    Text("Drop classic Mac files, disk images, or StuffIt archives onto this window.")
                } actions: {
                    Button("Add Files...") { addFilesPanel() }
                }
            } else {
                ContentUnavailableView {
                    Label("No selection", systemImage: "cursorarrow.click.2")
                } description: {
                    Text("Select an item from the sidebar.")
                }
            }
        }
    }

    private func archiveInfoSection(_ entry: VaultEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
                .font(.title2)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                if let tc = entry.typeCreatorDisplay {
                    GridRow {
                        Text("Type/Creator").foregroundStyle(.secondary)
                        Text(tc).font(.system(.body, design: .monospaced))
                    }
                }
                GridRow {
                    Text("Data fork").foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: entry.dataForkSize, countStyle: .file))
                }
                if entry.hasResourceFork {
                    GridRow {
                        Text("Resource fork").foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: entry.rsrcForkSize, countStyle: .file))
                    }
                }
                if let created = entry.created {
                    GridRow {
                        Text("Created").foregroundStyle(.secondary)
                        Text(created, style: .date)
                    }
                }
                if let modified = entry.modified {
                    GridRow {
                        Text("Modified").foregroundStyle(.secondary)
                        Text(modified, style: .date)
                    }
                }
            }

            if state.selectedHasExtracted {
                Text("\(state.extractedEntries.count) extracted files")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    /// Card prompting the user to extract an archive.
    private func extractPromptCard(_ entry: VaultEntry) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text("This is a \(archiveTypeLabel(entry.name))")
                .font(.headline)

            Text("Extract its contents to browse the files inside.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                state.extractSelected()
            } label: {
                Label("Extract Contents", systemImage: "archivebox.fill")
                    .frame(minWidth: 160)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
    }

    private func archiveTypeLabel(_ name: String) -> String {
        let lower = name.lowercased()
        // Compound extensions first
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") { return "compressed tar archive" }
        if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") { return "bzip2 tar archive" }
        if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") { return "XZ-compressed tar archive" }
        if lower.hasSuffix(".mar.xz") { return "XZ-compressed Macintosh archive" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "sit": return "StuffIt archive"
        case "sitx": return "StuffIt X archive"
        case "sea": return "self-extracting StuffIt archive"
        case "cpt": return "Compact Pro archive"
        case "dd": return "DiskDoubler archive"
        case "pit": return "PackIt archive"
        case "7z": return "7-Zip archive"
        case "rar": return "RAR archive"
        case "zip": return "ZIP archive"
        case "gz": return "Gzip-compressed file"
        case "bz2": return "Bzip2-compressed file"
        case "xz": return "XZ-compressed file"
        case "lzma": return "LZMA-compressed file"
        case "zst": return "Zstandard-compressed file"
        case "tar": return "tar archive"
        case "cab": return "Windows Cabinet archive"
        case "arj": return "ARJ archive"
        case "arc": return "ARC archive"
        case "zoo": return "Zoo archive"
        case "lzh", "lha": return "LHA/LZH archive"
        case "mar": return "Macintosh archive"
        case "iso": return "ISO 9660 disc image"
        case "dmg": return "macOS disk image"
        case "bin": return "raw CD/DVD image"
        case "cue": return "CUE sheet (CD layout)"
        case "nrg": return "Nero disc image"
        case "cdr": return "macOS disc master image"
        case "toast": return "Toast disc image"
        case "img", "image": return "HFS disk image"
        case "mar", "dart": return "DART disk archive"
        case "dsk", "disk": return "HFS disk image"
        case "hfs", "hfv": return "HFS volume"
        case "toast": return "Toast disc image"
        default: return "compressed archive"
        }
    }

    private var extractedFilesSection: some View {
        List(state.extractedTree, children: \.children, selection: Binding(
            get: { state.selectedExtractedID },
            set: { state.selectExtractedFile(id: $0) }
        )) { node in
            ExtractedFileRow(node: node) { entryID in
                state.extractEntry(id: entryID)
            } onExtractSelected: { entryID in
                state.showSelectiveImportSheet(id: entryID)
            } onQuickLook: { entry in
                state.quickLook(entry)
            } onOpen: { entry in
                state.openInDefaultApp(entry)
            } onPreview: { entry in
                state.previewFile(entry)
            } onConvert: { entry in
                state.convertToModernFormat(entry: entry)
            } onMessage: { msg in
                state.error = msg
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Search Results

    private var searchResultsPanel: some View {
        VStack(spacing: 0) {
            if let results = state.searchResults, !results.isEmpty {
                List {
                    ForEach(groupedSearchResults(results), id: \.archive) { group in
                        Section(group.archive) {
                            ForEach(group.entries) { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: "doc")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.name)
                                            .lineLimit(1)
                                        if let desc = FilePreviewHelper.fileTypeDescription(entry: entry) {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Spacer()
                                    if let tc = entry.typeCreatorDisplay {
                                        Text(tc)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(ByteCountFormatter.string(fromByteCount: entry.dataForkSize, countStyle: .file))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    state.selectSearchResult(entry)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(state.searchText)\"")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            // Inspector for selected search result
            if let entry = state.previewingEntry, state.isSearching {
                Divider()
                filePreviewSection(entry)
                    .frame(maxHeight: 200)
            }
        }
    }

    private struct SearchGroup {
        let archive: String
        let entries: [VaultEntry]
    }

    private func groupedSearchResults(_ results: [VaultEntry]) -> [SearchGroup] {
        var groups: [String: [VaultEntry]] = [:]
        for entry in results {
            let source = entry.sourceArchive ?? "Vault root"
            groups[source, default: []].append(entry)
        }
        return groups
            .sorted { $0.key < $1.key }
            .map { SearchGroup(archive: $0.key, entries: $0.value) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { state.closeVault() } label: {
                Label("Close Vault", systemImage: "chevron.left")
            }
            .help("Close vault and return to library")
        }
        ToolbarItem(placement: .primaryAction) {
            Button { addFilesPanel() } label: {
                Label("Add Files", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .destructiveAction) {
            Button { state.deleteSelected() } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(state.selectedEntry == nil)
        }
    }

    private var statusBar: some View {
        HStack {
            Text("\(state.entries.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            if state.isSearching, let r = state.searchResults {
                Spacer()
                Text("\(r.count) results")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func sidebarContextMenu(for entry: VaultEntry) -> some View {
        let isArchive = VaultState.isExtractable(entry.name)
        let isExtracted = state.isAlreadyExtracted(id: entry.id)

        Button { state.quickLook(entry) } label: {
            Label("Quick Look", systemImage: "eye")
        }
        Button { state.openInDefaultApp(entry) } label: {
            Label("Open", systemImage: "arrow.up.forward.app")
        }
        Button { showNotImplemented("Get Info") } label: {
            Label("Get Info", systemImage: "info.circle")
        }

        Divider()

        Button {
            state.select(entry)
            state.extractSelected()
        } label: {
            Label("Extract", systemImage: "archivebox")
        }
        .disabled(!isArchive || isExtracted)

        Button {
            state.select(entry)
            state.showSelectiveImportSheet(id: entry.id)
        } label: {
            Label("Extract Selected…", systemImage: "checklist")
        }
        .disabled(!isArchive || isExtracted)

        Divider()

        Button { showNotImplemented("Export") } label: {
            Label("Export to Finder…", systemImage: "square.and.arrow.up")
        }
        Button { showNotImplemented("Reveal in Finder") } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }
        Button {
            state.select(entry)
            state.convertToModernFormat(entry: entry)
        } label: {
            if let target = FilePreviewHelper.conversionTarget(entry: entry) {
                Label("Convert to \(target)", systemImage: "arrow.triangle.2.circlepath")
            } else {
                Label("Convert to Modern Format…", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .disabled(!FilePreviewHelper.canConvert(entry: entry))

        Divider()

        Button(role: .destructive) {
            state.select(entry)
            state.deleteSelected()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func showNotImplemented(_ feature: String) {
        state.error = "\(feature) is coming in a future version."
    }

    // MARK: - File Preview

    private func filePreviewSection(_ entry: VaultEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mini inspector header
            HStack(spacing: 8) {
                Image(systemName: inspectorIcon(for: entry))
                    .font(.title3)
                    .foregroundStyle(inspectorIconColor(for: entry))

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if let desc = FilePreviewHelper.fileTypeDescription(entry: entry) {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    state.previewingEntry = nil
                    state.previewText = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Metadata grid
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                GridRow {
                    Text("Size").font(.caption).foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: entry.dataForkSize, countStyle: .file))
                        .font(.caption)
                }
                if entry.hasResourceFork {
                    GridRow {
                        Text("Resource").font(.caption).foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: entry.rsrcForkSize, countStyle: .file))
                            .font(.caption)
                    }
                }
                if let tc = entry.typeCreatorDisplay {
                    GridRow {
                        Text("Type/Creator").font(.caption).foregroundStyle(.secondary)
                        Text(tc).font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            // Historical context
            if let info = FilePreviewHelper.fileTypeInfoDetailed(entry: entry) {
                if let history = info.history {
                    Text(history)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Text preview (only for text files)
            if let text = state.previewText {
                Divider()
                ScrollView {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }

            // Image preview (PICT → PNG)
            if let image = state.previewImage {
                Divider()
                ScrollView {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.bar)
    }

    private func inspectorIcon(for entry: VaultEntry) -> String {
        if UnarExtractor.canHandle(filename: entry.name) || HFSExtractor.canHandle(filename: entry.name) {
            return "archivebox.fill"
        }
        switch entry.typeCode {
        case "APPL": return "app.fill"
        case "TEXT", "ttro": return "doc.text.fill"
        case "PICT": return "photo.fill"
        case "snd ": return "speaker.wave.2.fill"
        default: break
        }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "jpg", "jpeg", "png", "gif", "tiff", "bmp", "pict": return "photo.fill"
        case "mov", "mp4", "avi": return "film.fill"
        case "mp3", "aiff", "aif", "wav": return "music.note"
        case "c", "h", "p", "pas", "swift", "py", "r", "rez": return "chevron.left.forwardslash.chevron.right"
        case "rsrc": return "puzzlepiece.extension.fill"
        case "ttf", "otf": return "textformat"
        default: return "doc.fill"
        }
    }

    private func inspectorIconColor(for entry: VaultEntry) -> Color {
        if UnarExtractor.canHandle(filename: entry.name) || HFSExtractor.canHandle(filename: entry.name) {
            return .orange
        }
        switch entry.typeCode {
        case "APPL": return .purple
        case "PICT": return .green
        case "snd ": return .pink
        default: return .secondary
        }
    }

    // MARK: - Actions

    private func addFilesPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            state.addFiles(urls: panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    state.addFiles(urls: [url])
                }
            }
        }
    }
}
