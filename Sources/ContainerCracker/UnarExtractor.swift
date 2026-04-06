import Foundation

/// Extracts files from archives using The Unarchiver's command-line tool (unar).
/// Handles: StuffIt (.sit, .sea), Compact Pro (.cpt), DiskDoubler (.dd),
/// and many other classic Mac archive formats.
public enum UnarExtractor {

    /// Check if unar is available on the system.
    public static func isAvailable() -> Bool {
        unarPath() != nil
    }

    /// Find the unar binary path.
    /// Override path for unar binary. Set by the app's ToolChain.
    public static var overridePath: String?

    public static func unarPath() -> String? {
        if let override = overridePath { return override }
        let candidates = [
            Bundle.main.resourcePath.map { "\($0)/unar" },
            "/opt/homebrew/bin/unar",
            "/usr/local/bin/unar",
            "/usr/bin/unar",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// List contents of an archive without extracting.
    public static func list(archiveURL: URL) throws -> [String] {
        guard let path = unarPath() else {
            throw ContainerError.unsupportedFormat("unar not installed. Run: brew install unar")
        }

        // lsar lists archive contents
        let lsarPath = path.replacingOccurrences(of: "/unar", with: "/lsar")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsarPath)
        process.arguments = [archiveURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        // lsar output: first line is archive name, then one file per line
        let lines = output.components(separatedBy: .newlines)
            .dropFirst() // skip archive name header
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(lines)
    }

    /// Supported archive extensions that unar handles.
    public static let supportedExtensions: Set<String> = [
        // Classic Mac archives
        "sit", "sitx", "sea", "cpt", "dd", "hqx", "bin",
        "pit", "now",
        // Vintage archives
        "arc", "zoo", "lzh", "lha", "arj",
        // Modern archives
        "zip", "rar", "7z", "cab",
        // Tar + compression
        "tar", "gz", "tgz", "bz2", "tbz", "tbz2",
        "xz", "txz", "lzma", "tlz", "zst",
        "Z",  // Unix compress
        // Disk/package formats unar can handle
        "mar", "msi", "nsis", "deb", "rpm",
        "dmg", "iso",
    ]

    /// Compound extensions where the last part alone isn't enough.
    private static let compoundExtensions: Set<String> = [
        "tar.gz", "tar.bz2", "tar.xz", "tar.lzma", "tar.zst",
        "tar.Z", "mar.xz",
    ]

    /// Check if a file extension is an archive unar can handle.
    public static func canHandle(filename: String) -> Bool {
        let lower = filename.lowercased()
        // Check compound extensions first
        for compound in compoundExtensions {
            if lower.hasSuffix(".\(compound)") { return true }
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// Extract an archive to a temp directory, returning extracted files with metadata.
    public static func extract(archiveURL: URL) throws -> [ExtractedFile] {
        guard let path = unarPath() else {
            throw ContainerError.unsupportedFormat("unar not installed. Run: brew install unar")
        }

        // Create temp dir for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-unar-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Run unar with AppleDouble resource fork output
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = [
            "-o", tempDir.path,    // output directory
            "-d",                   // don't create wrapper directory
            "-k", "visible",       // resource forks as ._ AppleDouble files
            "-f",                   // force overwrite
            archiveURL.path
        ]
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw ContainerError.corruptedData("unar failed: \(errMsg)")
        }

        // Scan extracted files
        return try scanExtractedFiles(in: tempDir)
    }

    /// Scan a directory for extracted files, pairing data forks with AppleDouble ._ files.
    private static func scanExtractedFiles(in directory: URL) throws -> [ExtractedFile] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var results: [ExtractedFile] = []

        for url in contents {
            let name = url.lastPathComponent

            // Skip AppleDouble ._ files (handled as companions)
            if name.hasPrefix("._") { continue }

            // Skip directories for now (flatten)
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                // Recurse into subdirectories
                let subFiles = try scanExtractedFiles(in: url)
                results.append(contentsOf: subFiles)
                continue
            }

            let dataFork = try Data(contentsOf: url)

            // Look for companion ._ file (AppleDouble with resource fork + Finder info)
            var rsrcFork = Data()
            var typeCode: String?
            var creatorCode: String?
            var finderFlags: UInt16 = 0

            let adURL = url.deletingLastPathComponent().appendingPathComponent("._\(name)")
            if fm.fileExists(atPath: adURL.path) {
                let adData = try Data(contentsOf: adURL)
                if AppleDoubleParser.canParse(adData) {
                    let parsed = try AppleDoubleParser.parse(adData)
                    rsrcFork = parsed.rsrcFork ?? Data()
                    if let fi = parsed.finderInfo {
                        let tc = AppleDoubleParser.typeCreator(from: fi)
                        typeCode = tc.type
                        creatorCode = tc.creator
                        finderFlags = AppleDoubleParser.finderFlags(from: fi)
                    }
                }
            }

            results.append(ExtractedFile(
                name: name,
                dataFork: dataFork,
                rsrcFork: rsrcFork,
                typeCode: typeCode,
                creatorCode: creatorCode,
                finderFlags: finderFlags
            ))
        }

        return results
    }
}
