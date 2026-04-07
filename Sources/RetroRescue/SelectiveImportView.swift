import SwiftUI
import ContainerCracker

struct SelectiveImportView: View {
    @EnvironmentObject var state: VaultState
    @State private var selectedPaths: Set<String> = []

    private var fileItems: [VaultState.SelectiveImportItem] {
        state.selectiveImportItems.filter { !$0.isDirectory }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            fileList
            Divider()
            footer
        }
        .frame(width: 480, height: 500)
        .onAppear { selectedPaths = Set(fileItems.map(\.path)) }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "archivebox").font(.title).foregroundStyle(.orange)
            if let t = state.selectiveImportTitle { Text(t).font(.headline) }
            Text("\(fileItems.count) files").font(.subheadline).foregroundStyle(.secondary)
        }.padding()
    }

    private var fileList: some View {
        List {
            Toggle(isOn: Binding(
                get: { selectedPaths.count == fileItems.count },
                set: { a in selectedPaths = a ? Set(fileItems.map(\.path)) : [] }
            )) { Text("Select All").fontWeight(.medium) }
            ForEach(groupedByDirectory(), id: \.dir) { group in
                Section(group.dir.isEmpty ? "Root" : group.dir) {
                    ForEach(group.files) { item in
                        Toggle(isOn: Binding(
                            get: { selectedPaths.contains(item.path) },
                            set: { s in if s { selectedPaths.insert(item.path) } else { selectedPaths.remove(item.path) } }
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc").foregroundStyle(.secondary).frame(width: 14)
                                Text(item.name).lineLimit(1)
                                Spacer()
                                if item.size > 0 {
                                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }.toggleStyle(.checkbox)
                    }
                }
            }
        }.listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var footer: some View {
        HStack {
            Text("\(selectedPaths.count) of \(fileItems.count) selected").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { state.showSelectiveImport = false }.keyboardShortcut(.escape)
            Button("Import Selected") { state.performSelectiveImport(selectedPaths: Array(selectedPaths)) }
                .keyboardShortcut(.return).disabled(selectedPaths.isEmpty).buttonStyle(.borderedProminent)
        }.padding()
    }

    private struct FileGroup { let dir: String; let files: [VaultState.SelectiveImportItem] }

    private func groupedByDirectory() -> [FileGroup] {
        var groups: [String: [VaultState.SelectiveImportItem]] = [:]
        for item in fileItems {
            let dir = (item.name as NSString).deletingLastPathComponent
            groups[dir, default: []].append(item)
        }
        return groups.sorted { $0.key < $1.key }.map { FileGroup(dir: $0.key, files: $0.value) }
    }
}
