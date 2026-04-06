import SwiftUI
import VaultEngine

struct FileRowView: View {
    let entry: VaultEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let tc = entry.typeCreatorDisplay {
                        Text(tc)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if !entry.isDirectory {
                        Text(ByteCountFormatter.string(
                            fromByteCount: entry.dataForkSize,
                            countStyle: .file
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if entry.hasResourceFork {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .help("Has resource fork")
                    }
                }
            }
        }
        .padding(.vertical, 2)
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
        case "TEXT", "ttro": return .secondary
        case "PICT": return .green
        case "APPL": return .purple
        case "snd ": return .orange
        default: return .secondary
        }
    }
}
