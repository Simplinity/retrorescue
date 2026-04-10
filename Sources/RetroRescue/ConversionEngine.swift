import Foundation
import AppKit
import VaultEngine
import ContainerCracker

/// Conversion engine for classic Mac files to modern formats (J7-J13).
public enum ConversionEngine {

    // MARK: - J13: Plain Text Charset Conversion

    /// Supported classic Mac character encodings.
    public enum Charset: String, CaseIterable {
        case macRoman = "MacRoman"
        case macJapanese = "MacJapanese"
        case macCyrillic = "MacCyrillic"
        case macGreek = "MacGreek"
        case macCentralEurope = "MacCentralEurope"
        case latin1 = "ISO Latin 1"
        case utf8 = "UTF-8"

        var encoding: String.Encoding {
            switch self {
            case .macRoman: return .macOSRoman
            case .macJapanese: return .japaneseEUC
            case .macCyrillic: return .windowsCP1251
            case .macGreek: return .windowsCP1253
            case .macCentralEurope: return .windowsCP1250
            case .latin1: return .isoLatin1
            case .utf8: return .utf8
            }
        }
    }

    /// Convert text between charsets. Returns UTF-8 data.
    public static func convertText(_ data: Data, from: Charset = .macRoman) -> Data? {
        guard let text = String(data: data, encoding: from.encoding) else { return nil }
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.data(using: .utf8)
    }

    /// Detect the most likely charset of text data.
    public static func detectCharset(_ data: Data) -> Charset {
        if String(data: data, encoding: .utf8) != nil { return .utf8 }
        // Check for high-byte patterns typical of MacRoman
        let highBytes = data.filter { $0 > 127 }
        if highBytes.isEmpty { return .utf8 } // pure ASCII
        return .macRoman // default for classic Mac files
    }

    // MARK: - J7: Bitmap Font → BDF Export

    /// Convert a FONT/NFNT resource to BDF (Bitmap Distribution Format).
    /// BDF is a standard text-based bitmap font format readable by modern tools.
    public static func fontToBDF(_ fontData: Data, name: String, id: Int16) -> Data? {
        guard let info = ResourceRenderers.parseBitmapFont(fontData) else { return nil }
        guard info.fRectHeight > 0 && info.rowWords > 0 else { return nil }
        let pointSize = info.fRectHeight
        var bdf = ""
        bdf += "STARTFONT 2.1\n"
        bdf += "FONT -RetroRescue-\(name)-Medium-R-Normal--\(pointSize)-\(pointSize * 10)-72-72-C-\(info.widMax * 10)-MacRoman\n"
        bdf += "SIZE \(pointSize) 72 72\n"
        bdf += "FONTBOUNDINGBOX \(info.widMax) \(info.fRectHeight) 0 \(-info.descent)\n"
        bdf += "STARTPROPERTIES 4\n"
        bdf += "FONT_ASCENT \(info.ascent)\n"
        bdf += "FONT_DESCENT \(info.descent)\n"
        bdf += "DEFAULT_CHAR 0\n"
        bdf += "PIXEL_SIZE \(pointSize)\n"
        bdf += "ENDPROPERTIES\n"
        let charCount = max(0, info.lastChar - info.firstChar + 1)
        bdf += "CHARS \(charCount)\n"

        // Extract bitmap data for each character
        // Font bitmap starts at offset 26 in FONT/NFNT data
        let bitmapOffset = 26
        let rowBytes = info.rowWords * 2
        for ch in info.firstChar...info.lastChar {
            bdf += "STARTCHAR char\(ch)\n"
            bdf += "ENCODING \(ch)\n"
            bdf += "SWIDTH \(info.widMax * 1000 / pointSize) 0\n"
            bdf += "DWIDTH \(info.widMax) 0\n"
            bdf += "BBX \(info.widMax) \(info.fRectHeight) 0 \(-info.descent)\n"
            bdf += "BITMAP\n"
            for row in 0..<info.fRectHeight {
                let byteOff = bitmapOffset + row * rowBytes
                if byteOff + 2 <= fontData.count {
                    bdf += String(format: "%02X%02X\n", fontData[byteOff], fontData[byteOff + 1])
                } else {
                    bdf += "0000\n"
                }
            }
            bdf += "ENDCHAR\n"
        }
        bdf += "ENDFONT\n"
        return bdf.data(using: .utf8)
    }

    // MARK: - J8: QuickTime → MP4 via ffmpeg

