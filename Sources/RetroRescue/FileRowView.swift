import SwiftUI
import VaultEngine

/// A row in the left sidebar archive list.
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
                    Text(ByteCountFormatter.string(
                        fromByteCount: entry.dataForkSize,
                        countStyle: .file
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if entry.hasResourceFork {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch entry.typeCode {
        case "TEXT", "ttro": return "doc.text"
        case "PICT": return "photo"
        case "APPL": return "app"
        case "snd ": return "speaker.wave.2"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        switch entry.typeCode {
        case "PICT": return .green
        case "APPL": return .purple
        case "snd ": return .orange
        default: return .secondary
        }
    }
}
