import SwiftUI
import VaultEngine

/// Finder-style "Get Info" sheet showing all metadata for a vault entry.
struct GetInfoView: View {
    let entry: VaultEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.headline)
                        .lineLimit(2)
                    if let desc = FilePreviewHelper.fileTypeDescription(entry: entry) {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()

            Divider()

            // Metadata grid
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    infoRow("Kind", FilePreviewHelper.fileTypeDescription(entry: entry) ?? "Unknown")
                    if let tc = entry.typeCreatorDisplay {
                        infoRow("Type / Creator", tc)
                    }
                    if let type = entry.typeCode {
                        infoRow("Type code", type)
                    }
                    if let creator = entry.creatorCode {
                        infoRow("Creator code", creator)
                    }

                    Divider().gridCellColumns(2)

                    infoRow("Data fork", ByteCountFormatter.string(fromByteCount: entry.dataForkSize, countStyle: .file))
                    if entry.hasResourceFork {
                        infoRow("Resource fork", ByteCountFormatter.string(fromByteCount: entry.rsrcForkSize, countStyle: .file))
                    }
                    infoRow("Total size", ByteCountFormatter.string(fromByteCount: entry.dataForkSize + entry.rsrcForkSize, countStyle: .file))

                    Divider().gridCellColumns(2)

                    if let created = entry.created {
                        infoRow("Created", created.formatted(date: .long, time: .shortened))
                    }
                    if let modified = entry.modified {
                        infoRow("Modified", modified.formatted(date: .long, time: .shortened))
                    }
                    infoRow("Added to vault", entry.addedAt.formatted(date: .long, time: .shortened))

                    Divider().gridCellColumns(2)

                    infoRow("Encoding", entry.encoding)
                    if entry.finderFlags != 0 {
                        infoRow("Finder flags", String(format: "0x%04X", entry.finderFlags))
                    }
                    if let source = entry.sourceArchive {
                        infoRow("Source archive", source)
                    }
                    infoRow("Vault ID", entry.id)
                    if let parentID = entry.parentID {
                        infoRow("Parent ID", parentID)
                    }

                    if let sha = entry.dataChecksum {
                        infoRow("Data SHA-256", sha)
                    }
                    if let sha = entry.rsrcChecksum {
                        infoRow("Rsrc SHA-256", sha)
                    }
                }
                .padding()

                // Historical context
                if let info = FilePreviewHelper.fileTypeInfoDetailed(entry: entry),
                   let history = info.history {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About this file type")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(history)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 380, height: 450)
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .gridColumnAlignment(.leading)
        }
    }

    private var iconName: String {
        if entry.isDirectory { return "folder.fill" }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        switch entry.typeCode {
        case "APPL": return "app.fill"
        case "TEXT", "ttro": return "doc.text.fill"
        case "PICT": return "photo.fill"
        case "snd ": return "speaker.wave.2.fill"
        default: break
        }
        switch ext {
        case "sit", "sitx", "cpt", "zip", "7z", "rar": return "archivebox.fill"
        case "img", "image", "dsk", "dmg": return "internaldrive.fill"
        case "pdf": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch entry.typeCode {
        case "APPL": return .purple
        case "PICT": return .green
        case "snd ": return .pink
        default: return .blue
        }
    }
}
