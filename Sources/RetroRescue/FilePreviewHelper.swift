import Foundation
import AppKit
import VaultEngine

/// Comprehensive file type handling for classic Mac and modern files.
/// Handles preview, Quick Look, and Open for every known file type.
enum FilePreviewHelper {

    // MARK: - Text-based files (inline preview)

    /// Classic Mac type codes that are text-based.
    static let textTypeCodes: Set<String> = [
        "TEXT",     // Plain text
        "ttro",     // Read-only text (TeachText/SimpleText)
        "sEXT",     // Styled text
        "utxt",     // Unicode text
        "clpt",     // Text clipping
        "ttxt",     // Teach text document
    ]

    /// File extensions previewable as text — organized by era and purpose.
    static let textExtensions: Set<String> = {
        var exts = Set<String>()

        // === CLASSIC MAC ERA ===
        // Plain text
        exts.formUnion(["txt", "text", "utxt"])
        // Rez source files (resource compiler)
        exts.formUnion(["r", "rez"])
        // Pascal (THE language of classic Mac)
        exts.formUnion(["p", "pas", "pp", "inc"])
        // C/C++ (MPW, THINK C, CodeWarrior)
        exts.formUnion(["c", "h", "cp", "cpp", "hpp", "cc", "hh", "mm"])
        // Assembly
        exts.formUnion(["a", "asm", "s"])
        // Build files
        exts.formUnion(["make", "mak", "def", "exp", "map"])
        // HyperCard
        exts.formUnion(["hc"])

        // === BBS / SCENE ERA ===
        exts.formUnion(["nfo", "diz", "asc", "ans", "1st", "me", "now", "faq"])

        // === WEB / INTERNET ===
        exts.formUnion(["html", "htm", "shtml", "xhtml",
                        "css", "js", "mjs", "json", "jsonl",
                        "xml", "xsl", "xslt", "dtd", "xsd",
                        "csv", "tsv",
                        "php", "asp", "jsp", "cgi",
                        "rss", "atom", "svg"])

        // === PROGRAMMING LANGUAGES ===
        // Apple ecosystem
        exts.formUnion(["swift", "m", "playground"])
        // Scripting
        exts.formUnion(["py", "pyw", "rb", "pl", "pm", "lua",
                        "tcl", "tk", "awk", "sed"])
        // Shell
        exts.formUnion(["sh", "bash", "zsh", "csh", "ksh", "fish"])
        // JVM
        exts.formUnion(["java", "kt", "scala", "groovy", "clj", "cljs"])
        // Systems
        exts.formUnion(["rs", "go", "zig", "nim", "d"])
        // Web/JS
        exts.formUnion(["ts", "tsx", "jsx", "vue", "svelte"])
        // Functional
        exts.formUnion(["hs", "ml", "mli", "erl", "ex", "exs",
                        "lisp", "el", "scm", "rkt"])
        // Legacy
        exts.formUnion(["f", "f90", "for", "ftn",
                        "cob", "cbl",
                        "ada", "adb", "ads",
                        "bas", "vb", "vbs",
                        "sql", "proto", "graphql", "gql"])

        // === CONFIG / DATA ===
        exts.formUnion(["yaml", "yml", "toml", "ini", "cfg", "conf",
                        "plist",  // macOS property list (XML)
                        "env", "properties", "reg",
                        "editorconfig", "eslintrc", "prettierrc"])

        // === DOCUMENTATION ===
        exts.formUnion(["md", "markdown", "mkd", "mkdn", "mdown",
                        "rst", "adoc", "asciidoc", "org",
                        "tex", "latex", "bib", "sty", "cls",
                        "pod", "man", "mdoc",
                        "rtf"])

        // === CHECKSUMS / SIGNATURES ===
        exts.formUnion(["md5", "sha1", "sha256", "sha512",
                        "sfv", "sum", "sig"])

        // === PATCHES / DIFFS ===
        exts.formUnion(["diff", "patch"])

        // === BUILD / PROJECT ===
        exts.formUnion(["cmake", "gradle", "sbt", "cabal",
                        "gemspec", "podspec", "gyp"])

        // === SUBTITLES ===
        exts.formUnion(["srt", "sub", "ass", "ssa", "vtt"])

        // === LOGS / OUTPUT ===
        exts.formUnion(["log", "out", "err"])

        return exts
    }()

    /// Well-known filenames without extensions that are text.
    static let textFilenames: Set<String> = [
        "readme", "read me", "read_me",
        "license", "licence", "copying",
        "authors", "contributors", "credits",
        "changelog", "changes", "history", "news",
        "todo", "fixme", "bugs", "hacking",
        "install", "building",
        "makefile", "gnumakefile", "rakefile",
        "gemfile", "podfile", "cartfile",
        "dockerfile", "vagrantfile", "procfile",
        "cmakelists.txt",
    ]

