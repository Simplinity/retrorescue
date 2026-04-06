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
        "toast",  // Roxio Toast images (sometimes HFS)
    ]

    public static func canHandle(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// Extract all files from an HFS disk image.
    /// Handles DiskCopy 4.2 format (strips 84-byte header).
    /// Uses hfsutils: hmount → hls -R → hcopy → humount
    public static func extract(imageURL: URL,
                               hmountPath: String,
                               hlsPath: String,
                               hcopyPath: String,
                               humountPath: String) throws -> [ExtractedFile] {

        // Read the image and handle DiskCopy 4.2 format
        let rawData = try Data(contentsOf: imageURL)
        let diskData: Data
        var imagePath = imageURL.path

        if isDiskCopy42(rawData) {
            // Check if it's MFS (not supported by hfsutils)
            let dataOffset = 84
            if rawData.count > dataOffset + 1026 {
                let magic = UInt16(rawData[dataOffset + 1024]) << 8
                         | UInt16(rawData[dataOffset + 1025])
                if magic == 0xD2D7 {
                    throw ContainerError.unsupportedFormat(
                        "This is an MFS (Macintosh File System) volume from the original 128K/512K Mac. MFS support is planned for a future version.")
                }
            }

            // Strip DiskCopy 4.2 header
            let dataSize = Int(rawData[64]) << 24 | Int(rawData[65]) << 16
                         | Int(rawData[66]) << 8  | Int(rawData[67])
            let end = min(84 + dataSize, rawData.count)
            diskData = rawData[84..<end]

            // Write stripped image to temp
            let stripped = FileManager.default.temporaryDirectory
                .appendingPathComponent("retrorescue-hfs-\(UUID().uuidString).raw")
            try diskData.write(to: stripped)
            defer { try? FileManager.default.removeItem(at: stripped) }
            imagePath = stripped.path

            return try extractHFS(imagePath: imagePath,
                                  hmountPath: hmountPath, hlsPath: hlsPath,
                                  hcopyPath: hcopyPath, humountPath: humountPath)
        } else {
            // Try raw HFS directly
            return try extractHFS(imagePath: imagePath,
                                  hmountPath: hmountPath, hlsPath: hlsPath,
                                  hcopyPath: hcopyPath, humountPath: humountPath)
        }
    }

    /// Detect DiskCopy 4.2 format: magic 0x0100 at offset 82-83.
    private static func isDiskCopy42(_ data: Data) -> Bool {
        guard data.count > 84 else { return false }
        return data[82] == 0x01 && data[83] == 0x00
    }

    // MARK: - HFS extraction via hfsutils

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
