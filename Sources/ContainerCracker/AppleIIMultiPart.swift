import Foundation

/// Apple II multi-partition format readers (read-only).
/// F3: CFFA (CompactFlash), F4: AmDOS/OzDOS/UniDOS, F5: FocusDrive/MicroDrive,
/// F6: PPM (Pascal ProFile Manager), F7: DOS hybrids.
///
/// Based on CiderPress2 Multi/*.cs (Apache 2.0).

// MARK: - F3: CFFA (CompactFlash for Apple)

/// CFFA storage card: no signature, 32MB partitions at fixed offsets.
/// Detected by probing for ProDOS/HFS at 32MB boundaries.
/// Supports 4, 6, or 8 partitions.
public enum CFFAReader {

    static let BLOCK_SIZE = 512
    static let STD_PARTITION_BLOCKS = 65536  // 32MB = 65536 × 512

    public static func isCFFA(_ data: Data) -> Bool {
        // Must be larger than 32MB to have multiple partitions
        guard data.count > STD_PARTITION_BLOCKS * BLOCK_SIZE else { return false }
        // Check if first 32MB chunk has a ProDOS or HFS filesystem
        let firstChunk = Data(data.prefix(STD_PARTITION_BLOCKS * BLOCK_SIZE))
        let fs = DiskImageParser.detectFilesystem(rawData: firstChunk)
        return fs == .proDOS || fs == .hfs
    }

    public static func extractAll(from rawData: Data) throws -> [(offset: Int, size: Int, filesystem: DiskImageParser.Filesystem)] {
        let totalBlocks = rawData.count / BLOCK_SIZE
        var partitions: [(offset: Int, size: Int, filesystem: DiskImageParser.Filesystem)] = []
        var startBlock = 0
        while startBlock < totalBlocks {
            let blockCount = min(STD_PARTITION_BLOCKS, totalBlocks - startBlock)
            let offset = startBlock * BLOCK_SIZE
            let chunk = Data(rawData[offset..<(offset + blockCount * BLOCK_SIZE)])
            let fs = DiskImageParser.detectFilesystem(rawData: chunk)
            if fs != .unknown {
                partitions.append((offset: offset, size: blockCount * BLOCK_SIZE, filesystem: fs))
            }
            startBlock += blockCount
        }
        return partitions
    }
}

// MARK: - F4: AmDOS / UniDOS / OzDOS (dual-volume 800K disks)

/// AmDOS and UniDOS split an 800K disk into two 400K DOS volumes (side by side).
/// OzDOS interleaves the two volumes (even blocks = vol 1, odd blocks = vol 2).
public enum DualDOSReader {

    static let SECTOR_SIZE = 256
    static let HALF_DISK_400K = 409_600   // 400K = 35 tracks × 16 sectors × 256 bytes
    static let FULL_DISK_800K = 819_200

    public enum Variant { case amDOS, uniDOS, ozDOS }

    public static func isDualDOS(_ data: Data) -> Bool {
        guard data.count == FULL_DISK_800K else { return false }
        // Check if both halves look like DOS 3.3
        let half1 = Data(data.prefix(HALF_DISK_400K))
        let half2 = Data(data.suffix(HALF_DISK_400K))
        return DOSReader.isDOS(half1) && DOSReader.isDOS(half2)
    }

    public static func extractAll(from rawData: Data, variant: Variant = .amDOS) throws -> [ExtractedFile] {
        guard rawData.count == FULL_DISK_800K else {
            throw ContainerError.invalidFormat("Not an 800K disk image")
        }
        var results: [ExtractedFile] = []
        if variant == .ozDOS {
            // Interleaved: even blocks = vol1, odd = vol2
            var vol1 = Data(), vol2 = Data()
            for i in stride(from: 0, to: rawData.count, by: SECTOR_SIZE * 2) {
                vol1.append(rawData[i..<min(i + SECTOR_SIZE, rawData.count)])
                let j = i + SECTOR_SIZE
                if j < rawData.count { vol2.append(rawData[j..<min(j + SECTOR_SIZE, rawData.count)]) }
            }
            let (_, f1) = try DOSReader.extractAll(from: vol1)
            let (_, f2) = try DOSReader.extractAll(from: vol2)
            results.append(contentsOf: f1)
            results.append(contentsOf: f2)
        } else {
            // Side by side
            let (_, f1) = try DOSReader.extractAll(from: Data(rawData.prefix(HALF_DISK_400K)))
            let (_, f2) = try DOSReader.extractAll(from: Data(rawData.suffix(HALF_DISK_400K)))
            results.append(contentsOf: f1)
            results.append(contentsOf: f2)
        }
        return results
    }
}

// MARK: - F5: FocusDrive / MicroDrive (Apple II hard drive partitions)

/// FocusDrive: partition table with "Parsons Engin." signature.
/// MicroDrive: similar format with "Micro Drive" signature.
/// Both store partition entries (start block, count, name).
public enum AppleIIHDReader {

    static let BLOCK_SIZE = 512
    static let FOCUS_SIG = "Parsons Engin."  // FocusDrive signature
    static let MICRO_SIG = "Micro Drive  "   // MicroDrive signature (padded)

