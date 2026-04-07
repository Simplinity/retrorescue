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

    /// Rich information about a file type, including historical context.
    struct FileTypeInfo {
        let name: String
        let description: String
        let history: String?
    }

    /// Human-readable description of what a file type is.
    static func fileTypeDescription(entry: VaultEntry) -> String? {
        // Check type code first
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
            case "AIFF": return "AIFF Audio"
            case "JPEG": return "JPEG Image"
            case "GIFf": return "GIF Image"
            case "PNGf": return "PNG Image"
            case "TIFF": return "TIFF Image"
            case "PDF ": return "PDF Document"
            case "WDBN": return "Microsoft Word Document"
            case "XLS ": return "Microsoft Excel Spreadsheet"
            case "SIT!": return "StuffIt Archive"
            case "SITD": return "StuffIt Deluxe Archive"
            case "dImg": return "DiskCopy Disk Image"
            case "ZSYS": return "System File"
            case "FNDR": return "Finder"
            default: break
            }
        }

        // Fall back to extension
        let ext = (entry.name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "text": return "Plain Text"
        case "rtf": return "Rich Text Format"
        case "html", "htm": return "HTML Document"
        case "css": return "CSS Stylesheet"
        case "js": return "JavaScript"
        case "json": return "JSON Data"
        case "xml": return "XML Document"
        case "csv": return "CSV Data"
        case "md", "markdown": return "Markdown Document"
        case "pdf": return "PDF Document"
        case "doc": return "Word Document"
        case "docx": return "Word Document (Modern)"
        case "xls": return "Excel Spreadsheet"
        case "xlsx": return "Excel Spreadsheet (Modern)"
        case "ppt": return "PowerPoint Presentation"
        case "pptx": return "PowerPoint (Modern)"
        case "png": return "PNG Image"
        case "jpg", "jpeg": return "JPEG Image"
        case "gif": return "GIF Image"
        case "tif", "tiff": return "TIFF Image"
        case "bmp": return "Bitmap Image"
        case "psd": return "Photoshop Document"
        case "eps": return "Encapsulated PostScript"
        case "svg": return "SVG Vector Image"
        case "pict", "pct": return "QuickDraw Picture"
        case "mov": return "QuickTime Movie"
        case "mp4": return "MPEG-4 Video"
        case "avi": return "AVI Video"
        case "mp3": return "MP3 Audio"
        case "aif", "aiff": return "AIFF Audio"
        case "wav": return "WAV Audio"
        case "flac": return "FLAC Audio"
        case "mid", "midi": return "MIDI Music"
        case "sit": return "StuffIt Archive"
        case "sitx": return "StuffIt X Archive"
        case "cpt": return "Compact Pro Archive"
        case "zip": return "ZIP Archive"
        case "rar": return "RAR Archive"
        case "7z": return "7-Zip Archive"
        case "gz": return "Gzip Compressed"
        case "bz2": return "Bzip2 Compressed"
        case "xz": return "XZ Compressed"
        case "tar": return "Tar Archive"
        case "iso": return "ISO 9660 Disc Image"
        case "dmg": return "macOS Disk Image"
        case "img", "image": return "Disk Image (DiskCopy)"
        case "dsk", "disk": return "Raw Disk Image"
        case "mar": return "DART Disk Archive"
        case "toast": return "Toast Disc Image"
        case "bin": return "MacBinary / Binary"
        case "hqx": return "BinHex 4.0 Encoded"
        case "sea": return "Self-Extracting Archive"
        case "rsrc": return "Resource Fork Data"
        case "c", "h": return "C Source Code"
        case "cpp", "hpp", "cc": return "C++ Source Code"
        case "m": return "Objective-C Source"
        case "swift": return "Swift Source Code"
        case "p", "pas": return "Pascal Source Code"
        case "r", "rez": return "Rez Source (Resources)"
        case "py": return "Python Script"
        case "rb": return "Ruby Script"
        case "sh": return "Shell Script"
        case "java": return "Java Source Code"
        case "ttf": return "TrueType Font"
        case "otf": return "OpenType Font"
        case "dfont": return "Data-Fork Font"
        case "nfo": return "NFO Info File"
        case "md5": return "MD5 Checksum"
        case "log": return "Log File"
        case "plist": return "Property List"
        case "yaml", "yml": return "YAML Configuration"
        case "ini", "cfg": return "Configuration File"
        case "sql": return "SQL Script"
        case "dd": return "DiskDoubler Archive"
        default: return nil
        }
    }

    /// Detailed file type information with historical context.
    static func fileTypeInfoDetailed(entry: VaultEntry) -> FileTypeInfo? {
        // Check type code first — most specific
        if let type = entry.typeCode {
            if let info = typeCodeInfo(type) { return info }
        }
        // Fall back to extension
        let ext = (entry.name as NSString).pathExtension.lowercased()
        if let info = extensionInfo(ext) { return info }
        // Check if it's a resource fork companion
        if entry.name.hasSuffix(".rsrc") {
            return FileTypeInfo(
                name: "Resource Fork Data",
                description: "The resource fork of a classic Mac file, stored separately.",
                history: "Every classic Mac file had two forks: a data fork (main content) and a resource fork (structured data like icons, menus, dialog layouts, sounds, and even executable code). This dual-fork architecture was unique to the Macintosh and was introduced with the original Mac in 1984. When Mac files are transferred to non-Mac systems, the resource fork is often stored as a separate .rsrc file to prevent data loss."
            )
        }
        return nil
    }

    // MARK: - Type Code Knowledge Base

    private static func typeCodeInfo(_ type: String?) -> FileTypeInfo? {
        guard let type else { return nil }
        switch type {
        case "TEXT":
            return FileTypeInfo(name: "Plain Text", description: "A plain text file with no formatting.",
                history: "The most universal file type on the Mac. TEXT files could be opened by virtually every application — from TeachText (bundled free with every Mac) to word processors like WriteNow and Microsoft Word. Classic Mac text used MacRoman encoding, a superset of ASCII with special characters like curly quotes and ligatures.")
        case "ttro":
            return FileTypeInfo(name: "Read-Only Text", description: "A text file that cannot be modified.",
                history: "Created by TeachText and later SimpleText — the simple text editors Apple bundled with every Mac from 1984 to 2003. The 'ttro' type code told the Finder to open it in read-only mode. Apple used this for Read Me files included with system software and applications.")
        case "APPL":
            return FileTypeInfo(name: "Application", description: "A Macintosh application (executable program).",
                history: "Classic Mac applications stored their executable code in the resource fork as CODE resources. The data fork was often empty or contained auxiliary data. This architecture meant that simply copying an application to a non-Mac filesystem would destroy it — the code lived in the resource fork that other systems couldn't see.")
        case "PICT":
            return FileTypeInfo(name: "QuickDraw Picture", description: "Apple's native vector/bitmap image format.",
                history: "PICT was the native graphics format of the Macintosh, based on QuickDraw — the Mac's graphics engine written by Bill Atkinson. PICT files could contain both vector and bitmap data, and were the standard clipboard format for images. Every Mac application that could display graphics used PICT. Apple deprecated PICT with Mac OS X in favor of PDF as the native graphics format.")
        case "PNTG":
            return FileTypeInfo(name: "MacPaint Image", description: "1-bit black & white bitmap, 576×720 pixels.",
                history: "Created by MacPaint, one of the two applications bundled with the original Macintosh in 1984 (the other was MacWrite). MacPaint was written by Bill Atkinson and was revolutionary — it was one of the first consumer bitmap painting programs. The format was limited to 1-bit (black and white) at a fixed resolution matching the original Mac's screen.")
        case "snd ":
            return FileTypeInfo(name: "Sound Resource", description: "A Macintosh sound stored as a resource.",
                history: "The Mac had built-in sound from day one in 1984 — years before PCs got Sound Blaster cards. Sound resources (type 'snd ') were stored in resource forks and used for system alerts, game sounds, and HyperCard stacks. The Sound Manager API supported 8-bit mono/stereo audio at various sample rates.")
        case "MooV", "MOOV":
            return FileTypeInfo(name: "QuickTime Movie", description: "Apple's multimedia container format.",
                history: "QuickTime was announced by Apple in 1991 and was revolutionary — it brought video to personal computers for the first time. The MooV type code (note the playful capitalization) became the standard for multimedia on both Mac and Windows. QuickTime evolved into the basis for the MPEG-4 standard and the .mp4 container format used worldwide today.")
        case "INIT":
            return FileTypeInfo(name: "System Extension", description: "Code that loads at startup to extend Mac OS.",
                history: "System extensions (INITs, named after the 'INIT' resource they contained) loaded during startup — represented by the parade of icons at the bottom of the 'Welcome to Macintosh' screen. They could add features like networking, virus scanning, or screen savers. Extension conflicts were a notorious source of crashes in classic Mac OS, leading users to hold Shift at startup to disable them all.")
        case "cdev":
            return FileTypeInfo(name: "Control Panel", description: "A settings panel accessible from the Apple menu.",
                history: "Control Panels (cdevs — 'control panel devices') appeared in the Control Panels folder and let users configure system settings like mouse speed, sound volume, monitor resolution, and desktop patterns. Third-party cdevs added features like After Dark (the famous flying toasters screensaver) and Kaleidoscope (custom UI themes).")
        case "DRVR":
            return FileTypeInfo(name: "Desk Accessory", description: "A mini-application accessible from the Apple menu.",
                history: "Desk Accessories (DAs) were the Mac's original answer to multitasking — before MultiFinder in 1987, the Mac could only run one application at a time, but DAs like the Calculator, Alarm Clock, and Scrapbook were always available from the Apple menu. They were stored as DRVR resources, a clever hack that treated them as device drivers to get around the single-application limitation.")
        case "FONT", "NFNT":
            return FileTypeInfo(name: "Bitmap Font", description: "A fixed-size screen font stored as a resource.",
                history: "The original Mac shipped with bitmap fonts designed by Susan Kare — Chicago, Geneva, Monaco, New York, and others, all named after world cities. Each size had to be individually designed pixel by pixel. When Apple and Microsoft introduced TrueType in 1991, scalable fonts gradually replaced bitmaps, though bitmap fonts remained important for screen display at small sizes well into the 2000s.")
        case "sfnt":
            return FileTypeInfo(name: "TrueType Font", description: "A scalable outline font.",
                history: "TrueType was developed by Apple in the late 1980s as a competitor to Adobe's PostScript Type 1 fonts, which required expensive licensing. Apple shared the technology with Microsoft, and TrueType became the standard font format for both Mac and Windows. The 'sfnt' type code stands for 'spline font' — referring to the mathematical curves used to describe letter shapes.")
        case "rsrc":
            return FileTypeInfo(name: "Resource File", description: "A file containing only resource fork data.",
                history: "Resource files were used by developers to store compiled resources — icons, dialog layouts, menus, string tables, and more. ResEdit, Apple's free resource editor, was an essential developer tool that let you visually edit these resources. Many Mac users also used ResEdit to customize their system — changing icons, menu text, and even modifying applications.")
        case "ZSYS":
            return FileTypeInfo(name: "System File", description: "The core Mac OS system file.",
                history: "The System file was the heart of classic Mac OS — it contained the operating system's resources including fonts, sounds, keyboard layouts, and core system code. Together with the Finder, it formed the minimum needed to boot a Mac. Users could customize their System file by dragging fonts and sounds into it.")
        case "FNDR":
            return FileTypeInfo(name: "Finder", description: "The Macintosh desktop manager.",
                history: "The Finder has been the face of the Macintosh since 1984 — it provides the desktop, file management, and the iconic trash can. The original Finder was written by Bruce Horn and Steve Capps. The 'FNDR' type code identified the Finder application, while 'MACS' was its creator code (one of Apple's reserved all-lowercase creator codes).")
        case "WDBN":
            return FileTypeInfo(name: "Microsoft Word Document", description: "A document created by Microsoft Word for Mac.",
                history: "Microsoft Word was one of the first third-party applications for the Mac, released in January 1985 — before the Windows version. Word for Mac was actually Microsoft's flagship word processor for years, and many features appeared on Mac first. The 'WDBN' type code was used through Word 5.1 (1992), widely considered the best version of Word ever made.")
        case "SIT!", "SITD":
            return FileTypeInfo(name: "StuffIt Archive", description: "A compressed archive in StuffIt format.",
                history: "StuffIt was created in 1987 by Raymond Lau, a 16-year-old student at Stuyvesant High School in New York City. It became THE standard compression format on the Mac for 14 years, replacing PackIt. StuffIt could preserve both data and resource forks — essential for Mac files. The '!' in 'SIT!' was a playful touch typical of early Mac culture. StuffIt Expander was bundled free with every Mac from the mid-1990s to 2005.")
        case "dImg":
            return FileTypeInfo(name: "DiskCopy Image", description: "An exact copy of a floppy disk.",
                history: "Apple's DiskCopy 4.2 was the standard tool for duplicating floppy disks and creating disk images. The format preserves the complete sector-by-sector layout of a disk, including tag data used by the earliest Macs. DiskCopy images were the primary way software was distributed via BBS systems and early Internet FTP sites before CD-ROMs became common.")
        default:
            return nil
        }
    }


    // MARK: - Extension Knowledge Base

    private static func extensionInfo(_ ext: String) -> FileTypeInfo? {
        switch ext {
        case "sit":
            return FileTypeInfo(name: "StuffIt Archive", description: "Compressed archive preserving Mac file forks.",
                history: "Created by Raymond Lau (age 16) in 1987. Dominated Mac compression for 14 years. StuffIt could preserve both data and resource forks, essential for classic Mac files. Aladdin Systems marketed it commercially while StuffIt Expander remained free.")
        case "sitx":
            return FileTypeInfo(name: "StuffIt X Archive", description: "Modern StuffIt format with advanced compression.",
                history: "Introduced in 2002 with StuffIt Deluxe 7.0. Added PPM and BWT compression, encryption, error correction, and support for long filenames and Unix/Windows attributes.")
        case "cpt":
            return FileTypeInfo(name: "Compact Pro Archive", description: "Archive format competing with StuffIt.",
                history: "Created by Bill Goodman around 1990, originally named 'Compactor' (renamed due to trademark issues). Offered good compression but never seriously threatened StuffIt's dominance. Freeware utilities like cptExpand could decompress these files.")
        case "dd":
            return FileTypeInfo(name: "DiskDoubler Archive", description: "In-place transparent file compression.",
                history: "Created in 1989 by Terry Morse and Lloyd Chambers (Salient Software). Unlike StuffIt, DiskDoubler compressed files 'in place' on the hard drive — they decompressed automatically when opened. Was the second-best-selling Mac product after the After Dark screensaver. Sigma Designs sold a NuBus card for hardware-accelerated compression.")
        case "pit":
            return FileTypeInfo(name: "PackIt Archive", description: "The first widely-used Mac archiver.",
                history: "Created by Harry Chesley in 1986 to distribute code for the online magazine MacDeveloper. PackIt was the first Mac archiver to see widespread use. PackIt III added DES encryption. Completely superseded by StuffIt in late 1987 when Chesley joined Apple.")
        case "sea":
            return FileTypeInfo(name: "Self-Extracting Archive", description: "An application that decompresses itself when run.",
                history: "Self-extracting archives were applications with a built-in decompressor — double-click to extract. This was crucial in the early Mac era when not everyone had StuffIt installed. Both StuffIt and Compact Pro could create SEAs.")
        case "hqx":
            return FileTypeInfo(name: "BinHex 4.0 Encoded", description: "Mac binary file encoded as 7-bit ASCII text.",
                history: "Created by Yves Lempereur in 1985. Essential for early Internet when email could only handle 7-bit ASCII. BinHex preserved both forks and Finder metadata by encoding everything into a text stream. Every Mac file downloaded via email in the late 1980s and 1990s was likely BinHex-encoded. Header: '(This file must be converted with BinHex 4.0)'")
        case "bin":
            return FileTypeInfo(name: "MacBinary", description: "Both forks combined in a single binary stream.",
                history: "Designed in 1985 by Dennis Brothers as a community standard. MacBinary combined the data fork, resource fork, and Finder metadata into one file for safe transfer. Most FTP clients auto-encoded downloads to MacBinary. Three versions: MacBinary I (1985), II (1987, added CRC), III (1996, longer filenames).")
        case "img", "image":
            return FileTypeInfo(name: "Disk Image", description: "An exact copy of a floppy disk or hard drive.",
                history: "Apple's DiskCopy 4.2 (1988) created these images with an 84-byte header containing the disk name, checksums, and encoding type. The format preserved complete sector data including 12-byte tags used by the earliest Macs. DiskCopy images were the standard way to distribute software via BBS and FTP before CD-ROMs.")
        case "dsk":
            return FileTypeInfo(name: "Raw Disk Image", description: "Raw sector dump of a disk with no header.",
                history: "Raw disk images contain the exact bytes from a disk, sector by sector, with no metadata wrapper. Common output from disk imaging tools like dd. These can contain any filesystem — MFS, HFS, HFS+, or even non-Mac formats.")
        case "mar", "dart":
            return FileTypeInfo(name: "DART Archive", description: "Apple's Disk Archive/Retrieval Tool format.",
                history: "DART (Disk Archive/Retrieval Tool) was Apple's internal tool for disk image distribution. It created DiskCopy 4.2-compatible images with optional compression. The .mar extension stands for 'Macintosh ARchive.' DART images were commonly used within Apple for distributing system software updates.")
        case "dmg":
            return FileTypeInfo(name: "macOS Disk Image", description: "Apple's modern disk image format (UDIF).",
                history: "Introduced with Mac OS X in 2001, UDIF (Universal Disk Image Format) replaced NDIF. Supports zlib, bzip2, LZFSE, and lzma compression. The 'koly' magic trailer identifies the format. DMGs are the standard way to distribute macOS software today.")
        case "iso":
            return FileTypeInfo(name: "ISO 9660 Disc Image", description: "Standard CD-ROM filesystem image.",
                history: "ISO 9660 was standardized in 1988 as ECMA-119, defining how files are stored on CD-ROMs. Extensions include Rock Ridge (Unix), Joliet (Windows/Unicode), El Torito (bootable), and Apple ISO 9660 Extensions (type/creator codes). Many Mac CDs were 'hybrid' — containing both ISO 9660 and HFS partitions so they worked on both Mac and PC.")
        case "toast":
            return FileTypeInfo(name: "Toast Disc Image", description: "Roxio Toast burning software format.",
                history: "Toast (originally by Astarte, then Adaptec, then Roxio) was THE CD burning application for the Mac. Toast images could contain HFS, ISO 9660, hybrid, or audio CD layouts. The software was essential in the late 1990s CD-burning era.")
        case "rsrc":
            return FileTypeInfo(name: "Resource Fork Data", description: "Separately stored resource fork.",
                history: "When Mac files are transferred to non-Mac systems, the resource fork — which contains icons, menus, dialog layouts, sounds, and code — must be stored separately to avoid data loss. The .rsrc extension preserves this critical Mac-specific data.")
        case "pict", "pct":
            return FileTypeInfo(name: "QuickDraw Picture", description: "Apple's native graphics format.",
                history: "Based on QuickDraw, the Mac's graphics engine written by Bill Atkinson. PICT could mix vector and bitmap data and was the standard clipboard format. Deprecated with Mac OS X in favor of PDF.")
        case "pntg":
            return FileTypeInfo(name: "MacPaint Image", description: "1-bit bitmap, 576×720 pixels.",
                history: "Created by MacPaint (Bill Atkinson, 1984), bundled with the original Macintosh. One of the first consumer bitmap painting programs. Limited to black and white at a fixed resolution matching the Mac's 512×342 screen.")
        case "mov":
            return FileTypeInfo(name: "QuickTime Movie", description: "Apple's multimedia container.",
                history: "QuickTime (1991) brought video to personal computers. It evolved into the basis for MPEG-4 and the .mp4 format used worldwide. The QuickTime player was available on both Mac and Windows.")
        case "aif", "aiff":
            return FileTypeInfo(name: "AIFF Audio", description: "Audio Interchange File Format — Apple's WAV equivalent.",
                history: "Designed by Apple in 1988, based on Electronic Arts' IFF format. AIFF stores uncompressed audio at CD quality (16-bit, 44.1kHz). It was the standard professional audio format on the Mac and remains important in music production.")
        case "hlp":
            return FileTypeInfo(name: "Help File", description: "Application help documentation.",
                history: "Help files contained the documentation for applications, accessible via the Help menu or Apple Guide. On classic Mac OS, help was often stored in the resource fork as 'STR#' and 'TEXT' resources, or later as Apple Guide files.")
        case "ttf":
            return FileTypeInfo(name: "TrueType Font", description: "Scalable outline font.",
                history: "Developed by Apple in the late 1980s as a royalty-free alternative to Adobe's PostScript Type 1 fonts. Apple shared the technology with Microsoft — it became the standard font format for both platforms. 'sfnt' (spline font) was the Mac type code.")
        case "r", "rez":
            return FileTypeInfo(name: "Rez Source Code", description: "Resource description language source.",
                history: "Rez was Apple's resource compiler language used in MPW (Macintosh Programmer's Workshop). Developers wrote .r files describing resources — menus, dialogs, icons, strings — and compiled them into the resource fork. DeRez did the reverse, decompiling resources back to source code.")
        case "p", "pas":
            return FileTypeInfo(name: "Pascal Source Code", description: "Source code in the Pascal language.",
                history: "Pascal was THE language of the original Macintosh. The Mac Toolbox APIs were defined in Pascal, and Apple's own development tools (MPW Pascal, THINK Pascal by Symantec) were Pascal-based. Object Pascal was used to write MacApp, Apple's application framework.")
        case "c", "h":
            return FileTypeInfo(name: "C Source Code", description: "Source code in the C language.",
                history: "C became increasingly important on the Mac through the late 1980s. THINK C (by THINK Technologies, later Symantec) and MPW C were the main compilers. Metrowerks CodeWarrior (1993) eventually dominated, especially for the PowerPC transition.")
        case "nfo":
            return FileTypeInfo(name: "NFO Info File", description: "Information file from the BBS/warez scene.",
                history: "NFO files originated in the BBS and early Internet scene culture of the 1980s-90s. They typically contain ASCII art and information about software releases. The name comes from 'info' with the vowels rearranged.")
        case "md5":
            return FileTypeInfo(name: "MD5 Checksum", description: "File integrity verification hash.",
                history: "MD5 (Message-Digest Algorithm 5) was developed by Ronald Rivest in 1991. MD5 checksum files were commonly included with software downloads to verify file integrity — you'd compare the computed hash of your download against the published hash to detect corruption or tampering.")
        default:
            return nil
        }
    }

    // MARK: - PICT Conversion

    /// Check if a file is a PICT image that can be converted.
    static func isPICT(entry: VaultEntry) -> Bool {
        if entry.typeCode == "PICT" { return true }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        return ext == "pict" || ext == "pct"
    }

    /// Convert a PICT file to PNG using macOS sips.
    /// Returns the PNG data, or nil if conversion fails.
    static func convertPICTtoPNG(vault: Vault, entry: VaultEntry, sipsPath: String = "/usr/bin/sips") -> Data? {
        guard let data = try? vault.dataFork(for: entry.id) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-convert")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let inputURL = tempDir.appendingPathComponent("input.pict")
        let outputURL = tempDir.appendingPathComponent("output.png")

        do {
            try data.write(to: inputURL)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sipsPath)
            process.arguments = ["-s", "format", "png", inputURL.path, "--out", outputURL.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0,
               FileManager.default.fileExists(atPath: outputURL.path) {
                let pngData = try Data(contentsOf: outputURL)
                try? FileManager.default.removeItem(at: inputURL)
                try? FileManager.default.removeItem(at: outputURL)
                return pngData
            }
        } catch { }

        try? FileManager.default.removeItem(at: inputURL)
        try? FileManager.default.removeItem(at: outputURL)
        return nil
    }

    /// Check if a file can be converted to a modern format.
    static func canConvert(entry: VaultEntry) -> Bool {
        isPICT(entry: entry)
    }

    /// Human-readable target format for conversion.
    static func conversionTarget(entry: VaultEntry) -> String? {
        if isPICT(entry: entry) { return "PNG image" }
        return nil
    }
}
