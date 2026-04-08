import Foundation

/// Apple Partition Map (APM) parser.
/// Reads multi-partition disk images (CD-ROMs, hard drives) from classic Macintosh.
///
/// Block 0: Driver Descriptor Record (DDR) — signature 'ER' (0x4552)
/// Block 1+: Partition entries — signature 'PM' (0x504D), one per 512-byte block.
///
/// Partition types: Apple_HFS, Apple_MFS, Apple_Driver, Apple_Free, Apple_partition_map, etc.
///
/// Based on Inside Macintosh: Devices ch.3 and CiderPress2 APM.cs (Apache 2.0).
public enum APMParser {

    // MARK: - Constants

    static let BLOCK_SIZE = 512
    static let DDR_SIGNATURE: UInt16 = 0x4552    // 'ER'
    static let PART_SIGNATURE: UInt16 = 0x504D   // 'PM'
    static let MAX_PARTITIONS = 256

    // MARK: - Data Structures

    /// Driver Descriptor Record (block 0).
    public struct DDR {
        public var signature: UInt16 = 0       // must be 0x4552 ('ER')
        public var blockSize: UInt16 = 0       // usually 512
        public var blockCount: UInt32 = 0      // may be unreliable
        public var driverCount: UInt16 = 0
    }

    /// A single partition entry from the partition map.
    public struct PartitionEntry {
        public var signature: UInt16 = 0       // must be 0x504D ('PM')
        public var mapBlockCount: UInt32 = 0   // total entries in partition map
        public var startBlock: UInt32 = 0      // first physical block of partition
        public var blockCount: UInt32 = 0      // number of blocks in partition
        public var name: String = ""           // partition name (up to 32 chars)
        public var type: String = ""           // partition type (e.g. "Apple_HFS")
        public var processor: String = ""      // e.g. "68000", "68020"
        public var dataStart: UInt32 = 0       // first logical block of data area
        public var dataCount: UInt32 = 0       // number of blocks in data area

        /// Byte offset of partition start in disk image.
        public var byteOffset: Int { Int(startBlock) * BLOCK_SIZE }
        /// Byte length of partition.
        public var byteLength: Int { Int(blockCount) * BLOCK_SIZE }

        /// Is this an HFS partition?
        public var isHFS: Bool {
            type.caseInsensitiveCompare("Apple_HFS") == .orderedSame
        }
        /// Is this an MFS partition?
        public var isMFS: Bool {
            type.caseInsensitiveCompare("Apple_MFS") == .orderedSame
        }
        /// Is this a ProDOS partition?
        public var isProDOS: Bool {
            type.caseInsensitiveCompare("Apple_PRODOS") == .orderedSame
        }
        /// Is this a free/unused partition?
        public var isFree: Bool {
            type.caseInsensitiveCompare("Apple_Free") == .orderedSame
                || type.caseInsensitiveCompare("Apple_Scratch") == .orderedSame
        }
        /// Is this the partition map itself?
        public var isPartitionMap: Bool {
            type.caseInsensitiveCompare("Apple_partition_map") == .orderedSame
        }
        /// Is this a driver partition?
        public var isDriver: Bool {
            type.lowercased().hasPrefix("apple_driver")
        }
    }

    // MARK: - Detection

    /// Check if raw disk data contains an Apple Partition Map.
    public static func isAPM(_ data: Data) -> Bool {
        guard data.count >= 2 * BLOCK_SIZE else { return false }
        // Block 0: DDR signature 'ER'
        let ddrSig = readBE16(data, at: 0)
        guard ddrSig == DDR_SIGNATURE else { return false }
        // Block 1: first partition entry signature 'PM'
        let partSig = readBE16(data, at: BLOCK_SIZE)
        return partSig == PART_SIGNATURE
    }

    // MARK: - Parsing

    /// Parse the DDR from block 0.
    public static func parseDDR(_ data: Data) -> DDR {
        var ddr = DDR()
        ddr.signature = readBE16(data, at: 0)
        ddr.blockSize = readBE16(data, at: 2)
        ddr.blockCount = readBE32(data, at: 4)
        ddr.driverCount = readBE16(data, at: 16)
        return ddr
    }

