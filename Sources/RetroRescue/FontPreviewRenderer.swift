import AppKit
import CoreText
import VaultEngine

/// Renders a Font Book–style preview image for any font format.
/// Supports: TTF, OTF, sfnt, ttro, LWFN (PostScript Type 1), FFIL (Mac suitcase),
/// AFM (Adobe Font Metrics — falls back to system font lookup).
enum FontPreviewRenderer {

    /// Check if a vault entry is a font we can preview.
    static func isFont(_ entry: VaultEntry) -> Bool {
        let ext = (entry.name as NSString).pathExtension.lowercased()
        let fontExts: Set<String> = ["ttf", "otf", "ttc", "dfont", "pfb", "pfa",
                                      "afm", "pfm", "suit", "fond"]
        if fontExts.contains(ext) { return true }
        if let tc = entry.typeCode {
            let fontTypes: Set<String> = ["sfnt", "ttro", "LWFN", "FFIL", "FONT",
                                          "NFNT", "FOND", "tfil"]
            if fontTypes.contains(tc) { return true }
        }
        return false
    }
}

extension FontPreviewRenderer {

    /// Main entry point: render a font preview image.
    /// Returns nil if the file is not a renderable font.
    static func renderPreview(vault: Vault, entry: VaultEntry) -> NSImage? {
        // Special case: AFM is text-only metadata
        if (entry.name as NSString).pathExtension.lowercased() == "afm"
            || entry.typeCode == "TEXT" && entry.name.lowercased().hasSuffix(".afm") {
            return renderAFMPreview(vault: vault, entry: entry)
        }

        // Try to get a CTFont from the vault entry
        guard let font = loadFont(vault: vault, entry: entry) else { return nil }
        return renderSampleSheet(font: font, displayName: fontDisplayName(font) ?? entry.name)
    }

    /// Get a human-readable font name from a CTFont.
    private static func fontDisplayName(_ font: CTFont) -> String? {
        let name = CTFontCopyDisplayName(font) as String
        return name.isEmpty ? nil : name
    }
}

extension FontPreviewRenderer {

    /// Try to load a CTFont from a vault entry.
    /// Strategy: write data fork (or resource fork for FFIL/LWFN) to a temp file
    /// with the right extension, then use CTFontManager to read it.
    private static func loadFont(vault: Vault, entry: VaultEntry) -> CTFont? {
        // Try data fork first (TTF/OTF/sfnt/ttro)
        let dataURL = vault.dataForkURL(for: entry.id)
        if FileManager.default.fileExists(atPath: dataURL.path),
           let size = try? FileManager.default.attributesOfItem(atPath: dataURL.path)[.size] as? Int,
           size > 0 {
            let ext = (entry.name as NSString).pathExtension.lowercased()
            let tempExt = ["otf", "ttf", "ttc"].contains(ext) ? ext : "otf"
            if let font = createFontFromURL(dataURL, ext: tempExt) {
                return font
            }
        }

        // Fall back to resource fork (FFIL, LWFN, FONT, NFNT, FOND)
        if let rsrcData = try? vault.rsrcFork(for: entry.id), !rsrcData.isEmpty {
            // dfont format = resource fork content as regular data fork
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("rrfont-\(UUID().uuidString).dfont")
            try? rsrcData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            if let font = createFontFromURL(tempURL, ext: "dfont") {
                return font
            }
        }
        return nil
    }

    /// Create a CTFont from a file URL. If the URL doesn't have the right
    /// extension, copy to a temp file first (CoreText is picky about extensions).
    private static func createFontFromURL(_ url: URL, ext: String) -> CTFont? {
        // Try direct first
        if let font = tryFontDescriptors(url: url) {
            return font
        }
        // Copy with the right extension
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rrfont-\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            return tryFontDescriptors(url: tempURL)
        } catch {
            return nil
        }
    }

    private static func tryFontDescriptors(url: URL) -> CTFont? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first else {
            return nil
        }
        return CTFontCreateWithFontDescriptor(first, 36, nil)
    }
}

extension FontPreviewRenderer {

