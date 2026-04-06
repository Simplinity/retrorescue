import SwiftUI
import VaultEngine

/// A row in the extracted file browser (right panel).
/// Supports recursive folder expansion and nested archive extraction.
struct ExtractedFileRow: View {
    let entry: VaultEntry
    let state: VaultState
    let depth: Int

    @State private var isExpanded = false
    @State private var children: [VaultEntry] = []
    @State private var isExtracting = false

    private var isExtractable: Bool {
        !entry.isDirectory && VaultState.isExtractable(entry.name) && children.isEmpty
    }

    private var hasChildren: Bool {
        !children.isEmpty || entry.isDirectory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
            if isExpanded {
                expandedChildren
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 6) {
            if depth > 0 {
                Spacer().frame(width: CGFloat(depth) * 16)
            }

            // Expand/collapse toggle
            if hasChildren {
                Button { toggleExpand() } label: {
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
                    fromByteCount: entry.dataForkSize, countStyle: .file
                ))
                .font(.caption2)
                .foregroundStyle(.tertiary)

                if entry.hasResourceFork {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            // Extract button for nested archives
            if isExtractable {
                Button {
                    extract()
                } label: {
                    Text("Extract")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(isExtracting)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
    }

    private var expandedChildren: some View {
        ForEach(children) { child in
            ExtractedFileRow(entry: child, state: state, depth: depth + 1)
        }
    }

    // MARK: - Actions

    private func toggleExpand() {
        isExpanded.toggle()
        if isExpanded && children.isEmpty {
            children = state.children(of: entry.id)
        }
    }

    private func extract() {
        isExtracting = true
        state.extractEntry(id: entry.id)
        children = state.children(of: entry.id)
        isExpanded = true
        isExtracting = false
    }

    // MARK: - Icons

    private var iconName: String {
        if entry.isDirectory { return "folder.fill" }
        if VaultState.isExtractable(entry.name) { return "archivebox" }
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
        if VaultState.isExtractable(entry.name) { return .orange }
        switch entry.typeCode {
        case "PICT": return .green
        case "APPL": return .purple
        case "snd ": return .orange
        default: return .secondary
        }
    }
}
