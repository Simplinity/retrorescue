import Foundation
import VaultEngine

/// Converts legacy Mac word processor / spreadsheet / database documents
/// using libmwaw (via bundled `mwaw2html` / `mwaw2text` / `mwawFile` tools).
///
/// Supported formats (via libmwaw 0.3.x):
/// - WriteNow 1.0 – 4.0           (`nX^n`/`nX^d`)
/// - MacWrite, MacWrite II, Pro   (`MWPd`/`MWPr`/`MW2D`)
/// - Microsoft Word 1 – 5.1 Mac   (`WDBN`/`W6BN`/`W8BN`)
/// - Microsoft Works Mac 1 – 4    (`AWWP`/`AWDB`/`AWSS`)
/// - ClarisWorks / AppleWorks     (`CWWP`/`CWSS`/`CWDB`/`CWGR`/`CWPR`)
/// - WordPerfect for Mac
/// - Nisus Writer Classic
/// - FullWrite Professional
/// - RagTime
/// - BeagleWorks, Ready Set Go!, More, Student Writing Center
/// - DOCMaker, MariNer Write, MaxWrite, WriteUp, eDOC, Zwrite
/// - MindWrite, MouseWrite, LightWay Text, Teach Text derivatives
/// - HanMac Word, ezPDF, Overhead Express
/// - … and ~40 more formats (see `libmwaw` wiki)
///
/// libmwaw is LGPL-2.1+ / MPL-2.0 licensed. Compatible with our GPLv3 distribution.
enum LegacyMacDocConverter {
}

extension LegacyMacDocConverter {

    /// Check if a vault entry is a legacy Mac document we can convert.
    /// Uses type code, then extension, then magic-byte sniffing of the data fork.
    static func canConvert(_ entry: VaultEntry) -> Bool {
        // By Mac type code (preferred — works for files without extensions)
        if let tc = entry.typeCode, legacyMacTypeCodes.contains(tc) {
            return true
        }
        // By filename extension (for files exported from Mac)
        let ext = (entry.name as NSString).pathExtension.lowercased()
        if legacyMacExtensions.contains(ext) { return true }
        return false
    }

    /// Same as `canConvert` but also performs magic-byte sniffing on the data
    /// fork. Use this when type code and extension are missing (e.g. files
    /// imported via Linux/Windows hosts that strip Mac metadata).
    static func canConvert(_ entry: VaultEntry, vault: Vault) -> Bool {
        if canConvert(entry) { return true }
        // Magic-byte sniff: WriteNow documents start with literal ASCII
        // "WriteNow" at offset 0 of the data fork.
        guard let data = try? vault.dataFork(for: entry.id), data.count >= 8
        else { return false }
        if data.prefix(8) == Data("WriteNow".utf8) { return true }
        return false
    }

    /// Human-readable name of the source format, if recognizable by type code.
    static func formatName(for entry: VaultEntry) -> String? {
        guard let tc = entry.typeCode else { return nil }
        return legacyMacTypeCodeNames[tc]
    }

    /// Human-readable name of the source format, using type code first then
    /// magic-byte sniffing of the data fork as a fallback.
    static func formatName(for entry: VaultEntry, vault: Vault) -> String? {
        if let name = formatName(for: entry) { return name }
        // Magic-byte detection
        guard let data = try? vault.dataFork(for: entry.id), data.count >= 8
        else { return nil }
        if data.prefix(8) == Data("WriteNow".utf8) {
            // Try to distinguish version via mwawFile if available
            if let detected = identifyViaMwawFile(vault: vault, entry: entry) {
                return detected
            }
            return "WriteNow Document"
        }
        return nil
    }

    /// Ask `mwawFile` what format it thinks this file is. Returns the
    /// human-readable label libmwaw uses (e.g. "WriteNow 3-4", "MacWrite II").
    private static func identifyViaMwawFile(vault: Vault, entry: VaultEntry) -> String? {
        guard let mwawFile = toolPath("mwawFile") else { return nil }
        guard let tempInput = writeTempForkFile(vault: vault, entry: entry)
        else { return nil }
        defer {
            try? FileManager.default.removeItem(
                at: tempInput.deletingLastPathComponent())
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mwawFile)
        // -f suppresses the filename prefix
        process.arguments = ["-f", tempInput.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let label = raw, !label.isEmpty else { return nil }
            return label
        } catch {
            return nil
        }
    }
}

// MARK: - Recognized formats

