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
    /// Most supported formats (WriteNow, MacWrite, ClarisWorks, Word, …) store
    /// their content in the data fork. A few formats also need the resource
    /// fork — for those, mwaw will gracefully fail and we fall back to hex.
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
        let tempURL = tempDir.appendingPathComponent(
            safeName.isEmpty ? "document" : safeName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
            return nil
        }
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
