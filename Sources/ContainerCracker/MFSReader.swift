import Foundation

/// Native MFS (Macintosh File System) reader.
/// Reads original 1984 Mac floppies — the filesystem before HFS.
///
/// MFS is a flat filesystem (no real folders). Folders in the Finder were faked
/// via the Desktop Database. Each file has a data fork + resource fork.
///
/// Based on Inside Macintosh Vol II ch.4 and CiderPress2 MFS*.cs.
public enum MFSReader {

    // MARK: - Constants

    static let MFS_SIGNATURE: UInt16 = 0xD2D7     // high ASCII "RW"
    static let BLOCK_SIZE = 512
    static let VOLUME_INFO_LEN = 64
    static let MAX_VOL_NAME = 27
    static let MAX_FILE_NAME = 255
    static let RESERVED_ALLOC_BLOCKS = 2   // blocks 0 and 1 are reserved
    static let ALLOC_MAP_LEN = 960         // 2 blocks - 64 bytes volume info
    static let MAX_ALLOC_BLOCKS = (ALLOC_MAP_LEN * 2) / 3  // 640 entries

    // MARK: - Volume Info

    public struct VolumeInfo {
        public var signature: UInt16 = 0
        public var createDate: UInt32 = 0
        public var attributes: UInt16 = 0
        public var fileCount: UInt16 = 0
        public var directoryStart: UInt16 = 0       // first block of directory
        public var directoryLength: UInt16 = 0      // directory length in blocks
        public var numAllocBlocks: UInt16 = 0
        public var allocBlockSize: UInt32 = 0       // bytes per alloc block
        public var clumpSize: UInt32 = 0
        public var allocBlockStart: UInt16 = 0      // block number where alloc blocks begin
        public var nextFileNum: UInt32 = 0
        public var freeAllocBlocks: UInt16 = 0
        public var volumeName: String = ""
    }

    // MARK: - File Entry (from directory)

    public struct FileEntry {
        public var flags: UInt8 = 0
        public var version: UInt8 = 0
        public var finderInfo: Data = Data(count: 16) // FInfo: type(4)+creator(4)+flags(2)+loc(4)+folder(2)
        public var fileNumber: UInt32 = 0
        public var dataStartBlock: UInt16 = 0
        public var dataLogicalLen: UInt32 = 0
        public var dataPhysicalLen: UInt32 = 0
        public var rsrcStartBlock: UInt16 = 0
        public var rsrcLogicalLen: UInt32 = 0
        public var rsrcPhysicalLen: UInt32 = 0
        public var createDate: UInt32 = 0
        public var modifyDate: UInt32 = 0
        public var fileName: String = ""

        public var typeCode: String? {
            guard finderInfo.count >= 4 else { return nil }
            return String(data: finderInfo[0..<4], encoding: .macOSRoman)
        }
        public var creatorCode: String? {
            guard finderInfo.count >= 8 else { return nil }
            return String(data: finderInfo[4..<8], encoding: .macOSRoman)
        }
        public var finderFlags: UInt16 {
            guard finderInfo.count >= 10 else { return 0 }
            return UInt16(finderInfo[8]) << 8 | UInt16(finderInfo[9])
        }
        public var isUsed: Bool { flags & 0x80 != 0 }
        public var isLocked: Bool { flags & 0x01 != 0 }
    }

    // MARK: - Public API

    /// Check if raw disk data is an MFS volume.
    public static func isMFS(_ data: Data) -> Bool {
        guard data.count > 1026 else { return false }
        let sig = UInt16(data[1024]) << 8 | UInt16(data[1025])
        return sig == MFS_SIGNATURE
    }

