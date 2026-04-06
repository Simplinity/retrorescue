import SwiftUI
import VaultEngine
import ContainerCracker

/// A single row in the Finder-style extracted file browser.
/// Used inside a List with children: parameter for native outline behavior.
struct ExtractedFileRow: View {
    @ObservedObject var node: FileTreeNode
    var onExtract: ((String) -> Void)?

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
                Button {
                    onExtract?(node.entry.id)
                    node.reloadChildren()
                } label: {
                    Text("Extract")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
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