private let legacyMacTypeCodes: Set<String> = [
    // WriteNow
    "nX^n", "nX^d", "nX^r",
    // MacWrite family
    "MWPd", "MWPr", "MW2D", "MACA", "WORD",
    // Microsoft Word for Mac
    "WDBN", "W6BN", "W8BN", "WDMC",
    // Microsoft Works Mac
    "AWWP", "AWDB", "AWSS", "AWDR",
    // ClarisWorks / AppleWorks
    "CWWP", "CWSS", "CWDB", "CWGR", "CWPR", "CWPT",
    "BOBO", // AppleWorks creator (alt)
    // Nisus Writer Classic
    "NISI", "GLOB", "NSCT", "NIS!",
    // FullWrite Professional
    "FWRT", "FWRP",
    // WordPerfect Mac
    "WPC2", "WPD2", "WPD3",
    // RagTime
    "RTd1", "RTSt",
    // BeagleWorks / Ready Set Go / More / Student Writing Center
    "BWwp", "BWdb", "BWss",
    "RSGD", "MMPP",
    "MORE", "MOR2",
    "SWCw",
    // Misc Mac word processors libmwaw also handles
    "ZWRT", "MaxW", "MWII", "EDOC", "HANM",
    "LWT1", "LWT2", "LWTR",
    "DOCM", "MARI", "MWRT", "MIWR", "MOUS",
]

private let legacyMacExtensions: Set<String> = [
    // WriteNow sometimes uses .nx_ or .nx^n as exported extension
    "nx", "nxn", "nxd",
    // MacWrite variants
    "mcw", "mw", "mw2", "mwd", "mwii",
    // ClarisWorks / AppleWorks
    "cwk", "cws", "cwp", "cwdb", "cwss", "cwgr",
    // Word for Mac
    "mcw",
    // WordPerfect Mac
    "wpd", "wp",
    // Works Mac
    "wks",
    // Nisus
    "nwc",
    // RagTime
    "rag", "rtd",
    // FullWrite
    "fwr",
    // Generic legacy
    "doc", // only when type code also matches — .doc alone isn't enough
]

private let legacyMacTypeCodeNames: [String: String] = [
    "nX^n": "WriteNow Document",
    "nX^d": "WriteNow Document",
    "nX^r": "WriteNow Document",
    "MWPd": "MacWrite Pro Document",
    "MWPr": "MacWrite Pro Document",
    "MW2D": "MacWrite II Document",
    "MACA": "MacWrite Document",
    "WORD": "MacWrite Document",
    "WDBN": "Microsoft Word Document",
    "W6BN": "Microsoft Word 6 Document",
    "W8BN": "Microsoft Word 98 Document",
    "WDMC": "Microsoft Word Document",
    "AWWP": "Microsoft Works Word Processing",
    "AWDB": "Microsoft Works Database",
    "AWSS": "Microsoft Works Spreadsheet",
    "AWDR": "Microsoft Works Drawing",
    "CWWP": "ClarisWorks/AppleWorks Word Processing",
    "CWSS": "ClarisWorks/AppleWorks Spreadsheet",
    "CWDB": "ClarisWorks/AppleWorks Database",
    "CWGR": "ClarisWorks/AppleWorks Drawing",
    "CWPR": "ClarisWorks/AppleWorks Presentation",
    "CWPT": "ClarisWorks/AppleWorks Paint",
    "NISI": "Nisus Writer Document",
    "GLOB": "Nisus Writer Document",
    "NSCT": "Nisus Writer Document",
    "NIS!": "Nisus Writer Document",
    "FWRT": "FullWrite Professional Document",
    "FWRP": "FullWrite Professional Document",
    "WPC2": "WordPerfect Mac Document",
    "WPD2": "WordPerfect Mac Document",
    "WPD3": "WordPerfect Mac Document",
    "RTd1": "RagTime Document",
    "RTSt": "RagTime Stationery",
    "BWwp": "BeagleWorks Word Processing",
    "BWdb": "BeagleWorks Database",
    "BWss": "BeagleWorks Spreadsheet",
    "RSGD": "Ready, Set, Go! Document",
    "MMPP": "Ready, Set, Go! Document",
    "MORE": "More Document",
    "MOR2": "More 3.0 Document",
    "SWCw": "Student Writing Center Document",
]


// MARK: - Extraction

extension LegacyMacDocConverter {

    /// Look up a libmwaw tool path. Mirrors ToolChain's discovery order but
    /// doesn't require MainActor so it can be called from background contexts.
    static func toolPath(_ name: String) -> String? {
        let fm = FileManager.default
        // 1. Bundled in .app
        if let resPath = Bundle.main.resourcePath {
            let p = "\(resPath)/tools/\(name)"
            if fm.isExecutableFile(atPath: p) { return p }
        }
        // 2. Homebrew (dev fallback)
        #if DEBUG
        let homebrew = "/opt/homebrew/bin/\(name)"
        if fm.isExecutableFile(atPath: homebrew) { return homebrew }
        let homebrewOpt = "/opt/homebrew/opt/libmwaw/bin/\(name)"
        if fm.isExecutableFile(atPath: homebrewOpt) { return homebrewOpt }
        #endif
        return nil
    }

