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
    /// Uses hfsutils: hmount → hls -R → hcopy → humount
    public static func extract(imageURL: URL,
                               hmountPath: String,
                               hlsPath: String,
                               hcopyPath: String,
                               humountPath: String) throws -> [ExtractedFile] {
        let imagePath = imageURL.path

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
