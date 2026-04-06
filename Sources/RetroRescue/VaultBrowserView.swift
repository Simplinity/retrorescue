import SwiftUI
import VaultEngine

struct VaultBrowserView: View {
    @EnvironmentObject var state: VaultState

    var body: some View {
        NavigationSplitView {
            sidebar
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

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            fileList
            statusBar
        }
    }

    private var breadcrumbBar: some View {
        HStack {
            ForEach(Array(state.breadcrumb.enumerated()), id: \.offset) { i, crumb in
                if i > 0 { Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.caption) }
                Button(crumb.name) {
                    // Navigate back to this level
                    while state.breadcrumb.count > i + 1 {
                        state.navigateUp()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(i == state.breadcrumb.count - 1 ? .primary : .secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var fileList: some View {
        Group {
            if state.entries.isEmpty {
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
            } else {
                List(state.entries, selection: Binding(
                    get: { state.selectedEntry?.id },
                    set: { id in state.selectedEntry = state.entries.first { $0.id == id } }
                )) { entry in
                    FileRowView(entry: entry)
                        .onTapGesture(count: 2) {
                            if entry.isDirectory { state.navigateInto(entry) }
                        }
                }
            }
        }
    }

    // MARK: - Detail panel

    private var detailPanel: some View {
        Group {
            if let entry = state.selectedEntry {
                VStack(alignment: .leading, spacing: 12) {
                    Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
                        .font(.title2)

                    Divider()

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
                        GridRow {
                            Text("Encoding").foregroundStyle(.secondary)
                            Text(entry.encoding)
                        }
                        if let source = entry.sourceArchive {
                            GridRow {
                                Text("Source").foregroundStyle(.secondary)
                                Text(source)
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
            } else if state.entries.isEmpty {
                ContentUnavailableView {
                    Label("Empty vault", systemImage: "archivebox")
                } description: {
                    Text("Drop classic Mac files, disk images, or StuffIt archives onto this window to preserve them.")
                } actions: {
                    Button("Add Files...") { addFilesPanel() }
                }
            } else {
                ContentUnavailableView {
                    Label("No selection", systemImage: "cursorarrow.click.2")
                } description: {
                    Text("Select a file from the sidebar to inspect it.")
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                addFilesPanel()
            } label: {
                Label("Add Files", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .destructiveAction) {
            Button {
                state.deleteSelected()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(state.selectedEntry == nil)
        }
        ToolbarItem(placement: .navigation) {
            Button {
                state.navigateUp()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(state.breadcrumb.count <= 1)
        }
    }

    // MARK: - Status bar

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
        panel.message = "Choose files to add to the vault"
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
