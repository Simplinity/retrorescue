import SwiftUI
import VaultEngine
import ContainerCracker

struct FileRowView: View {
    let entry: VaultEntry
    var isExtracted: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let tc = entry.typeCreatorDisplay {
                        Text(tc)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(ByteCountFormatter.string(
                        fromByteCount: entry.dataForkSize, countStyle: .file
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if entry.hasResourceFork {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    if isExtracted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var isArchive: Bool {
        UnarExtractor.canHandle(filename: entry.name)
            || HFSExtractor.canHandle(filename: entry.name)
    }

    private var iconName: String {
        if isArchive { return "archivebox" }
        switch entry.typeCode {
        case "TEXT", "ttro": return "doc.text"
        case "PICT": return "photo"
        case "APPL": return "app"
        case "snd ": return "speaker.wave.2"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if isArchive { return .orange }  // Always orange — it's still an archive
        switch entry.typeCode {
        case "PICT": return .green
        case "APPL": return .purple
        case "snd ": return .orange
        default: return .secondary
        }
    }
}
