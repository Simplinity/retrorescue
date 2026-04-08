import Foundation
import VaultEngine

/// N1 + N3: Vault → Emulator Bridge.
/// Creates HFS disk images from vault contents and sends them to emulators.
public enum EmulatorBridge {

    // MARK: - N1: Create HFS Disk Image

    /// Standard floppy/disk sizes.
    public enum DiskSize: String, CaseIterable {
        case floppy400K = "400K Floppy"
        case floppy800K = "800K Floppy"
        case floppy1440K = "1.4MB Floppy"
        case disk10MB = "10 MB"
        case disk50MB = "50 MB"
        case disk100MB = "100 MB"
        case custom = "Auto (fit contents)"

        public var bytes: Int {
            switch self {
            case .floppy400K: return 409_600
            case .floppy800K: return 819_200
            case .floppy1440K: return 1_474_560
            case .disk10MB: return 10_485_760
            case .disk50MB: return 52_428_800
            case .disk100MB: return 104_857_600
            case .custom: return 0
            }
        }
    }

    /// Create an HFS disk image from vault entries.
    /// Uses hfsutils: hformat (create) + hmount + hcopy (populate) + humount.
    public static func createHFSImage(
        vault: Vault,
        entries: [VaultEntry],
        volumeName: String = "Untitled",
        size: DiskSize = .custom,
        outputURL: URL,
        hformatPath: String,
        hmountPath: String,
        hcopyPath: String,
        humountPath: String,
        progress: ((String, Double) -> Void)? = nil
    ) throws {
        let hformat = hformatPath
        let hmount = hmountPath
        let hcopy = hcopyPath
        let humount = humountPath

        // 1. Calculate image size
        let totalBytes = entries.reduce(0) { $0 + Int($1.dataForkSize) + Int($1.rsrcForkSize) }
        let imageSize: Int
        if size == .custom {
            // Auto-size: content + 30% overhead for HFS directory + allocation bitmap
            let needed = Int(Double(totalBytes) * 1.3) + 32768 // minimum overhead
            // Round up to nearest standard size
            imageSize = [409_600, 819_200, 1_474_560, 10_485_760, 52_428_800, 104_857_600]
                .first { $0 >= needed } ?? max(needed, 819_200)
        } else {
            imageSize = size.bytes
        }

        progress?("Creating \(imageSize / 1024)K disk image…", 0.1)

        // 2. Create raw image file (zero-filled)
        let fm = FileManager.default
        try? fm.removeItem(at: outputURL)
        fm.createFile(atPath: outputURL.path, contents: nil)
        let fh = try FileHandle(forWritingTo: outputURL)
        let zeroBlock = Data(repeating: 0, count: 65536)
        var remaining = imageSize
        while remaining > 0 {
            let chunk = min(remaining, zeroBlock.count)
            fh.write(Data(zeroBlock.prefix(chunk)))
            remaining -= chunk
        }
        fh.closeFile()

        // 3. Format as HFS with hformat
        progress?("Formatting HFS volume '\(volumeName)'…", 0.2)
        let cleanName = String(volumeName.prefix(27))  // HFS max volume name
        try runTool(hformat, args: ["-l", cleanName, outputURL.path])

        // 4. Mount, copy files, unmount
        progress?("Mounting image…", 0.3)
        try runTool(hmount, args: [outputURL.path])

        defer { try? runTool(humount, args: []) }

        let total = Double(entries.count)
        for (i, entry) in entries.enumerated() where !entry.isDirectory {
            progress?("Copying \(entry.name)…", 0.3 + 0.6 * Double(i) / max(1, total))

            // Write data fork to temp file
            let tempDir = fm.temporaryDirectory.appendingPathComponent("retrorescue-hfs")
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempFile = tempDir.appendingPathComponent(entry.name)
            let data = try vault.dataFork(for: entry.id)
            try data.write(to: tempFile)

            // Write resource fork as xattr (hcopy reads it)
            let rsrc = try vault.rsrcFork(for: entry.id)
            if !rsrc.isEmpty {
                try tempFile.withUnsafeFileSystemRepresentation { path in
                    guard let path else { return }
                    rsrc.withUnsafeBytes { buf in
                        _ = setxattr(path, "com.apple.ResourceFork", buf.baseAddress, rsrc.count, 0, 0)
                    }
                }
            }

            // Copy into HFS image with hcopy (macbinary mode preserves forks)
            var hcopyArgs = ["-m", tempFile.path, "::"]
            // Set type/creator if available
            if let tc = entry.typeCode, let cc = entry.creatorCode,
               tc.count == 4, cc.count == 4 {
                hcopyArgs = ["-m", "-t", tc, "-c", cc, tempFile.path, "::"]
            }
            try? runTool(hcopy, args: hcopyArgs)  // best-effort per file
            try? fm.removeItem(at: tempFile)
        }

        progress?("Done — \(entries.count) files on '\(cleanName)'", 1.0)
    }