    /// Extract plain UTF-8 text from a legacy Mac document.
    /// Returns nil if mwaw2text is unavailable or extraction fails.
    static func extractText(vault: Vault, entry: VaultEntry) -> String? {
        guard let mwaw2text = toolPath("mwaw2text") else { return nil }
        guard let tempInput = writeTempForkFile(vault: vault, entry: entry)
        else { return nil }
        defer { try? FileManager.default.removeItem(at: tempInput) }

        let tempOutput = tempInput.deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempOutput) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mwaw2text)
        // mwaw2text -o output.txt input
        process.arguments = ["-o", tempOutput.path, tempInput.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return try String(contentsOf: tempOutput, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Extract HTML (with styling) from a legacy Mac document.
    /// Returns nil if mwaw2html is unavailable or extraction fails.
    static func extractHTML(vault: Vault, entry: VaultEntry) -> String? {
        guard let mwaw2html = toolPath("mwaw2html") else { return nil }
        guard let tempInput = writeTempForkFile(vault: vault, entry: entry)
        else { return nil }
        defer { try? FileManager.default.removeItem(at: tempInput) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mwaw2html)
        // mwaw2html writes to stdout
        process.arguments = [tempInput.path]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Convert a legacy Mac document to Markdown via the HTML intermediate.
    /// Returns nil if neither HTML nor text extraction works.
    static func convertToMarkdown(vault: Vault, entry: VaultEntry) -> String? {
        if let html = extractHTML(vault: vault, entry: entry) {
            return htmlToMarkdown(html)
        }
        // Fallback: plain text
        return extractText(vault: vault, entry: entry)
    }
}


// MARK: - Helpers

private extension LegacyMacDocConverter {

    /// Write vault entry's data fork to a temp file for libmwaw to read.
    /// If the entry has a resource fork, also writes a sibling AppleDouble
    /// `._<filename>` companion file so libmwaw can read both forks.
    /// Most supported formats (WriteNow, MacWrite, ClarisWorks, Word, …) store
    /// their content in the data fork — but libmwaw uses the resource fork to
    /// pick up styling, fonts, and metadata where available.
    static func writeTempForkFile(vault: Vault, entry: VaultEntry) -> URL? {
        guard let data = try? vault.dataFork(for: entry.id), !data.isEmpty
        else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-mwaw-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        // Use the original name so mwaw's internal filename-based hints work.
        // Sanitize illegal filesystem characters.
        let safeName = entry.name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let baseName = safeName.isEmpty ? "document" : safeName
        let tempURL = tempDir.appendingPathComponent(baseName)

        do {
            try data.write(to: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
            return nil
        }

        // If a resource fork exists, write a sibling AppleDouble companion.
        if let rsrc = try? vault.rsrcFork(for: entry.id), !rsrc.isEmpty {
            let companionURL = tempDir.appendingPathComponent("._\(baseName)")
            let typeCode = entry.typeCode ?? "????"
            let creatorCode = entry.creatorCode ?? "????"
            let appleDouble = makeAppleDouble(
                resourceFork: rsrc,
                typeCode: typeCode,
                creatorCode: creatorCode)
            try? appleDouble.write(to: companionURL)
        }

        return tempURL
    }

    /// Very lightweight HTML → Markdown conversion.
    /// libmwaw's HTML output is clean and predictable, so we don't need a full
    /// HTML parser. We only strip the obvious structural tags and convert the
    /// handful of inline formatting elements we care about.
    static func htmlToMarkdown(_ html: String) -> String {
        var s = html

        // Strip <head>…</head> and <style>…</style> blocks entirely.
        s = s.replacingOccurrences(
            of: "<head[^>]*>[\\s\\S]*?</head>",
            with: "",
            options: .regularExpression)
        s = s.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression)
        s = s.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression)

        // Headings
        for level in 1...6 {
            let hashes = String(repeating: "#", count: level)
            s = s.replacingOccurrences(
                of: "<h\(level)[^>]*>",
                with: "\n\n\(hashes) ",
                options: .regularExpression)
            s = s.replacingOccurrences(of: "</h\(level)>", with: "\n\n")
        }
        return finishMarkdown(s)
    }

    /// Finish Markdown conversion — bold/italic/links/lists/paragraphs.
    static func finishMarkdown(_ input: String) -> String {
        var s = input

        // Inline formatting
        s = s.replacingOccurrences(
            of: "<(b|strong)[^>]*>", with: "**", options: .regularExpression)
        s = s.replacingOccurrences(
            of: "</(b|strong)>", with: "**", options: .regularExpression)
        s = s.replacingOccurrences(
            of: "<(i|em)[^>]*>", with: "*", options: .regularExpression)
        s = s.replacingOccurrences(
            of: "</(i|em)>", with: "*", options: .regularExpression)
        s = s.replacingOccurrences(
            of: "<u[^>]*>", with: "_", options: .regularExpression)
        s = s.replacingOccurrences(of: "</u>", with: "_")

        // Lists
        s = s.replacingOccurrences(of: "<ul[^>]*>", with: "\n",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "</ul>", with: "\n")
        s = s.replacingOccurrences(of: "<ol[^>]*>", with: "\n",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "</ol>", with: "\n")
        s = s.replacingOccurrences(of: "<li[^>]*>", with: "- ",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "</li>", with: "\n")

        // Paragraphs & line breaks
        s = s.replacingOccurrences(of: "<p[^>]*>", with: "\n\n",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "</p>", with: "")
        s = s.replacingOccurrences(of: "<br[^>]*/?>", with: "  \n",
                                   options: .regularExpression)

        // Strip all remaining tags
        s = s.replacingOccurrences(of: "<[^>]+>", with: "",
                                   options: .regularExpression)

        // HTML entities
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&#39;", with: "'")
        s = s.replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
        s = s.replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
        s = s.replacingOccurrences(of: "&lsquo;", with: "\u{2018}")
        s = s.replacingOccurrences(of: "&rsquo;", with: "\u{2019}")

        // Collapse 3+ blank lines into 2
        s = s.replacingOccurrences(
            of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Minimal AppleDouble writer

private extension LegacyMacDocConverter {

    /// Build a minimal AppleDouble v2 file containing a Finder Info entry
    /// (with type/creator codes) and a resource fork entry.
    /// Reference: RFC 1740 / Apple Technical Note FL18 "AppleSingle/AppleDouble".
    /// Layout:
    ///   +0   /4  magic         0x00051607
    ///   +4   /4  version       0x00020000
    ///   +8   /16 filler        zeros
    ///   +24  /2  entry count   N (big-endian)
    ///   +26  /N*12 entry descriptors  (id, offset, length)
    ///   +... entry data
    static func makeAppleDouble(resourceFork: Data,
                                typeCode: String,
                                creatorCode: String) -> Data {
        var out = Data()

        // Header
        out.append(contentsOf: [0x00, 0x05, 0x16, 0x07])  // magic
        out.append(contentsOf: [0x00, 0x02, 0x00, 0x00])  // version 2
        out.append(Data(repeating: 0, count: 16))         // filler
        out.append(contentsOf: [0x00, 0x02])              // 2 entries

        // Build Finder Info entry data (32 bytes):
        //   +0 /4  type code
        //   +4 /4  creator code
        //   +8 /2  finder flags
        //   +10/4  location (v,h)
        //   +14/2  folder
        //   +16/16 extended finder info (zeros)
        var finderInfo = Data()
        finderInfo.append(fourCharData(typeCode))
        finderInfo.append(fourCharData(creatorCode))
        finderInfo.append(Data(repeating: 0, count: 24))

        // Compute offsets
        // Header size: 4 + 4 + 16 + 2 = 26
        // Each entry descriptor: 12 bytes, we have 2 → 24
        // Data starts at offset 26 + 24 = 50
        let headerEnd: UInt32 = 26 + 24
        let finderOffset: UInt32 = headerEnd
        let finderLength: UInt32 = UInt32(finderInfo.count)
        let rsrcOffset: UInt32 = finderOffset + finderLength
        let rsrcLength: UInt32 = UInt32(resourceFork.count)

        // Entry descriptor 1: Finder Info (id 9)
        out.append(beUInt32(9))
        out.append(beUInt32(finderOffset))
        out.append(beUInt32(finderLength))
        // Entry descriptor 2: Resource Fork (id 2)
        out.append(beUInt32(2))
        out.append(beUInt32(rsrcOffset))
        out.append(beUInt32(rsrcLength))

        // Entry data
        out.append(finderInfo)
        out.append(resourceFork)

        return out
    }

    /// Convert a 4-character code String to 4 bytes, padding/truncating as needed.
    static func fourCharData(_ s: String) -> Data {
        let bytes = Array(s.utf8.prefix(4))
        var out = Data(bytes)
        while out.count < 4 { out.append(0x20) }  // pad with spaces
        return out
    }

    /// Big-endian UInt32 as Data.
    static func beUInt32(_ v: UInt32) -> Data {
        var be = v.bigEndian
        return Data(bytes: &be, count: 4)
    }
}
