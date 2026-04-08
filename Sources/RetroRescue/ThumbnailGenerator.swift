import Foundation
import AppKit
import VaultEngine
import ContainerCracker

/// L5: Thumbnail generation and storage pipeline.
/// Generates 128×128 PNG thumbnails and stores them in vault's thumbnails/ directory.
/// Integrates L1 (PICT), L2 (icons), L3 (text), L4 (sound waveform), L6 (rebuild).
public enum ThumbnailGenerator {

    static let thumbSize = 128

    // MARK: - Generate + Store

    /// Generate and store a thumbnail for a vault entry. Returns true if successful.
    @discardableResult
    public static func generateAndStore(vault: Vault, entry: VaultEntry) -> Bool {
        guard !entry.isDirectory else { return false }
        if let pngData = generateThumbnail(vault: vault, entry: entry) {
            try? vault.setThumbnail(for: entry.id, pngData: pngData)
            return true
        }
        return false
    }

    /// Generate thumbnail PNG data for a vault entry (does not store it).
    public static func generateThumbnail(vault: Vault, entry: VaultEntry) -> Data? {
        // L1: PICT thumbnail
        if FilePreviewHelper.isPICT(entry: entry) {
            if let pngData = FilePreviewHelper.convertPICTtoPNG(vault: vault, entry: entry),
               let img = NSImage(data: pngData) {
                return resizeAndEncode(img)
            }
        }
        // L1b: MacPaint thumbnail
        if FilePreviewHelper.isMacPaint(entry: entry) {
            if let data = try? vault.dataFork(for: entry.id),
               let img = FilePreviewHelper.decodeMacPaintData(data) {
                return resizeAndEncode(img)
            }
        }
        // L2: Icon from resource fork
        if let icon = FilePreviewHelper.iconFromResourceFork(vault: vault, entry: entry) {
            return resizeAndEncode(icon)
        }
        // L3: Text thumbnail (first 4 lines rendered as image)
        if FilePreviewHelper.isTextPreviewable(entry: entry) {
            if let text = FilePreviewHelper.readTextContent(vault: vault, entry: entry) {
                return textThumbnail(text)
            }
        }
        // L4: Sound waveform thumbnail
        if let rsrcData = try? vault.rsrcFork(for: entry.id), !rsrcData.isEmpty {
            let parser = ResourceForkParser(data: rsrcData)
            if parser.isValid, let sndEntry = parser.findAll(type: "snd ").first,
               let sndData = parser.readData(for: sndEntry),
               let info = ResourceRenderers.parseSnd(sndData), info.encoding == 0 {
                let pcmStart = info.dataOffset
                let pcmLen = min(info.numFrames, sndData.count - pcmStart)
                if pcmLen > 0 {
                    let pcm = Data(sndData[pcmStart..<(pcmStart + pcmLen)])
                    if let waveImg = FilePreviewHelper.waveformImage(pcmData: pcm,
                           sampleSize: info.sampleSize, width: thumbSize, height: thumbSize / 2) {
                        return resizeAndEncode(waveImg)
                    }
                }
            }
        }
        return nil
    }

    // MARK: - L6: Rebuild All Thumbnails

    /// Regenerate thumbnails for all entries in the vault.
    /// Returns (generated, skipped) counts.
    public static func rebuildAll(vault: Vault,
                                  progress: ((String, Double) -> Void)? = nil) -> (Int, Int) {
        vault.deleteAllThumbnails()
        let entries = (try? vault.entries()) ?? []
        let allEntries = entries.flatMap { entry -> [VaultEntry] in
            var result = [entry]
            if let kids = try? vault.entries(parentID: entry.id) {
                result.append(contentsOf: kids)
            }
            return result
        }
        var generated = 0, skipped = 0
        let total = Double(allEntries.count)
        for (i, entry) in allEntries.enumerated() {
            progress?(entry.name, Double(i) / max(1, total))
            if generateAndStore(vault: vault, entry: entry) {
                generated += 1
            } else {
                skipped += 1
            }
        }
        progress?("Done", 1.0)
        return (generated, skipped)
    }

    // MARK: - Helpers

    /// Resize an NSImage to thumbSize×thumbSize and encode as PNG.
    private static func resizeAndEncode(_ image: NSImage) -> Data? {
        let size = NSSize(width: thumbSize, height: thumbSize)
        let resized = NSImage(size: size)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }

    /// L3: Render first 4 lines of text as a thumbnail image.
    private static func textThumbnail(_ text: String) -> Data? {
        let lines = text.components(separatedBy: .newlines).prefix(4)
        let preview = lines.joined(separator: "\n")
        let size = NSSize(width: thumbSize, height: thumbSize)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(white: 0.95, alpha: 1.0).setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.darkGray
        ]
        let rect = NSRect(x: 6, y: 6, width: Double(thumbSize) - 12, height: Double(thumbSize) - 12)
        (preview as NSString).draw(in: rect, withAttributes: attrs)
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }

    /// Load a cached thumbnail as NSImage.
    public static func loadThumbnail(vault: Vault, id: String) -> NSImage? {
        guard let data = vault.thumbnail(for: id) else { return nil }
        return NSImage(data: data)
    }
}
