import SwiftUI
import VaultEngine
import ContainerCracker

/// A single row in the Finder-style extracted file browser.
/// Used inside a List with children: parameter for native outline behavior.
struct ExtractedFileRow: View {
    @ObservedObject var node: FileTreeNode
    var onExtract: ((String) -> Void)?
    var onQuickLook: ((VaultEntry) -> Void)?
    var onOpen: ((VaultEntry) -> Void)?
    var onPreview: ((VaultEntry) -> Void)?
    var onMessage: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 16)

            Text(node.entry.name)
                .lineLimit(1)

            Spacer()

            if !node.entry.isDirectory {
                if let tc = node.entry.typeCreatorDisplay {
                    Text(tc)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(ByteCountFormatter.string(
                    fromByteCount: node.entry.dataForkSize, countStyle: .file
                ))
                .font(.caption)
                .foregroundStyle(.tertiary)

                if node.entry.hasResourceFork {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            if node.isExtractable {
                Image(systemName: "archivebox")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .contextMenu {
            if !node.entry.isDirectory {
                Button { onQuickLook?(node.entry) } label: {
                    Label("Quick Look", systemImage: "eye")
                }
                Button { onOpen?(node.entry) } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
                Button { onPreview?(node.entry) } label: {
                    Label("Preview", systemImage: "doc.text.magnifyingglass")
                }
            }

            Divider()

            if node.isExtractable {
                Button {
                    onExtract?(node.entry.id)
                    node.reloadChildren()
                } label: {
                    Label("Extract Contents", systemImage: "archivebox")
                }
            }

            if !node.entry.isDirectory {
                Button { showNotImplemented("Export") } label: {
                    Label("Export to Finder…", systemImage: "square.and.arrow.up")
                }
                Button { showNotImplemented("Convert") } label: {
                    Label("Convert to Modern Format…", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Divider()

            Button(role: .destructive) { showNotImplemented("Delete") } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func showNotImplemented(_ feature: String) {
        onMessage?("\(feature) is coming in a future version.")
    }

    private var iconName: String {
        if node.entry.isDirectory { return "folder.fill" }
        if node.isExtractable { return "archivebox" }
        switch node.entry.typeCode {
        case "TEXT", "ttro": return "doc.text"
        case "PICT": return "photo"
        case "APPL": return "app"
        case "snd ": return "speaker.wave.2"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if node.entry.isDirectory { return .blue }
        if node.isExtractable { return .orange }
        switch node.entry.typeCode {
        case "PICT": return .green
        case "APPL": return .purple
        case "snd ": return .orange
        default: return .secondary
        }
    }
}
