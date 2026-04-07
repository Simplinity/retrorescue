import SwiftUI
import ContainerCracker

/// Sheet that shows the contents of an HFS disk image
/// and lets the user select which files to import.
struct SelectiveImportView: View {
    @EnvironmentObject var state: VaultState
    @State private var selectedPaths: Set<String> = []
    @State private var selectAll = true

    private var fileItems: [HFSExtractor.HFSItem] {
        state.selectiveImportItems.filter { !$0.isDirectory }
    }

    private var dirItems: [HFSExtractor.HFSItem] {
        state.selectiveImportItems.filter { $0.isDirectory }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            Divider()
            // File list with checkboxes
            fileList
            Divider()
            // Footer with buttons
            footer
        }
        .frame(width: 480, height: 500)
        .onAppear {
            // Select all file paths by default
            selectedPaths = Set(fileItems.map(\.path))
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "internaldrive")
                .font(.title)
                .foregroundStyle(.blue)
            if let name = state.selectiveImportVolumeName {
                Text(name).font(.headline)
            }
            Text("\(fileItems.count) files in \(dirItems.count) folders")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Select the files you want to import into the vault.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var fileList: some View {
        List {
            // Select All toggle
            Toggle(isOn: Binding(
                get: { selectedPaths.count == fileItems.count },
                set: { newValue in
                    if newValue {
                        selectedPaths = Set(fileItems.map(\.path))
                    } else {
                        selectedPaths.removeAll()
                    }
                }
            )) {
                Text("Select All")
                    .fontWeight(.medium)
            }

            // Group files by directory
            ForEach(groupedByDirectory(), id: \.dir) { group in
                Section(group.dir.isEmpty ? "Root" : String(group.dir.dropFirst())) {
                    ForEach(group.files) { item in
                        Toggle(isOn: Binding(
                            get: { selectedPaths.contains(item.path) },
                            set: { selected in
                                if selected {
                                    selectedPaths.insert(item.path)
                                } else {
                                    selectedPaths.remove(item.path)
                                }
                            }
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                Text(item.name)
                                    .lineLimit(1)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var footer: some View {
        HStack {
            Text("\(selectedPaths.count) of \(fileItems.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") {
                state.showSelectiveImport = false
            }
            .keyboardShortcut(.escape)
            Button("Import Selected") {
                state.performSelectiveImport(
                    selectedPaths: Array(selectedPaths))
            }
            .keyboardShortcut(.return)
            .disabled(selectedPaths.isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Grouping

    private struct FileGroup {
        let dir: String
        let files: [HFSExtractor.HFSItem]
    }

    private func groupedByDirectory() -> [FileGroup] {
        var groups: [String: [HFSExtractor.HFSItem]] = [:]
        for item in fileItems {
            let dir = (item.path as NSString).deletingLastPathComponent
            groups[dir, default: []].append(item)
        }
        return groups
            .sorted { $0.key < $1.key }
            .map { FileGroup(dir: $0.key, files: $0.value) }
    }
}
