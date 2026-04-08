import Foundation
import VaultEngine

/// Extracts files from HFS disk images using hfsutils (hmount/hls/hcopy).
/// For development: uses homebrew hfsutils.
/// For release: will be rewritten in native Swift.
public enum HFSExtractor {

    /// File extensions we recognize as HFS disk images.
    public static let supportedExtensions: Set<String> = [
        "img", "image", "dsk", "disk",
        "hfs", "hfv",
        "dart",         // DART alternate extension
        "2mg", "2img",  // 2IMG (Apple II Universal Disk Image)
        "po",           // ProDOS-order block image
        "do",           // DOS-order block image
    ]

    public static func canHandle(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// An item found inside an HFS disk image (for selective import).
    public struct HFSItem: Identifiable, Hashable {
        public let id: String       // HFS colon-separated path
        public let name: String     // filename only
        public let path: String     // full HFS path e.g. ":System Folder:Finder"
        public let isDirectory: Bool

        public init(name: String, path: String, isDirectory: Bool) {
            self.id = path
            self.name = name
            self.path = path
            self.isDirectory = isDirectory
        }
    }

    /// List the contents of an HFS disk image without extracting.
    /// Returns a flat list of all items (files and directories).
    public static func listContents(imageURL: URL,
                                    hmountPath: String,
                                    hlsPath: String,
                                    humountPath: String) throws -> (items: [HFSItem], volumeName: String?) {
        let (rawData, info) = try DiskImageParser.extractRawData(from: imageURL)

        // MFS volumes: list via native MFSReader
        if info.filesystem == .mfs {
            let (volName, files) = try MFSReader.extractAll(from: rawData)
            let items = files.map { HFSItem(name: $0.name, path: $0.name, isDirectory: false) }
            return (items, volName)
        }

        // ProDOS volumes: list via native ProDOSReader
        if info.filesystem == .proDOS {
            let (volName, files) = try ProDOSReader.extractAll(from: rawData)
            let items = files.map { HFSItem(name: $0.name, path: $0.name, isDirectory: false) }
            return (items, volName)
        }

        // DOS 3.x volumes: list via native DOSReader
        if info.filesystem == .dos33 {
            let spt = rawData.count == 116_480 ? 13 : 16  // 13-sector = DOS 3.2
            let (volNum, files) = try DOSReader.extractAll(from: rawData, sectorsPerTrack: spt)
            let items = files.map { HFSItem(name: $0.name, path: $0.name, isDirectory: false) }
            return (items, "DOS VOL \(volNum)")
        }

        // CP/M volumes: list via native CPMReader
        if info.filesystem == .cpm {
            let files = try CPMReader.extractAll(from: rawData)
            let items = files.map { HFSItem(name: $0.name, path: $0.name, isDirectory: false) }
            return (items, "CP/M")
        }

        // Apple Pascal volumes
        if info.filesystem == .pascal {
            let (volName, files) = try PascalReader.extractAll(from: rawData)
            let items = files.map { HFSItem(name: $0.name, path: $0.name, isDirectory: false) }
            return (items, volName)
        }

        // Gutenberg WP volumes
        if info.filesystem == .gutenberg {
            let files = try GutenbergReader.extractAll(from: rawData)
            let items = files.map { HFSItem(name: $0.name, path: $0.name, isDirectory: false) }
            return (items, "Gutenberg")
        }

        // RDOS (SSI games) volumes
        if info.filesystem == .rdos {
            let files = try RDOSReader.extractAll(from: rawData)
            let items = files.map { HFSItem(name: $0.name, path: $0.name, isDirectory: false) }
            return (items, "RDOS")
        }

        guard info.filesystem == .hfs else {
            throw ContainerError.unsupportedFormat(
                "This \(info.format.rawValue) contains a \(info.filesystem.rawValue) filesystem.")
        }

        let rawFile = try DiskImageParser.writeRawTemp(rawData)
        defer { try? FileManager.default.removeItem(at: rawFile) }

        // Mount
        let mount = Process()
        mount.executableURL = URL(fileURLWithPath: hmountPath)
        mount.arguments = [rawFile.path]
        mount.standardOutput = FileHandle.nullDevice
        mount.standardError = FileHandle.nullDevice
        try mount.run()
        mount.waitUntilExit()
        guard mount.terminationStatus == 0 else {
            throw ContainerError.unsupportedFormat("Could not read this disk image.")
        }

        defer {
            let umount = Process()
            umount.executableURL = URL(fileURLWithPath: humountPath)
            umount.standardOutput = FileHandle.nullDevice
            umount.standardError = FileHandle.nullDevice
            try? umount.run()
            umount.waitUntilExit()
        }

        // List with -R -1 for files, -R -d -1 for directories
        let ls = Process()
        ls.executableURL = URL(fileURLWithPath: hlsPath)
        ls.arguments = ["-R", "-1"]
        let lsPipe = Pipe()
        ls.standardOutput = lsPipe
        ls.standardError = FileHandle.nullDevice
        try ls.run()
        ls.waitUntilExit()

        let lsOutput = String(data: lsPipe.fileHandleForReading.readDataToEndOfFile(),
                              encoding: .macOSRoman) ?? ""

        var items: [HFSItem] = []
        var dirs: Set<String> = []
        var currentDir = ""

        for line in lsOutput.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasSuffix(":") {
                currentDir = String(trimmed.dropLast())
                if !currentDir.hasPrefix(":") { currentDir = ":\(currentDir)" }
                if !dirs.contains(currentDir) {
                    dirs.insert(currentDir)
                    let dirName = (currentDir as NSString).lastPathComponent
                    items.append(HFSItem(name: dirName, path: currentDir, isDirectory: true))
                }
            } else {
                let fullPath = currentDir.isEmpty ? ":\(trimmed)" : "\(currentDir):\(trimmed)"
                items.append(HFSItem(name: String(trimmed), path: fullPath, isDirectory: false))
            }
        }

        return (items, info.diskName)
    }