    /// Extract all files from an MFS volume.
    /// - Parameter rawData: Raw disk data (after stripping any disk image header).
    /// - Returns: Array of extracted files with metadata.
    public static func extractAll(from rawData: Data) throws -> (volumeName: String, files: [ExtractedFile]) {
        guard isMFS(rawData) else {
            throw ContainerError.invalidFormat("Not an MFS volume (missing 0xD2D7 signature)")
        }

        // 1. Parse Volume Info (block 2, offset 1024)
        let vol = parseVolumeInfo(rawData)

        // 2. Parse 12-bit Allocation Block Map
        let allocMap = parseAllocMap(rawData)

        // 3. Scan file directory
        let entries = scanDirectory(rawData, vol: vol)

        // 4. Extract each file's data and resource forks
        var results: [ExtractedFile] = []
        for entry in entries {
            let dataFork = extractFork(
                rawData, startBlock: entry.dataStartBlock,
                logicalLen: entry.dataLogicalLen, allocMap: allocMap, vol: vol)
            let rsrcFork = extractFork(
                rawData, startBlock: entry.rsrcStartBlock,
                logicalLen: entry.rsrcLogicalLen, allocMap: allocMap, vol: vol)

            results.append(ExtractedFile(
                name: entry.fileName,
                dataFork: dataFork,
                rsrcFork: rsrcFork,
                typeCode: entry.typeCode,
                creatorCode: entry.creatorCode,
                finderFlags: entry.finderFlags,
                created: macDateToDate(entry.createDate),
                modified: macDateToDate(entry.modifyDate)
            ))
        }
        return (vol.volumeName, results)
    }

    // MARK: - Volume Info Parsing

    private static func parseVolumeInfo(_ data: Data) -> VolumeInfo {
        let base = 1024  // block 2
        var vol = VolumeInfo()
        vol.signature = readBE16(data, at: base)
        vol.createDate = readBE32(data, at: base + 2)
        vol.attributes = readBE16(data, at: base + 10)
        vol.fileCount = readBE16(data, at: base + 12)
        vol.directoryStart = readBE16(data, at: base + 14)
        vol.directoryLength = readBE16(data, at: base + 16)
        vol.numAllocBlocks = readBE16(data, at: base + 18)
        vol.allocBlockSize = readBE32(data, at: base + 20)
        vol.clumpSize = readBE32(data, at: base + 24)
        vol.allocBlockStart = readBE16(data, at: base + 28)
        vol.nextFileNum = readBE32(data, at: base + 30)
        vol.freeAllocBlocks = readBE16(data, at: base + 34)
        // Volume name: Pascal string at offset 36 (length byte + up to 27 chars)
        let nameLen = Int(data[base + 36])
        if nameLen >= 1 && nameLen <= MAX_VOL_NAME && base + 37 + nameLen <= data.count {
            vol.volumeName = String(data: data[(base + 37)..<(base + 37 + nameLen)],
                                    encoding: .macOSRoman) ?? "Untitled"
        }
        return vol
    }

    // MARK: - 12-bit Allocation Block Map

    /// Parse the 12-bit allocation block map from blocks 2-3.
    /// Each entry is 12 bits: 0=free, 1=end-of-chain, 2+=next block.
    /// Stored immediately after the 64-byte volume info.
    private static func parseAllocMap(_ data: Data) -> [UInt16] {
        let base = 1024 + VOLUME_INFO_LEN  // after volume info
        var map = [UInt16](repeating: 0, count: MAX_ALLOC_BLOCKS)

        for i in stride(from: 0, to: MAX_ALLOC_BLOCKS, by: 2) {
            let byteOffset = base + (i / 2) * 3
            guard byteOffset + 2 < data.count else { break }
            let b0 = UInt16(data[byteOffset])
            let b1 = UInt16(data[byteOffset + 1])
            let b2 = UInt16(data[byteOffset + 2])
            map[i]     = (b0 << 4) | (b1 >> 4)
            map[i + 1] = ((b1 & 0x0F) << 8) | b2
        }
        return map
    }

    // MARK: - Directory Scanning