    /// Parse all partition entries from the partition map.
    public static func parsePartitions(_ data: Data) throws -> [PartitionEntry] {
        guard isAPM(data) else {
            throw ContainerError.invalidFormat("Not an Apple Partition Map (missing DDR/PM signature)")
        }

        let totalBlocks = data.count / BLOCK_SIZE
        var partitions: [PartitionEntry] = []
        var blockNum = 1
        var mapBlockCount: UInt32 = 0

        while blockNum < totalBlocks {
            let offset = blockNum * BLOCK_SIZE
            guard offset + BLOCK_SIZE <= data.count else { break }

            let sig = readBE16(data, at: offset)
            guard sig == PART_SIGNATURE else { break }

            var entry = PartitionEntry()
            entry.signature = sig
            entry.mapBlockCount = readBE32(data, at: offset + 4)
            entry.startBlock = readBE32(data, at: offset + 8)
            entry.blockCount = readBE32(data, at: offset + 12)
            entry.name = readString(data, at: offset + 16, maxLen: 32)
            entry.type = readString(data, at: offset + 48, maxLen: 32)
            entry.dataStart = readBE32(data, at: offset + 80)
            entry.dataCount = readBE32(data, at: offset + 84)
            entry.processor = readString(data, at: offset + 120, maxLen: 16)

            // Validate map block count
            if mapBlockCount == 0 {
                mapBlockCount = entry.mapBlockCount
            }
            if entry.mapBlockCount > MAX_PARTITIONS || entry.mapBlockCount > totalBlocks - 1 {
                break  // corrupt map
            }

            // Clamp partition to actual data size (tolerance for oversized partitions)
            if Int(entry.startBlock) + Int(entry.blockCount) > totalBlocks {
                entry.blockCount = UInt32(max(0, totalBlocks - Int(entry.startBlock)))
            }

            partitions.append(entry)
            blockNum += 1

            // Stop after all declared map entries
            if blockNum > Int(mapBlockCount) { break }
        }

        return partitions
    }

    // MARK: - Partition Data Extraction

    /// Extract raw data for a specific partition.
    public static func extractPartitionData(_ data: Data, partition: PartitionEntry) -> Data? {
        let start = partition.byteOffset
        let end = start + partition.byteLength
        guard start >= 0 && end <= data.count && end > start else { return nil }
        return Data(data[start..<end])
    }

    /// Find the first HFS partition and return its raw data.
    public static func findHFSPartition(_ data: Data) -> Data? {
        guard let partitions = try? parsePartitions(data) else { return nil }
        for part in partitions where part.isHFS {
            return extractPartitionData(data, partition: part)
        }
        return nil
    }

    /// Find the first MFS partition and return its raw data.
    public static func findMFSPartition(_ data: Data) -> Data? {
        guard let partitions = try? parsePartitions(data) else { return nil }
        for part in partitions where part.isMFS {
            return extractPartitionData(data, partition: part)
        }
        return nil
    }

