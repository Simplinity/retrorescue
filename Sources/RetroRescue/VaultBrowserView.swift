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
        .navigationTitle(state.windowTitle)
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
        .onDrop(of: [.fileURL, .url, .text], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .sheet(isPresented: $state.showSelectiveImport) {
            SelectiveImportView()
                .environmentObject(state)
        }
        .sheet(item: $state.getInfoEntry) { entry in
            GetInfoView(entry: entry)
        }
        // K18: Preferences sheet
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        // K19: Progress overlay
        // Progress is now shown inline under extracting entries
        // K15: Keyboard shortcuts
        .onKeyPress(.space) {
            if let entry = state.previewingEntry { state.quickLook(entry); return .handled }
            return .ignored
        }
        .onKeyPress(.return) {
            if let entry = state.selectedEntry { state.select(entry); return .handled }
            return .ignored
        }
        .onKeyPress(.deleteForward) {
            state.deleteSelected(); return .handled
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
                    VStack(spacing: 0) {
                        FileRowView(entry: entry, isExtracted: state.isAlreadyExtracted(id: entry.id))
                            .contextMenu { sidebarContextMenu(for: entry) }
                        if state.extractingEntryID == entry.id {
                            inlineProgressBar
                        }
                    }
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
                            VSplitView {
                                extractedFilesForViewMode
                                    .frame(maxWidth: .infinity, minHeight: 100, idealHeight: 300, maxHeight: .infinity)

                                filePreviewSection(state.previewingEntry!)
                                    .frame(maxWidth: .infinity, minHeight: 80, idealHeight: 200, maxHeight: .infinity)
                            }
                        } else {
                            extractedFilesForViewMode
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

            // DiskCopy 4.2 disk description + checksum status
            if let diskInfo = state.cachedDiskImageInfo {
                Divider()
                if let name = diskInfo.diskName, !name.isEmpty {
                    Text("Disk: \"\(name)\" — \(diskInfo.diskType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: diskInfo.checksumValid ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundStyle(diskInfo.checksumValid ? .green : .red)
                    Text(diskInfo.checksumValid ? "Checksum verified" : "Checksum mismatch!")
                        .font(.caption)
                        .foregroundStyle(diskInfo.checksumValid ? .green : .red)
                    if let tag = diskInfo.tagData, !tag.isEmpty {
                        Text("· \(tag.count) bytes tag data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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

    // K13/K14: Switch view based on viewMode
    @ViewBuilder
    private var extractedFilesForViewMode: some View {
        switch state.viewMode {
        case .list: extractedFilesSection
        case .grid: extractedFilesGrid
        case .columns: extractedFilesColumns
        }
    }

    private var extractedFilesSection: some View {
        VStack(spacing: 0) {
            // Breadcrumb bar when drilled down
            if !state.browsePath.isEmpty {
                HStack(spacing: 4) {
                    Button { state.drillUp() } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    Text(state.browsePathNames.last ?? "")
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(state.extractedEntries.count) items")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.bar)
                Divider()
            }
            // Flat file list
            List(state.filteredExtractedEntries, selection: Binding(
                get: { state.selectedExtractedID },
                set: { state.selectExtractedFile(id: $0) }
            )) { entry in
                extractedFileRow(entry)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private func extractedFileRow(_ entry: VaultEntry) -> some View {
        HStack(spacing: 6) {
            Image(systemName: entry.isDirectory ? "folder.fill" :
                    VaultState.isExtractable(entry.name) ? "archivebox" : "doc")
                .foregroundStyle(entry.isDirectory ? .blue :
                    VaultState.isExtractable(entry.name) ? .orange : .secondary)
                .frame(width: 16)
            Text(entry.name).lineLimit(1)
            Spacer()
            if entry.rsrcForkSize > 0 {
                Image(systemName: "fork.knife").font(.caption2).foregroundStyle(.purple)
            }
            if let tc = entry.typeCode, !tc.isEmpty {
                Text(tc).font(.caption).foregroundStyle(.tertiary).frame(width: 40)
            }
            Text(ByteCountFormatter.string(fromByteCount: entry.dataForkSize, countStyle: .file))
                .font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
            // Drill-down chevron for items with children
            if state.hasChildren(entry.id) {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if state.hasChildren(entry.id) {
                state.drillDown(into: entry)
            } else {
                state.quickLook(entry)
            }
        }
        .onTapGesture(count: 1) {
            state.selectExtractedFile(id: entry.id)
        }
        .contextMenu {
            if state.hasChildren(entry.id) {
                Button { state.drillDown(into: entry) } label: { Label("Open", systemImage: "arrow.right") }
                Divider()
            }
            Button { state.previewFile(entry) } label: { Label("Preview", systemImage: "eye") }
            Button { state.quickLook(entry) } label: { Label("Quick Look", systemImage: "eye.fill") }
            if VaultState.isExtractable(entry.name) {
                Button { state.extractEntry(id: entry.id) } label: { Label("Extract", systemImage: "archivebox.fill") }
            }
            Divider()
            Button { state.exportToFinder(entry) } label: { Label("Export", systemImage: "square.and.arrow.up") }
            Button { state.getInfoEntry = entry } label: { Label("Get Info", systemImage: "info.circle") }
            Divider()
            Button(role: .destructive) {
                state.selectedExtractedID = entry.id
                state.deleteSelectedExtractedFile()
            } label: { Label("Delete", systemImage: "trash") }
        }
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
        // K13/K14: View mode picker
        ToolbarItem(placement: .automatic) {
            Picker("View", selection: $state.viewMode) {
                Label("List", systemImage: "list.bullet").tag(VaultState.ViewMode.list)
                Label("Grid", systemImage: "square.grid.2x2").tag(VaultState.ViewMode.grid)
                Label("Columns", systemImage: "rectangle.split.3x1").tag(VaultState.ViewMode.columns)
            }
            .pickerStyle(.segmented)
            .help("Switch view mode")
        }
        // K12: Filter popover
        ToolbarItem(placement: .automatic) {
            filterButton
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

    // MARK: - K12: Filter Popover

    @State private var showFilterPopover = false
    @State private var imageZoom: Double = 1.0

    private var filterButton: some View {
        Button {
            showFilterPopover.toggle()
        } label: {
            Label("Filter", systemImage: state.isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .help("Filter extracted files")
        .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
            filterPopoverContent
        }
    }

    private var filterPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filter Files").font(.headline)
            HStack {
                Text("Type:").frame(width: 60, alignment: .trailing)
                TextField("e.g. TEXT", text: $state.filterTypeCode).textFieldStyle(.roundedBorder).frame(width: 120)
            }
            HStack {
                Text("Creator:").frame(width: 60, alignment: .trailing)
                TextField("e.g. MSWD", text: $state.filterCreatorCode).textFieldStyle(.roundedBorder).frame(width: 120)
            }
            HStack {
                Text("Rsrc fork:").frame(width: 60, alignment: .trailing)
                Picker("", selection: Binding(
                    get: { state.filterHasRsrc.map { $0 ? 1 : 0 } ?? -1 },
                    set: { state.filterHasRsrc = $0 == -1 ? nil : $0 == 1 }
                )) {
                    Text("Any").tag(-1)
                    Text("Has rsrc").tag(1)
                    Text("No rsrc").tag(0)
                }
                .pickerStyle(.segmented).frame(width: 180)
            }
            if state.isFiltering {
                Button("Clear Filters") { state.clearFilters() }
                    .buttonStyle(.borderless).foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - K13: Grid View

    private var extractedFilesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100))], spacing: 12) {
                ForEach(state.filteredExtractedEntries) { entry in
                    VStack(spacing: 4) {
                        // Show thumbnail if available, else SF Symbol
                        if let vault = state.vault, let thumb = ThumbnailGenerator.loadThumbnail(vault: vault, id: entry.id) {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                        } else {
                            Image(systemName: entry.isDirectory ? "folder.fill" : fileIcon(for: entry))
                                .font(.system(size: 32))
                                .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                                .frame(height: 40)
                        }
                        Text(entry.name)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 80, height: 80)
                    .padding(4)
                    .background(state.selectedExtractedID == entry.id ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    .onTapGesture { state.selectExtractedFile(id: entry.id) }
                    .onTapGesture(count: 2) { state.quickLook(entry) }
                }
            }
            .padding()
        }
    }

    private func fileIcon(for entry: VaultEntry) -> String {
        let ext = (entry.name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "text", "md": return "doc.text"
        case "png", "jpg", "gif", "tiff", "pict": return "photo"
        case "mp3", "aiff", "wav": return "music.note"
        case "mov", "mp4": return "film"
        case "sit", "zip", "cpt": return "archivebox"
        case "img", "dsk", "dmg": return "opticaldiscsymbol"
        default: return entry.rsrcForkSize > 0 ? "doc.richtext" : "doc"
        }
    }

    // MARK: - K14: Column View (breadcrumb-style)

    private var extractedFilesColumns: some View {
        VStack(spacing: 0) {
            // Breadcrumb path bar
            HStack(spacing: 4) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(state.selectedEntry?.name ?? "").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(state.filteredExtractedEntries.count) items").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.bar)

            Divider()

            // Two-column: folders left, files right
            HStack(spacing: 0) {
                let dirs = state.filteredExtractedEntries.filter { $0.isDirectory }
                let files = state.filteredExtractedEntries.filter { !$0.isDirectory }
                if !dirs.isEmpty {
                    List(dirs, selection: Binding(
                        get: { state.selectedExtractedID },
                        set: { state.selectExtractedFile(id: $0) }
                    )) { entry in
                        Label(entry.name, systemImage: "folder")
                    }
                    .frame(minWidth: 150, maxWidth: 200)
                    Divider()
                }
                List(files, selection: Binding(
                    get: { state.selectedExtractedID },
                    set: { state.selectExtractedFile(id: $0) }
                )) { entry in
                    Label(entry.name, systemImage: fileIcon(for: entry))
                }
            }
        }
    }

    // MARK: - K18: Preferences

    @State private var showPreferences = false

    // MARK: - Inline Progress Bar

    /// Subtle inline progress bar: grey background, orange fill.
    private var inlineProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.orange)
                    .frame(width: max(4, geo.size.width * state.progressFraction), height: 4)
                    .animation(.easeInOut(duration: 0.3), value: state.progressFraction)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 4)
        .padding(.top, 2)
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
        Button { state.getInfoEntry = entry } label: {
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

        Button { state.exportToFinder(entry) } label: {
            Label("Export to Finder…", systemImage: "square.and.arrow.up")
        }
        Button { state.revealInFinder(entry) } label: {
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

        Menu {
            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.name, forType: .string) } label: {
                Label("Copy Name", systemImage: "doc.on.doc")
            }
            if let tc = entry.typeCreatorDisplay {
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(tc, forType: .string) } label: {
                    Label("Copy Type/Creator", systemImage: "doc.on.doc")
                }
            }
            if let sha = entry.dataChecksum {
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(sha, forType: .string) } label: {
                    Label("Copy SHA-256", systemImage: "number")
                }
            }
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

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

            // Nested archive extract button
            if state.selectedExtractedIsArchive {
                Button {
                    if let id = state.selectedExtractedID {
                        state.extractEntry(id: id)
                    }
                } label: {
                    Label("Extract Disk Image", systemImage: "archivebox.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            // Inline progress bar for nested extraction
            if let extractID = state.extractingEntryID,
               extractID == state.selectedExtractedID {
                VStack(spacing: 2) {
                    inlineProgressBar
                    Text(state.progressMessage ?? "Extracting…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
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

            // Image preview (PICT, MacPaint, icons)
            if let image = state.previewImage {
                Divider()
                imagePreview(image)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.bar)
    }

    /// Image preview with zoom control
    private func imagePreview(_ image: NSImage) -> some View {
        VStack(spacing: 0) {
            // Zoom toolbar
            HStack(spacing: 8) {
                Button { imageZoom = max(0.25, imageZoom - 0.25) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Text("\(Int(imageZoom * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                Button { imageZoom = min(4.0, imageZoom + 0.25) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Button { imageZoom = 1.0 } label: {
                    Text("Fit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(image.size.width))×\(Int(image.size.height))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            // Scrollable image with zoom
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: min(image.size.width, 280) * imageZoom,
                        height: min(image.size.height, 200) * imageZoom
                    )
                    .padding(4)
            }
            .frame(maxHeight: 220)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onChange(of: state.previewingEntry?.id) { _, _ in imageZoom = 1.0 }
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
            // File URLs (local files)
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        if url.isFileURL {
                            state.addFiles(urls: [url])
                        } else {
                            // M1: Web URL dropped — download and import
                            state.downloadFromURL(url)
                        }
                    }
                }
            }
            // Plain text (might be a URL string from browser address bar)
            if provider.hasItemConformingToTypeIdentifier("public.text") {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                          url.scheme == "http" || url.scheme == "https" else { return }
                    DispatchQueue.main.async {
                        state.downloadFromURL(url)
                    }
                }
            }
        }
    }
}
