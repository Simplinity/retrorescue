import SwiftUI
import VaultEngine

/// A row in the extracted file browser (right panel).
/// Supports recursive folder expansion.
struct ExtractedFileRow: View {
    let entry: VaultEntry
    let state: VaultState
    let depth: Int

    @State private var isExpanded = false
    @State private var children: [VaultEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Indentation
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth) * 16)
                }

                // Expand/collapse for folders
                if entry.isDirectory {
                    Button {
                        toggleExpand()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 12)
                }

                // Icon
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 16)

                // Name
                Text(entry.name)
                    .lineLimit(1)
                    .font(.callout)

                Spacer()

                // Metadata
                if !entry.isDirectory {
                    if let tc = entry.typeCreatorDisplay {
                        Text(tc)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(ByteCountFormatter.string(
                        fromByteCount: entry.dataForkSize,
                        countStyle: .file
                    ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    if entry.hasResourceFork {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)

            // Expanded children
            if isExpanded {
                ForEach(children) { child in
                    ExtractedFileRow(entry: child, state: state, depth: depth + 1)
                }
            }
        }
    }

    private func toggleExpand() {
        isExpanded.toggle()
        if isExpanded && children.isEmpty {
            children = state.children(of: entry.id)
        }
    }

    private var iconName: String {
        if entry.isDirectory { return "folder.fill" }
        switch entry.typeCode {
        case "TEXT", "ttro": return "doc.text"
        case "PICT": return "photo"
        case "APPL": return "app"
        case "snd ": return "speaker.wave.2"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if entry.isDirectory { return .blue }
        switch entry.typeCode {
        case "PICT": return .green
        case "APPL": return .purple
        case "snd ": return .orange
        default: return .secondary
        }
    }
}