    /// Find the best data partition (HFS > MFS > ProDOS) and return its data + filesystem type.
    public static func findBestPartition(_ data: Data) -> (Data, DiskImageParser.Filesystem)? {
        guard let partitions = try? parsePartitions(data) else { return nil }
        // Priority: HFS > MFS > ProDOS
        for part in partitions where part.isHFS {
            if let pData = extractPartitionData(data, partition: part) {
                return (pData, .hfs)
            }
        }
        for part in partitions where part.isMFS {
            if let pData = extractPartitionData(data, partition: part) {
                return (pData, .mfs)
            }
        }
        for part in partitions where part.isProDOS {
            if let pData = extractPartitionData(data, partition: part) {
                return (pData, .proDOS)
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func readBE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 |
        UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
    }

    /// Read a null-terminated string from data (Mac OS Roman).
    private static func readString(_ data: Data, at offset: Int, maxLen: Int) -> String {
        var len = 0
        while len < maxLen && offset + len < data.count && data[offset + len] != 0 {
            len += 1
        }
        guard len > 0 else { return "" }
        return String(data: data[offset..<(offset + len)], encoding: .macOSRoman) ?? ""
    }
}

// MARK: - Mac 'TS' Partition Format (pre-APM)

/// Early Macintosh partition format, pre-dating APM.
/// Block 0: DDR (same as APM, signature 'ER')
/// Block 1: signature 'TS' (0x5453) + list of 12-byte entries (startBlock, blockCount, fsid)
///
/// Used on very early Macintosh hard drives (pre-Mac II, before APM was introduced).
/// Based on CiderPress2 MacTS.cs (Apache 2.0).
public enum MacTSParser {

    static let TS_SIGNATURE: UInt16 = 0x5453  // 'TS'
    static let BLOCK_SIZE = 512

    /// A partition in a TS map.
    public struct TSPartition {
        public var startBlock: UInt32 = 0
        public var blockCount: UInt32 = 0
        public var fsid: String = ""       // 4-char identifier (e.g. "TFS1" for HFS)
        public var byteOffset: Int { Int(startBlock) * BLOCK_SIZE }
        public var byteLength: Int { Int(blockCount) * BLOCK_SIZE }
    }

    /// Check if raw disk data contains a Mac 'TS' partition map.
    public static func isMacTS(_ data: Data) -> Bool {
        guard data.count >= 2 * BLOCK_SIZE else { return false }
        // Block 0: DDR signature 'ER'
        let ddrSig = UInt16(data[0]) << 8 | UInt16(data[1])
        guard ddrSig == APMParser.DDR_SIGNATURE else { return false }
        // Block 1: 'TS' signature (NOT 'PM' — that would be APM)
        let tsSig = UInt16(data[BLOCK_SIZE]) << 8 | UInt16(data[BLOCK_SIZE + 1])
        return tsSig == TS_SIGNATURE
    }

    /// Parse all partitions from a TS map.
    public static func parsePartitions(_ data: Data) throws -> [TSPartition] {
        guard isMacTS(data) else {
            throw ContainerError.invalidFormat("Not a Mac TS partition map")
        }
        let totalBlocks = data.count / BLOCK_SIZE
        var partitions: [TSPartition] = []
        var offset = BLOCK_SIZE + 2  // skip 'TS' signature

        while offset + 12 <= BLOCK_SIZE * 2 {  // entries fit in block 1
            let startBlock = readBE32(data, at: offset)
            let blockCount = readBE32(data, at: offset + 4)
            let fsidRaw = readBE32(data, at: offset + 8)
            offset += 12

            if startBlock == 0 { break }  // end of list
            guard Int(startBlock) < totalBlocks else { continue }

            var part = TSPartition()
            part.startBlock = startBlock
            part.blockCount = min(blockCount, UInt32(totalBlocks) - startBlock)
            // Convert fsid to 4-char string
            part.fsid = String(bytes: [
                UInt8((fsidRaw >> 24) & 0xFF), UInt8((fsidRaw >> 16) & 0xFF),
                UInt8((fsidRaw >> 8) & 0xFF), UInt8(fsidRaw & 0xFF)
            ], encoding: .macOSRoman) ?? "????"
            partitions.append(part)
        }
        return partitions
    }

    /// Find the best data partition and return its raw data.
    public static func findBestPartition(_ data: Data) -> (Data, DiskImageParser.Filesystem)? {
        guard let partitions = try? parsePartitions(data) else { return nil }
        for part in partitions {
            let start = part.byteOffset
            let end = min(start + part.byteLength, data.count)
            guard end > start else { continue }
            let partData = Data(data[start..<end])
            let fs = DiskImageParser.detectFilesystem(rawData: partData)
            if fs == .hfs || fs == .mfs { return (partData, fs) }
        }
        // Fall back to first partition
        if let first = partitions.first {
            let start = first.byteOffset
            let end = min(start + first.byteLength, data.count)
            guard end > start else { return nil }
            return (Data(data[start..<end]), .unknown)
        }
        return nil
    }

    private static func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 |
        UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
    }
}