    /// File extensions macOS Quick Look can handle.
    static let quickLookExtensions: Set<String> = {
        var exts = Set<String>()
        // Images
        exts.formUnion(["png", "jpg", "jpeg", "gif", "tiff", "tif",
                        "bmp", "heic", "heif", "webp", "svg", "ico",
                        "icns", "psd", "eps",
                        "raw", "cr2", "nef", "arw", "dng"])
        // Documents
        exts.formUnion(["pdf",
                        "doc", "docx", "xls", "xlsx", "ppt", "pptx",
                        "pages", "numbers", "keynote",
                        "rtf", "rtfd"])
        // Audio
        exts.formUnion(["mp3", "aiff", "aif", "wav", "m4a", "aac",
                        "flac", "ogg", "wma", "mid", "midi"])
        // Video
        exts.formUnion(["mp4", "mov", "m4v", "avi", "mkv", "wmv",
                        "qt", "webm"])
        // Fonts
        exts.formUnion(["ttf", "otf", "woff", "woff2", "dfont"])
        // 3D
        exts.formUnion(["usdz", "obj", "stl"])
        // All text files are also Quick Lookable
        exts.formUnion(textExtensions)
        return exts
    }()

    // MARK: - Detection

    /// Check if a file can be previewed as text.
    static func isTextPreviewable(entry: VaultEntry) -> Bool {
        // Check type code first (classic Mac)
        if let type = entry.typeCode, textTypeCodes.contains(type) {
            return true
        }
        // Check extension
        let ext = (entry.name as NSString).pathExtension.lowercased()
        if textExtensions.contains(ext) { return true }
        // Check well-known filenames (no extension)
        let lower = entry.name.lowercased()
        if textFilenames.contains(lower) { return true }
        return false
    }

    /// Check if a file can be Quick Looked.
    static func isQuickLookable(entry: VaultEntry) -> Bool {
        let ext = (entry.name as NSString).pathExtension.lowercased()
        return quickLookExtensions.contains(ext)
            || isTextPreviewable(entry: entry)
    }

    // MARK: - Actions

    /// Write a vault file to a temp location for preview/open.
    static func writeTempFile(vault: Vault, entry: VaultEntry) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-preview")
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent(entry.name)
        let data = try vault.dataFork(for: entry.id)
        try data.write(to: tempURL)
        return tempURL
    }

    /// Open a file in the default macOS app.
    /// PDFs are always opened in Preview.app, not the user's default PDF viewer.
    static func openInDefaultApp(vault: Vault, entry: VaultEntry) {
        guard let url = try? writeTempFile(vault: vault, entry: entry)
        else { return }

        let ext = (entry.name as NSString).pathExtension.lowercased()
        if ext == "pdf" {
            // Force Preview.app for PDFs
            let previewURL = URL(fileURLWithPath: "/System/Applications/Preview.app")
            NSWorkspace.shared.open([url], withApplicationAt: previewURL,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Read the text content of a file.
    /// Tries UTF-8 first, then MacRoman (classic Mac default encoding).
    /// Normalizes classic Mac line endings (\r) to Unix (\n).
    static func readTextContent(vault: Vault, entry: VaultEntry) -> String? {
        guard let data = try? vault.dataFork(for: entry.id) else { return nil }
        let text: String?
        if let utf8 = String(data: data, encoding: .utf8) {
            text = utf8
        } else if let mac = String(data: data, encoding: .macOSRoman) {
            text = mac
        } else {
            return nil
        }
        // Normalize line endings: \r\n → \n, then \r → \n
        return text?
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Human-readable description of what a file type is.
    static func fileTypeDescription(entry: VaultEntry) -> String? {
        if let type = entry.typeCode {
            switch type {
            case "TEXT": return "Plain Text"
            case "ttro": return "Read-Only Text (SimpleText)"
            case "PICT": return "QuickDraw Picture"
            case "APPL": return "Application"
            case "snd ": return "Sound Resource"
            case "PNTG": return "MacPaint Image"
            case "MOOV", "MooV": return "QuickTime Movie"
            case "FONT", "NFNT": return "Bitmap Font"
            case "sfnt": return "TrueType Font"
            case "rsrc": return "Resource File"
            case "INIT": return "System Extension"
            case "cdev": return "Control Panel"
            case "DRVR": return "Desk Accessory"
            case "sEXT": return "Styled Text"
            case "utxt": return "Unicode Text"
            default: return nil
            }
        }
        return nil
    }
}