    public struct HDPartition {
        public var name: String = ""
        public var startBlock: UInt32 = 0
        public var blockCount: UInt32 = 0
        public var byteOffset: Int { Int(startBlock) * BLOCK_SIZE }
        public var byteLength: Int { Int(blockCount) * BLOCK_SIZE }
    }

    public static func isFocusDrive(_ data: Data) -> Bool {
        guard data.count >= 2 * BLOCK_SIZE else { return false }
        // Signature at block 1 (or block 0 for some variants)
        let sig = String(data: data[BLOCK_SIZE..<(BLOCK_SIZE + 14)], encoding: .ascii) ?? ""
        return sig == FOCUS_SIG
    }

    public static func isMicroDrive(_ data: Data) -> Bool {
        guard data.count >= 2 * BLOCK_SIZE else { return false }
        let sig = String(data: data[BLOCK_SIZE..<(BLOCK_SIZE + 13)], encoding: .ascii) ?? ""
        return sig.hasPrefix("Micro Drive")
    }

    public static func parsePartitions(_ data: Data) -> [HDPartition] {
        let sigOffset = BLOCK_SIZE  // partition table at block 1
        guard sigOffset + BLOCK_SIZE <= data.count else { return [] }
        let partCount = Int(data[sigOffset + 15])  // after signature(14) + unknown(1)
        guard partCount > 0 && partCount <= 8 else { return [] }
        var parts: [HDPartition] = []
        var offset = sigOffset + 32  // skip header
        let totalBlocks = data.count / BLOCK_SIZE
        for _ in 0..<partCount {
            guard offset + 48 <= data.count else { break }
            let start = readLE32(data, at: offset)
            let count = readLE32(data, at: offset + 4)
            let nameData = data[(offset + 16)..<min(offset + 48, data.count)]
            let name = String(data: nameData, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters.union(.whitespaces)) ?? ""
            if start > 0 && Int(start) < totalBlocks {
                parts.append(HDPartition(name: name, startBlock: start,
                    blockCount: min(count, UInt32(totalBlocks) - start)))
            }
            offset += 48
        }
        return parts
    }

    private static func readLE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset+1]) << 8 |
        UInt32(data[offset+2]) << 16 | UInt32(data[offset+3]) << 24
    }
}

// MARK: - F6: PPM (Pascal ProFile Manager)

/// Pascal ProFile Manager: stores Apple Pascal volumes on a ProFile hard drive.
/// Partitions are listed in a directory on the disk.
public enum PPMReader {

    static let BLOCK_SIZE = 512

    public static func isPPM(_ data: Data) -> Bool {
        // PPM is detected by finding Pascal filesystem signatures at various offsets
        // within a ProDOS volume. Very rare format.
        guard data.count >= 4 * BLOCK_SIZE else { return false }
        // Check for Pascal signature at an offset consistent with PPM layout
        // This is a simplified check — real detection requires ProDOS volume analysis
        return false  // TODO: implement full PPM detection when test images are available
    }
}

// MARK: - F7: DOS Hybrids (DOS + ProDOS/Pascal/CP/M on same disk)

/// DOS hybrid disks contain multiple filesystems on a single 140K floppy.
/// e.g. DOS 3.3 + embedded ProDOS volume, DOS + Pascal, DOS + CP/M.
/// CP2 detects these by scanning for filesystem signatures at known offsets.
public enum DOSHybridReader {

    static let SECTOR_SIZE = 256
    static let DISK_140K = 143_360

    public static func isDOSHybrid(_ data: Data) -> Bool {
        guard data.count == DISK_140K else { return false }
        // Check if it's a DOS disk that also contains another filesystem
        guard DOSReader.isDOS(data) else { return false }
        // Check for embedded ProDOS at block 0 (ProDOS boot loader)
        if ProDOSReader.isProDOS(data) { return true }
        // Check for Pascal filesystem
        if PascalReader.isPascal(data) { return true }
        // Check for CP/M
        if CPMReader.isCPM(data) { return true }
        return false
    }

    /// Extract files from all detected filesystems on a hybrid disk.
    public static func extractAll(from rawData: Data) throws -> [ExtractedFile] {
        var results: [ExtractedFile] = []
        // Extract from DOS
        if DOSReader.isDOS(rawData) {
            let (_, files) = try DOSReader.extractAll(from: rawData)
            results.append(contentsOf: files)
        }
        // Also extract from ProDOS if present
        if ProDOSReader.isProDOS(rawData) {
            let (_, files) = try ProDOSReader.extractAll(from: rawData)
            results.append(contentsOf: files)
        }
        // Also extract from Pascal if present
        if PascalReader.isPascal(rawData) {
            let (_, files) = try PascalReader.extractAll(from: rawData)
            results.append(contentsOf: files)
        }
        // Also extract from CP/M if present
        if CPMReader.isCPM(rawData) {
            let files = try CPMReader.extractAll(from: rawData)
            results.append(contentsOf: files)
        }
        return results
    }
}