    /// Extract only selected files from an HFS disk image.
    public static func extractSelected(imageURL: URL,
                                       selectedPaths: [String],
                                       hmountPath: String,
                                       hlsPath: String,
                                       hcopyPath: String,
                                       humountPath: String) throws -> [ExtractedFile] {
        let (rawData, info) = try DiskImageParser.extractRawData(from: imageURL)

        // MFS volumes: extract selected via native MFSReader
        if info.filesystem == .mfs {
            let (_, files) = try MFSReader.extractAll(from: rawData)
            let selectedSet = Set(selectedPaths)
            return files.filter { selectedSet.contains($0.name) }
        }

        // ProDOS volumes: extract selected via native ProDOSReader
        if info.filesystem == .proDOS {
            let (_, files) = try ProDOSReader.extractAll(from: rawData)
            let selectedSet = Set(selectedPaths)
            return files.filter { selectedSet.contains($0.name) }
        }

        // DOS 3.x volumes: extract selected via native DOSReader
        if info.filesystem == .dos33 {
            let spt = rawData.count == 116_480 ? 13 : 16
            let (_, files) = try DOSReader.extractAll(from: rawData, sectorsPerTrack: spt)
            let selectedSet = Set(selectedPaths)
            return files.filter { selectedSet.contains($0.name) }
        }

        // CP/M volumes: extract selected via native CPMReader
        if info.filesystem == .cpm {
            let files = try CPMReader.extractAll(from: rawData)
            let selectedSet = Set(selectedPaths)
            return files.filter { selectedSet.contains($0.name) }
        }

        // Apple Pascal
        if info.filesystem == .pascal {
            let (_, files) = try PascalReader.extractAll(from: rawData)
            let selectedSet = Set(selectedPaths)
            return files.filter { selectedSet.contains($0.name) }
        }

        // Gutenberg
        if info.filesystem == .gutenberg {
            let files = try GutenbergReader.extractAll(from: rawData)
            let selectedSet = Set(selectedPaths)
            return files.filter { selectedSet.contains($0.name) }
        }

        // RDOS
        if info.filesystem == .rdos {
            let files = try RDOSReader.extractAll(from: rawData)
            let selectedSet = Set(selectedPaths)
            return files.filter { selectedSet.contains($0.name) }
        }

        guard info.filesystem == .hfs else {
            throw ContainerError.unsupportedFormat("Not an HFS or MFS volume.")
        }
        let rawFile = try DiskImageParser.writeRawTemp(rawData)
        defer { try? FileManager.default.removeItem(at: rawFile) }

        return try extractHFSPaths(imagePath: rawFile.path,
                                   paths: selectedPaths,
                                   hmountPath: hmountPath, hlsPath: hlsPath,
                                   hcopyPath: hcopyPath, humountPath: humountPath)
    }

