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
                VStack(alignment: .leading, spacing: 0) {
                    // Archive info (fixed at top)
                    archiveInfoSection(entry)
                        .padding()

                    if state.selectedHasExtracted {
                        Divider()
                        // Extracted file browser (takes remaining space)
                        extractedFilesSection
                    }

                    Spacer(minLength: 0)
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
            } else if state.selectedIsArchive {
                Text("Right-click to extract contents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var extractedFilesSection: some View {
        List(state.extractedTree, children: \.children) { node in
            ExtractedFileRow(node: node) { entryID in
                state.extractEntry(id: entryID)
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

        Button { showNotImplemented("Quick Look") } label: {
            Label("Quick Look", systemImage: "eye")
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