    /// Convert a classic QuickTime movie to H.264 MP4 using ffmpeg.
    /// Returns the output URL, or nil if ffmpeg is not available.
    public static func convertQuickTime(inputURL: URL, outputDir: URL) -> URL? {
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ffmpeg = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return nil // ffmpeg not installed
        }
        let outputURL = outputDir.appendingPathComponent(
            (inputURL.deletingPathExtension().lastPathComponent) + ".mp4")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = ["-i", inputURL.path, "-c:v", "libx264", "-preset", "fast",
                            "-crf", "23", "-c:a", "aac", "-b:a", "128k",
                            "-movflags", "+faststart", "-y", outputURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 { return outputURL }
        } catch { }
        return nil
    }

    // MARK: - J9: ClarisWorks / AppleWorks → Markdown

    /// Extract text from a ClarisWorks/AppleWorks document.
    /// ClarisWorks uses a proprietary binary format. This does best-effort text extraction
    /// by scanning for text runs in the data fork. Full formatting would require ~3000 lines.
    public static func extractClarisWorksText(_ data: Data) -> String? {
        // ClarisWorks documents have "BOBO" marker at offset 0 for word processing
        // AppleWorks GS has different markers
        guard data.count > 100 else { return nil }

        // Strategy: scan for runs of printable MacRoman text
        var textRuns: [String] = []
        var currentRun = Data()
        let minRunLength = 8  // minimum chars to consider a text run

        for byte in data {
            let isPrintable = (byte >= 0x20 && byte < 0x7F) || byte == 0x0D || byte == 0x0A
                || (byte >= 0x80 && byte != 0xFF) // MacRoman high chars
            if isPrintable {
                currentRun.append(byte)
            } else {
                if currentRun.count >= minRunLength {
                    if let text = String(data: currentRun, encoding: .macOSRoman) {
                        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
                        textRuns.append(normalized)
                    }
                }
                currentRun = Data()
            }
        }
        // Flush last run
        if currentRun.count >= minRunLength,
           let text = String(data: currentRun, encoding: .macOSRoman) {
            textRuns.append(text.replacingOccurrences(of: "\r", with: "\n"))
        }

        guard !textRuns.isEmpty else { return nil }
        // Join runs, filter out obvious binary garbage
        let result = textRuns.filter { run in
            let alphaRatio = Double(run.filter { $0.isLetter || $0.isWhitespace }.count) / Double(run.count)
            return alphaRatio > 0.5  // at least 50% alphabetic/whitespace
        }.joined(separator: "\n\n")
        return result.isEmpty ? nil : "# Extracted Text (ClarisWorks/AppleWorks)\n\n" + result
    }

    /// Check if data looks like a ClarisWorks document.
    public static func isClarisWorks(_ data: Data, typeCode: String?) -> Bool {
        if let tc = typeCode, ["CWWP", "CWK ", "AAPL"].contains(tc) { return true }
        // BOBO marker at various offsets
        if data.count > 4 {
            let header = String(data: data[0..<4], encoding: .ascii)
            if header == "BOBO" { return true }
        }
        return false
    }

    // MARK: - J10: MacWrite → Markdown / RTF

    /// Extract text from a MacWrite document.
    /// MacWrite format: version(2) + paragraphs with style info.
    /// MacWrite II and MacWrite Pro have different formats.
    public static func extractMacWriteText(_ data: Data) -> String? {
        guard data.count > 10 else { return nil }
        // MacWrite version at offset 0-1
        let version = Int(data[0]) << 8 | Int(data[1])
        guard version == 3 || version == 6 else {
            // Try generic text extraction for unknown versions
            return extractGenericText(data)
        }
        // MacWrite v3: text starts after header (offset varies)
        // Paragraphs are preceded by formatting info
        // Simplified: scan for text paragraphs
        return extractGenericText(data)
    }

    /// Generic text extraction from any binary document — best effort.
    public static func extractGenericText(_ data: Data) -> String? {
        var runs: [String] = []
        var current = Data()
        for byte in data {
            let ok = (byte >= 0x20 && byte < 0x7F) || byte == 0x0D || byte == 0x0A || byte == 0x09
                || (byte >= 0x80 && byte < 0xFF)
            if ok { current.append(byte) }
            else {
                if current.count >= 12 {
                    if let t = String(data: current, encoding: .macOSRoman) {
                        runs.append(t.replacingOccurrences(of: "\r", with: "\n"))
                    }
                }
                current = Data()
            }
        }
        if current.count >= 12,
           let t = String(data: current, encoding: .macOSRoman) {
            runs.append(t.replacingOccurrences(of: "\r", with: "\n"))
        }
        let filtered = runs.filter { r in
            Double(r.filter { $0.isLetter || $0.isWhitespace }.count) / Double(max(1, r.count)) > 0.5
        }
        return filtered.isEmpty ? nil : "# Extracted Text\n\n" + filtered.joined(separator: "\n\n")
    }

    public static func isMacWrite(_ data: Data, typeCode: String?) -> Bool {
        if let tc = typeCode, ["MWII", "MWRT", "WORD"].contains(tc) { return true }
        if data.count > 2 {
            let ver = Int(data[0]) << 8 | Int(data[1])
            return ver == 3 || ver == 6
        }
        return false
    }

    // MARK: - J11: Batch Export

    /// Export an entire vault to a directory with modern formats + metadata.json.
    public static func batchExport(vault: Vault, outputDir: URL,
                                   progress: ((String, Double) -> Void)? = nil) throws {
        let entries = try vault.entries()
        let total = Double(entries.count)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var manifest: [[String: Any]] = []
        for (i, entry) in entries.enumerated() {
            progress?(entry.name, Double(i) / total)
            guard !entry.isDirectory else { continue }
            let safeDir = outputDir.appendingPathComponent(entry.parentID ?? "root")
            try FileManager.default.createDirectory(at: safeDir, withIntermediateDirectories: true)
            // Write data fork
            let dataFork = try vault.dataFork(for: entry.id)
            let filePath = safeDir.appendingPathComponent(entry.name)
            try dataFork.write(to: filePath)
            // Write resource fork as xattr if present
            let rsrcFork = try vault.rsrcFork(for: entry.id)
            if !rsrcFork.isEmpty {
                try filePath.withUnsafeFileSystemRepresentation { path in
                    guard let path else { return }
                    rsrcFork.withUnsafeBytes { buf in
                        _ = setxattr(path, "com.apple.ResourceFork", buf.baseAddress, rsrcFork.count, 0, 0)
                    }
                }
            }
            // Metadata entry
            var meta: [String: Any] = [
                "name": entry.name, "id": entry.id, "size": dataFork.count,
                "rsrc_size": rsrcFork.count
            ]
            if let tc = entry.typeCode { meta["type_code"] = tc }
            if let cc = entry.creatorCode { meta["creator_code"] = cc }
            manifest.append(meta)
        }
        // Write manifest
        let jsonData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: outputDir.appendingPathComponent("metadata.json"))
        progress?("Done", 1.0)
    }

    // MARK: - J12: Restore Mode (vault → emulator-ready files)

    /// Export vault contents as emulator-ready files with AppleDouble resource forks.
    /// SheepShaver and Basilisk II use AppleDouble (._prefix) for resource forks.
    public static func restoreForEmulator(vault: Vault, outputDir: URL,
                                          progress: ((String, Double) -> Void)? = nil) throws {
        let entries = try vault.entries()
        let total = Double(entries.count)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        for (i, entry) in entries.enumerated() {
            progress?(entry.name, Double(i) / total)
            guard !entry.isDirectory else { continue }

            let filePath = outputDir.appendingPathComponent(entry.name)
            let dataFork = try vault.dataFork(for: entry.id)
            try dataFork.write(to: filePath)

            // Create AppleDouble companion (._filename) for resource fork + Finder info
            let rsrcFork = try vault.rsrcFork(for: entry.id)
            let typeCode = entry.typeCode ?? ""
            let creatorCode = entry.creatorCode ?? ""
            if !rsrcFork.isEmpty || !typeCode.isEmpty {
                let adPath = outputDir.appendingPathComponent("._" + entry.name)
                let adData = buildAppleDouble(rsrcFork: rsrcFork,
                                             typeCode: typeCode, creatorCode: creatorCode)
                try adData.write(to: adPath)
            }
        }
        progress?("Done", 1.0)
    }

    /// Build an AppleDouble file (version 2) with resource fork and Finder info.
    private static func buildAppleDouble(rsrcFork: Data, typeCode: String, creatorCode: String) -> Data {
        var ad = Data()
        // AppleDouble magic + version
        ad.append(contentsOf: [0x00, 0x05, 0x16, 0x07]) // magic
        ad.append(contentsOf: [0x00, 0x02, 0x00, 0x00]) // version 2
        ad.append(Data(repeating: 0, count: 16))          // filler
        // Number of entries: 2 (Finder info + resource fork)
        let numEntries: UInt16 = rsrcFork.isEmpty ? 1 : 2
        ad.append(contentsOf: withUnsafeBytes(of: numEntries.bigEndian) { Array($0) })
        // Entry descriptors start at offset 26
        let finderInfoOffset: UInt32 = 26 + UInt32(numEntries) * 12
        let finderInfoLen: UInt32 = 32
        // Entry 1: Finder Info (ID=9)
        ad.append(contentsOf: withUnsafeBytes(of: UInt32(9).bigEndian) { Array($0) })
        ad.append(contentsOf: withUnsafeBytes(of: finderInfoOffset.bigEndian) { Array($0) })
        ad.append(contentsOf: withUnsafeBytes(of: finderInfoLen.bigEndian) { Array($0) })

        if !rsrcFork.isEmpty {
            // Entry 2: Resource Fork (ID=2)
            let rsrcOffset = finderInfoOffset + finderInfoLen
            ad.append(contentsOf: withUnsafeBytes(of: UInt32(2).bigEndian) { Array($0) })
            ad.append(contentsOf: withUnsafeBytes(of: rsrcOffset.bigEndian) { Array($0) })
            ad.append(contentsOf: withUnsafeBytes(of: UInt32(rsrcFork.count).bigEndian) { Array($0) })
        }
        // Finder Info: type(4) + creator(4) + flags(2) + location(4) + folder(2) + reserved(16)
        var finderInfo = Data(repeating: 0, count: 32)
        if typeCode.count == 4, let typeData = typeCode.data(using: .macOSRoman) {
            finderInfo.replaceSubrange(0..<4, with: typeData)
        }
        if creatorCode.count == 4, let creatorData = creatorCode.data(using: .macOSRoman) {
            finderInfo.replaceSubrange(4..<8, with: creatorData)
        }
        ad.append(finderInfo)
        // Resource fork data
        if !rsrcFork.isEmpty {
            ad.append(rsrcFork)
        }
        return ad
    }

    // MARK: - Unified Conversion Dispatch

    /// Check if a file can be converted to a modern format.
    public static func canConvert(entry: VaultEntry, vault: Vault) -> Bool {
        if FilePreviewHelper.isPICT(entry: entry) { return true }
        if FilePreviewHelper.isMacPaint(entry: entry) { return true }
        if LegacyMacDocConverter.canConvert(entry, vault: vault) { return true }
        if isClarisWorks(Data(), typeCode: entry.typeCode) { return true }
        if isMacWrite(Data(), typeCode: entry.typeCode) { return true }
        if entry.typeCode == "TEXT" || entry.typeCode == "ttro" { return true }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        if ["mov", "qt"].contains(ext) || entry.typeCode == "MooV" { return true }
        return false
    }

    /// Human-readable description of what the conversion produces.
    public static func conversionTarget(entry: VaultEntry) -> String? {
        if FilePreviewHelper.isPICT(entry: entry) { return "PNG image" }
        if FilePreviewHelper.isMacPaint(entry: entry) { return "PNG image" }
        if LegacyMacDocConverter.canConvert(entry) {
            let name = LegacyMacDocConverter.formatName(for: entry) ?? "legacy Mac document"
            return "Markdown text (from \(name))"
        }
        if isClarisWorks(Data(), typeCode: entry.typeCode) { return "Markdown text" }
        if isMacWrite(Data(), typeCode: entry.typeCode) { return "Markdown text" }
        if entry.typeCode == "TEXT" || entry.typeCode == "ttro" { return "UTF-8 text (.txt)" }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        if ["mov", "qt"].contains(ext) || entry.typeCode == "MooV" { return "MP4 video (requires ffmpeg)" }
        return nil
    }

    /// Perform the conversion and return (filename, data) for the result.
    public static func convert(entry: VaultEntry, vault: Vault) -> (String, Data)? {
        guard let data = try? vault.dataFork(for: entry.id) else { return nil }
        let baseName = (entry.name as NSString).deletingPathExtension

        // PICT → PNG
        if FilePreviewHelper.isPICT(entry: entry) {
            if let png = FilePreviewHelper.convertPICTtoPNG(vault: vault, entry: entry) {
                return (baseName + ".png", png)
            }
        }
        // MacPaint → PNG
        if FilePreviewHelper.isMacPaint(entry: entry) {
            if let img = FilePreviewHelper.decodeMacPaintData(data),
               let tiff = img.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                return (baseName + ".png", png)
            }
        }
        // Legacy Mac docs (WriteNow, MacWrite II/Pro, Word 1-5, Works, Nisus,
        // ClarisWorks, FullWrite, RagTime, …) → Markdown via libmwaw
        if LegacyMacDocConverter.canConvert(entry, vault: vault) {
            if let md = LegacyMacDocConverter.convertToMarkdown(vault: vault, entry: entry),
               let mdData = md.data(using: .utf8) {
                return (baseName + ".md", mdData)
            }
        }
        // ClarisWorks → Markdown
        if isClarisWorks(data, typeCode: entry.typeCode) {
            if let text = extractClarisWorksText(data), let md = text.data(using: .utf8) {
                return (baseName + ".md", md)
            }
        }
        // MacWrite → Markdown
        if isMacWrite(data, typeCode: entry.typeCode) {
            if let text = extractMacWriteText(data), let md = text.data(using: .utf8) {
                return (baseName + ".md", md)
            }
        }
        // TEXT → UTF-8
        if entry.typeCode == "TEXT" || entry.typeCode == "ttro" {
            if let utf8 = convertText(data) {
                return (baseName + ".txt", utf8)
            }
        }
        return nil
    }
}