    /// Extract all files from a disk image.
    /// Supports DiskCopy 4.2, NDIF, UDIF, and raw HFS images.
    public static func extract(imageURL: URL,
                               hmountPath: String,
                               hlsPath: String,
                               hcopyPath: String,
                               humountPath: String) throws -> [ExtractedFile] {

        // Parse the disk image and get raw HFS data
        let (rawData, info) = try DiskImageParser.extractRawData(from: imageURL)

        // MFS volumes: use native MFSReader (no hfsutils needed)
        if info.filesystem == .mfs {
            let (_, files) = try MFSReader.extractAll(from: rawData)
            return files
        }

        // ProDOS volumes: use native ProDOSReader
        if info.filesystem == .proDOS {
            let (_, files) = try ProDOSReader.extractAll(from: rawData)
            return files
        }

        // DOS 3.x volumes: use native DOSReader
        if info.filesystem == .dos33 {
            let spt = rawData.count == 116_480 ? 13 : 16
            let (_, files) = try DOSReader.extractAll(from: rawData, sectorsPerTrack: spt)
            return files
        }

        // CP/M volumes: use native CPMReader
        if info.filesystem == .cpm {
            return try CPMReader.extractAll(from: rawData)
        }

        // Apple Pascal
        if info.filesystem == .pascal {
            let (_, files) = try PascalReader.extractAll(from: rawData)
            return files
        }

        // Gutenberg
        if info.filesystem == .gutenberg {
            return try GutenbergReader.extractAll(from: rawData)
        }

        // RDOS
        if info.filesystem == .rdos {
            return try RDOSReader.extractAll(from: rawData)
        }

        guard info.filesystem == .hfs else {
            throw ContainerError.unsupportedFormat(
                "This \(info.format.rawValue) contains a \(info.filesystem.rawValue) filesystem. "
                + "Only HFS, MFS, and ProDOS volumes are currently supported.")
        }

        // Write raw data to temp file for hfsutils
        let rawFile = try DiskImageParser.writeRawTemp(rawData)
        defer { try? FileManager.default.removeItem(at: rawFile) }

        return try extractHFS(imagePath: rawFile.path,
                              hmountPath: hmountPath, hlsPath: hlsPath,
                              hcopyPath: hcopyPath, humountPath: humountPath)
    }

    /// Detect DiskCopy 4.2 format: magic 0x0100 at offset 82-83.
    private static func isDiskCopy42(_ data: Data) -> Bool {
        guard data.count > 84 else { return false }
        return data[82] == 0x01 && data[83] == 0x00
    }

    // MARK: - HFS extraction via hfsutils

