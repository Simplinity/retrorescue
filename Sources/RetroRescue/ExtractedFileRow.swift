import SwiftUI
import VaultEngine
import ContainerCracker

/// A single row in the Finder-style extracted file browser.
/// Used inside a List with children: parameter for native outline behavior.
struct ExtractedFileRow: View {
    @ObservedObject var node: FileTreeNode
    var onExtract: ((String) -> Void)?
    var onExtractSelected: ((String) -> Void)?
    var onQuickLook: ((VaultEntry) -> Void)?
    var onOpen: ((VaultEntry) -> Void)?
    var onPreview: ((VaultEntry) -> Void)?
    var onConvert: ((VaultEntry) -> Void)?
    var onExport: ((VaultEntry) -> Void)?
    var onDragFile: ((VaultEntry) -> URL?)?
    var onGetInfo: ((VaultEntry) -> Void)?
    var onMessage: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            // Column 1: Icon + Name (flexible)
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 16)

            Text(node.entry.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            // Column 2: Type/Creator (fixed width)
            if let tc = node.entry.typeCreatorDisplay {
                Text(tc)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
            } else {
                Spacer().frame(width: 80)
            }

            // Column 3: Size (fixed width, right-aligned)
            if !node.entry.isDirectory {
                Text(ByteCountFormatter.string(
                    fromByteCount: node.entry.dataForkSize, countStyle: .file
                ))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .trailing)
            } else {
                Spacer().frame(width: 60)
            }

            // Column 4: Indicators (fixed width)
            HStack(spacing: 4) {
                if node.entry.hasResourceFork {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if node.isExtractable {
                    Image(systemName: "archivebox")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 30, alignment: .trailing)
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
                    Label("Extract", systemImage: "archivebox")
                }
                Button {
                    onExtractSelected?(node.entry.id)
                } label: {
                    Label("Extract Selected…", systemImage: "checklist")
                }
            }

            if !node.entry.isDirectory {
                Button { onExport?(node.entry) } label: {
                    Label("Export to Finder…", systemImage: "square.and.arrow.up")
                }
                Button { onGetInfo?(node.entry) } label: {
                    Label("Get Info", systemImage: "info.circle")
                }
                Button { onConvert?(node.entry) } label: {
                    Label("Convert to Modern Format…", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!FilePreviewHelper.canConvert(entry: node.entry))
            }

            Divider()

            Button(role: .destructive) { showNotImplemented("Delete") } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onDrag {
            if !node.entry.isDirectory,
               let url = onDragFile?(node.entry) {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider()
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