    /// Scan the flat file directory and extract all file entries.
    private static func scanDirectory(_ data: Data, vol: VolumeInfo) -> [FileEntry] {
        var entries: [FileEntry] = []
        let dirStart = Int(vol.directoryStart) * BLOCK_SIZE
        let dirEnd = dirStart + Int(vol.directoryLength) * BLOCK_SIZE

        // Walk through directory blocks
        var blockOffset = dirStart
        while blockOffset < dirEnd && blockOffset < data.count {
            let blockEnd = min(blockOffset + BLOCK_SIZE, data.count)
            var offset = blockOffset

            // Walk entries within this block
            while offset + 51 <= blockEnd {  // minimum entry: 50 bytes + 1 byte filename
                // Check if entry is used (bit 7 of flags)
                guard data[offset] & 0x80 != 0 else { break }  // no more in this block

                var entry = FileEntry()
                entry.flags = data[offset]
                entry.version = data[offset + 1]
                entry.finderInfo = Data(data[(offset + 2)..<(offset + 18)])
                entry.fileNumber = readBE32(data, at: offset + 18)
                entry.dataStartBlock = readBE16(data, at: offset + 22)
                entry.dataLogicalLen = readBE32(data, at: offset + 24)
                entry.dataPhysicalLen = readBE32(data, at: offset + 28)
                entry.rsrcStartBlock = readBE16(data, at: offset + 32)
                entry.rsrcLogicalLen = readBE32(data, at: offset + 34)
                entry.rsrcPhysicalLen = readBE32(data, at: offset + 38)
                entry.createDate = readBE32(data, at: offset + 42)
                entry.modifyDate = readBE32(data, at: offset + 46)

                // Filename (Pascal string at offset 50)
                let nameLen = Int(data[offset + 50])
                let nameStart = offset + 51
                guard nameLen >= 1, nameStart + nameLen <= blockEnd else { break }
                entry.fileName = String(data: data[nameStart..<(nameStart + nameLen)],
                                       encoding: .macOSRoman) ?? "file_\(entry.fileNumber)"

                entries.append(entry)

                // Advance past entry (50 bytes fixed + 1 length byte + name), word-aligned
                offset = nameStart + nameLen
                if offset & 1 != 0 { offset += 1 }  // align to 16-bit boundary
            }

            blockOffset += BLOCK_SIZE
        }
        return entries
    }

    // MARK: - Fork Extraction

    /// Extract a fork by following the allocation block chain.
    /// startBlock is the first alloc block (0 = no data).
    /// The chain: allocMap[block-2] gives next block, 1=end of chain.
    private static func extractFork(
        _ data: Data,
        startBlock: UInt16,
        logicalLen: UInt32,
        allocMap: [UInt16],
        vol: VolumeInfo
    ) -> Data {
        guard startBlock >= RESERVED_ALLOC_BLOCKS && logicalLen > 0 else { return Data() }

        var result = Data()
        var currentBlock = startBlock
        let allocStart = Int(vol.allocBlockStart)
        let blockSize = Int(vol.allocBlockSize)
        var safety = 0

        while currentBlock >= RESERVED_ALLOC_BLOCKS && safety < 10000 {
            safety += 1
            // Convert alloc block number to byte offset
            let byteOffset = (allocStart + Int(currentBlock - UInt16(RESERVED_ALLOC_BLOCKS))
                * Int(vol.allocBlockSize / UInt32(BLOCK_SIZE))) * BLOCK_SIZE
            let end = min(byteOffset + blockSize, data.count)
            guard byteOffset >= 0 && end > byteOffset else { break }
            result.append(data[byteOffset..<end])

            // Follow chain: allocMap index is (block - 2)
            let mapIndex = Int(currentBlock) - RESERVED_ALLOC_BLOCKS
            guard mapIndex >= 0 && mapIndex < allocMap.count else { break }
            let next = allocMap[mapIndex]
            if next == 1 { break }          // end of chain
            if next == 0 { break }          // free block (shouldn't happen)
            currentBlock = next
        }

        // Trim to logical length
        if result.count > Int(logicalLen) {
            return Data(result.prefix(Int(logicalLen)))
        }
        return result
    }

    // MARK: - Helpers

    private static func readBE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 |
        UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
    }

    private static func macDateToDate(_ macSeconds: UInt32) -> Date? {
        guard macSeconds > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(macSeconds) - 2_082_844_800)
    }
}