    /// Extract specific paths from a mounted HFS image.
    private static func extractHFSPaths(imagePath: String,
                                        paths: [String],
                                        hmountPath: String,
                                        hlsPath: String,
                                        hcopyPath: String,
                                        humountPath: String) throws -> [ExtractedFile] {
        let mount = Process()
        mount.executableURL = URL(fileURLWithPath: hmountPath)
        mount.arguments = [imagePath]
        mount.standardOutput = FileHandle.nullDevice
        mount.standardError = Pipe()
        try mount.run()
        mount.waitUntilExit()
        guard mount.terminationStatus == 0 else {
            let errData = (mount.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
            let errMsg = errData.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
            throw ContainerError.unsupportedFormat("hmount failed: \(errMsg)")
        }
        defer {
            let umount = Process()
            umount.executableURL = URL(fileURLWithPath: humountPath)
            umount.standardOutput = FileHandle.nullDevice
            umount.standardError = FileHandle.nullDevice
            try? umount.run()
            umount.waitUntilExit()
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-hfs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var results: [ExtractedFile] = []
        for hfsPath in paths {
            let safeName = hfsPath.replacingOccurrences(of: ":", with: "_")
            let destPath = tempDir.appendingPathComponent(safeName).path
            let cp = Process()
            cp.executableURL = URL(fileURLWithPath: hcopyPath)
            cp.arguments = ["-m", hfsPath, destPath]
            cp.standardOutput = FileHandle.nullDevice
            cp.standardError = FileHandle.nullDevice
            try cp.run()
            cp.waitUntilExit()
            guard cp.terminationStatus == 0 else { continue }

            let macBinData = try Data(contentsOf: URL(fileURLWithPath: destPath))
            if let parsed = try? MacBinaryParser.parse(macBinData) {
                results.append(parsed)
            } else {
                let name = (hfsPath as NSString).lastPathComponent
                results.append(ExtractedFile(name: name, dataFork: macBinData, rsrcFork: Data()))
            }
        }
        return results
    }

    private static func extractHFS(imagePath: String,
                                   hmountPath: String,
                                   hlsPath: String,
                                   hcopyPath: String,
                                   humountPath: String) throws -> [ExtractedFile] {
        // Mount the HFS image
        let mount = Process()
        mount.executableURL = URL(fileURLWithPath: hmountPath)
        mount.arguments = [imagePath]
        mount.standardOutput = FileHandle.nullDevice
        mount.standardError = Pipe()
        try mount.run()
        mount.waitUntilExit()

        guard mount.terminationStatus == 0 else {
            let errData = (mount.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
            let errMsg = errData.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown error"
            throw ContainerError.unsupportedFormat("hmount failed: \(errMsg)")
        }

        // Always unmount when done
        defer {
            let umount = Process()
            umount.executableURL = URL(fileURLWithPath: humountPath)
            umount.standardOutput = FileHandle.nullDevice
            umount.standardError = FileHandle.nullDevice
            try? umount.run()
            umount.waitUntilExit()
        }

        // List all files recursively
        let ls = Process()
        ls.executableURL = URL(fileURLWithPath: hlsPath)
        ls.arguments = ["-R", "-1"]
        let lsPipe = Pipe()
        ls.standardOutput = lsPipe
        ls.standardError = FileHandle.nullDevice
        try ls.run()
        ls.waitUntilExit()

        let lsOutput = String(data: lsPipe.fileHandleForReading.readDataToEndOfFile(),
                              encoding: .macOSRoman) ?? ""
        let filePaths = parseHLSOutput(lsOutput)

        // Create temp dir for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-hfs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Copy each file out using MacBinary mode (preserves type/creator/rsrc)
        var results: [ExtractedFile] = []
        for hfsPath in filePaths {
            let safeName = hfsPath.replacingOccurrences(of: ":", with: "_")
            let destPath = tempDir.appendingPathComponent(safeName).path

            let cp = Process()
            cp.executableURL = URL(fileURLWithPath: hcopyPath)
            cp.arguments = ["-m", hfsPath, destPath]  // -m = MacBinary
            cp.standardOutput = FileHandle.nullDevice
            cp.standardError = FileHandle.nullDevice
            try cp.run()
            cp.waitUntilExit()

            guard cp.terminationStatus == 0 else { continue }

            // hcopy -m produces MacBinary files — parse them
            let macBinData = try Data(contentsOf: URL(fileURLWithPath: destPath))
            if let parsed = try? MacBinaryParser.parse(macBinData) {
                results.append(parsed)
            } else {
                // Fallback: raw data, use filename for name
                let name = (hfsPath as NSString).lastPathComponent
                results.append(ExtractedFile(
                    name: name,
                    dataFork: macBinData,
                    rsrcFork: Data()
                ))
            }
        }

        return results
    }

    /// Parse `hls -R -1` output into a list of full HFS paths.
    /// hls -R outputs directory names followed by ":" then filenames.
    private static func parseHLSOutput(_ output: String) -> [String] {
        var currentDir = ""
        var paths: [String] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasSuffix(":") {
                // Directory header
                currentDir = String(trimmed.dropLast())
                if !currentDir.hasPrefix(":") { currentDir = ":\(currentDir)" }
            } else {
                // File entry
                let fullPath = currentDir.isEmpty ? ":\(trimmed)" : "\(currentDir):\(trimmed)"
                paths.append(fullPath)
            }
        }
        return paths
    }
}