    // MARK: - N3: Send to Emulator

    /// Known emulator configurations.
    public enum Emulator: String, CaseIterable {
        case sheepShaver = "SheepShaver"
        case basiliskII = "Basilisk II"
        case miniVMac = "Mini vMac"
    }

    /// Send vault files to an emulator.
    /// - SheepShaver/Basilisk II: copies to shared folder as AppleDouble
    /// - Mini vMac: creates a disk image
    public static func sendToEmulator(
        vault: Vault,
        entries: [VaultEntry],
        emulator: Emulator,
        hformatPath: String = "",
        hmountPath: String = "",
        hcopyPath: String = "",
        humountPath: String = "",
        progress: ((String, Double) -> Void)? = nil
    ) throws {
        switch emulator {
        case .sheepShaver, .basiliskII:
            // Export to shared folder as AppleDouble (._prefix companions)
            let sharedFolder = findEmulatorSharedFolder(emulator)
            guard let folder = sharedFolder else {
                throw EmulatorError.noSharedFolder(emulator.rawValue)
            }
            progress?("Exporting to \(emulator.rawValue) shared folder…", 0.2)
            try ConversionEngine.restoreForEmulator(
                vault: vault, outputDir: folder) { msg, frac in
                    progress?(msg, 0.2 + frac * 0.8)
                }

        case .miniVMac:
            // Mini vMac uses .dsk disk images
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let imageURL = desktop.appendingPathComponent("RetroRescue Export.dsk")
            try createHFSImage(vault: vault, entries: entries,
                              volumeName: "RetroRescue", size: .custom,
                              outputURL: imageURL,
                              hformatPath: hformatPath, hmountPath: hmountPath,
                              hcopyPath: hcopyPath, humountPath: humountPath,
                              progress: progress)
        }
    }

    /// Find the shared folder for an emulator.
    private static func findEmulatorSharedFolder(_ emulator: Emulator) -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates: [URL]
        switch emulator {
        case .sheepShaver:
            candidates = [
                home.appendingPathComponent("SheepShaver Shared"),
                home.appendingPathComponent("Documents/SheepShaver"),
                home.appendingPathComponent(".sheepshaver/shared"),
            ]
        case .basiliskII:
            candidates = [
                home.appendingPathComponent("Basilisk II Shared"),
                home.appendingPathComponent("Documents/Basilisk II"),
                home.appendingPathComponent(".basilisk_ii/shared"),
            ]
        case .miniVMac:
            return nil  // Mini vMac uses disk images, not shared folders
        }
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    // MARK: - Tool Runner

    @discardableResult
    private static func runTool(_ path: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw EmulatorError.toolFailed("\(path) failed: \(output)")
        }
        return output
    }
}

// MARK: - Errors

public enum EmulatorError: LocalizedError {
    case missingTools(String)
    case noSharedFolder(String)
    case toolFailed(String)
    case imageTooSmall(String)

    public var errorDescription: String? {
        switch self {
        case .missingTools(let msg): return "Missing tools: \(msg)"
        case .noSharedFolder(let emu): return "Shared folder not found for \(emu). Create one at ~/\(emu) Shared/"
        case .toolFailed(let msg): return msg
        case .imageTooSmall(let msg): return "Image too small: \(msg)"
        }
    }
}
