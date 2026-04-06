import SwiftUI
import VaultEngine

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
        .toolbar { toolbarContent }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
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
            if let entry = state.selectedEntry {
                if state.selectedHasExtracted {
                    VSplitView {
                        ScrollView {
                            archiveInfoSection(entry)
                                .padding()
                        }
                        .frame(minHeight: 80, idealHeight: 120, maxHeight: .infinity)

                        VStack(spacing: 0) {
                            extractedFilesSection

                            if let previewing = state.previewingEntry {
                                Divider()
                                filePreviewSection(previewing)
                            }
                        }
                        .frame(minHeight: 150, idealHeight: 400, maxHeight: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        archiveInfoSection(entry)
                            .padding()

                        if state.selectedIsArchive {
                            extractPromptCard(entry)
                                .padding(.horizontal)
                        }

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
        case "dmg": return "disk image"
        case "iso": return "ISO disc image"
        case "img", "image": return "HFS disk image"
        case "dsk", "disk": return "HFS disk image"
        case "hfs", "hfv": return "HFS volume"
        case "toast": return "Toast disc image"
        default: return "compressed archive"
        }
    }

    private var extractedFilesSection: some View {
        List(state.extractedTree, children: \.children) { node in
            ExtractedFileRow(node: node) { entryID in
                state.extractEntry(id: entryID)
            } onQuickLook: { entry in
                state.quickLook(entry)
            } onOpen: { entry in
                state.openInDefaultApp(entry)
            } onPreview: { entry in
                state.previewFile(entry)
            } onMessage: { msg in
                state.error = msg
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            Label("Extract Contents", systemImage: "archivebox")
        }
        .disabled(!isArchive || isExtracted)

        Divider()

        Button { showNotImplemented("Export") } label: {
            Label("Export to Finder…", systemImage: "square.and.arrow.up")
        }
        Button { showNotImplemented("Reveal in Finder") } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }
        Button { showNotImplemented("Convert to Modern Format") } label: {
            Label("Convert to Modern Format…", systemImage: "arrow.triangle.2.circlepath")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(entry.name, systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                Spacer()
                Button {
                    state.previewingEntry = nil
                    state.previewText = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let text = state.previewText {
                ScrollView {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                .frame(minHeight: 150, maxHeight: 300)
            } else {
                Text("No text preview available. Use Quick Look or Open for this file type.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .background(.quaternary.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal)
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