    /// Render a Font Book–style sample sheet showing alphabets, numbers,
    /// and the pangram at multiple sizes.
    private static func renderSampleSheet(font: CTFont, displayName: String) -> NSImage {
        let width: CGFloat = 600
        let margin: CGFloat = 20
        let pangram = "The quick brown fox jumps over the lazy dog"
        let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let lower = "abcdefghijklmnopqrstuvwxyz"
        let digits = "0123456789  .,;:!?&@#$%"
        let sizes: [CGFloat] = [12, 18, 24, 36, 48, 64]

        // Build attributed strings to measure heights
        struct Block { let str: NSAttributedString; let height: CGFloat }
        var blocks: [Block] = []

        // Header (system font, font name)
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let header = NSAttributedString(string: displayName, attributes: headerAttr)
        blocks.append(Block(str: header, height: 22))

        // Helper to make a styled string in this font at a given size
        func styled(_ s: String, _ size: CGFloat) -> NSAttributedString {
            let descriptor = CTFontCopyFontDescriptor(font)
            let sized = CTFontCreateWithFontDescriptor(descriptor, size, nil)
            let nsFont = sized as NSFont
            return NSAttributedString(string: s, attributes: [
                .font: nsFont,
                .foregroundColor: NSColor.labelColor
            ])
        }

        // Alphabet rows at 24pt
        blocks.append(Block(str: styled(upper, 24), height: 32))
        blocks.append(Block(str: styled(lower, 24), height: 32))
        blocks.append(Block(str: styled(digits, 24), height: 32))

        // Pangram at increasing sizes
        for size in sizes {
            blocks.append(Block(str: styled(pangram, size), height: size * 1.4 + 4))
        }

        // Compute total height
        let totalHeight = blocks.reduce(margin * 2) { $0 + $1.height + 6 }
        let imageSize = NSSize(width: width, height: totalHeight)

        // Draw
        let image = NSImage(size: imageSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        // White background
        NSColor.textBackgroundColor.setFill()
        NSRect(origin: .zero, size: imageSize).fill()

        var y = totalHeight - margin
        for block in blocks {
            y -= block.height
            let rect = NSRect(x: margin, y: y, width: width - margin * 2, height: block.height)
            block.str.draw(in: rect)
            y -= 6
        }

        return image
    }
}

extension FontPreviewRenderer {

    /// Render a preview for an AFM (Adobe Font Metrics) text file.
    /// Parses the font name and tries to render with the actual font if available;
    /// otherwise returns an info card with the parsed metadata.
    private static func renderAFMPreview(vault: Vault, entry: VaultEntry) -> NSImage? {
        guard let data = try? vault.dataFork(for: entry.id),
              let text = String(data: data, encoding: .ascii)
                ?? String(data: data, encoding: .utf8) else { return nil }

        // Parse key AFM fields
        var fields: [String: String] = [:]
        for line in text.split(separator: "\n").prefix(40) {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                fields[String(parts[0])] = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        let fontName = fields["FontName"] ?? ""
        let fullName = fields["FullName"] ?? fontName
        let family = fields["FamilyName"] ?? ""
        let weight = fields["Weight"] ?? ""

        // Try to find the actual font on the system
        if !fontName.isEmpty, let nsFont = NSFont(name: fontName, size: 36) {
            let ctFont = nsFont as CTFont
            return renderSampleSheet(font: ctFont, displayName: fullName)
        }
        if !fullName.isEmpty, let nsFont = NSFont(name: fullName, size: 36) {
            return renderSampleSheet(font: nsFont as CTFont, displayName: fullName)
        }

        // Fall back to info card
        return renderInfoCard(title: fullName.isEmpty ? entry.name : fullName,
                              subtitle: family.isEmpty ? "Adobe Font Metrics" : "\(family) — \(weight)",
                              note: "PostScript font metadata file (.afm). The actual font outlines are stored separately as LWFN/PFB files.")
    }

    /// Render a simple info card when we can't render the font itself.
    private static func renderInfoCard(title: String, subtitle: String, note: String) -> NSImage {
        let width: CGFloat = 600
        let height: CGFloat = 200
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.textBackgroundColor.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        NSAttributedString(string: title, attributes: titleAttr)
            .draw(in: NSRect(x: 20, y: height - 50, width: width - 40, height: 32))

        let subAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        NSAttributedString(string: subtitle, attributes: subAttr)
            .draw(in: NSRect(x: 20, y: height - 78, width: width - 40, height: 22))

        let noteAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        NSAttributedString(string: note, attributes: noteAttr)
            .draw(in: NSRect(x: 20, y: 20, width: width - 40, height: 80))

        return image
    }
}
