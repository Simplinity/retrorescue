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
                    FileRowView(entry: entry)
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Archive info section
                        archiveInfoSection(entry)

                        // Extract button
                        if state.selectedIsArchive && !state.selectedHasExtracted {
                            Divider()
                            Button("Extract Contents") {
                                state.extractSelected()
                            }
                            .controlSize(.large)
                        }

                        // Extracted file browser
                        if state.selectedHasExtracted {
                            Divider()
                            extractedFilesSection
                        }
                    }
                    .padding()
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

    private var extractedFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extracted Contents")
                .font(.headline)

            List(state.extractedTree, children: \.children) { node in
                ExtractedFileRow(node: node) { entryID in
                    state.extractEntry(id: entryID)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 200)
        }
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
            if let vault = state.vault {
                Text("\(vault.entryCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
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
