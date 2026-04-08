import Foundation

/// Native ProDOS filesystem reader (read-only).
/// Reads Apple II floppy and hard disk images with ProDOS/SOS filesystem.
///
/// Storage types: 1=seedling (≤512B), 2=sapling (≤128K), 3=tree (≤16M),
/// 5=extended (GS/OS data+rsrc forks), 0xD=directory.
///
/// Based on _Beneath Apple ProDOS_ and CiderPress2 ProDOS*.cs.
public enum ProDOSReader {

    // MARK: - Constants

    static let BLOCK_SIZE = 512
    static let PRODOS_SIGNATURE: UInt8 = 0xF0   // storage type nibble for volume dir header
    static let ENTRY_SIZE = 39              // standard directory entry size
    static let ENTRIES_PER_BLOCK = 13       // (512 - 4) / 39

    // Storage types (upper nibble of storage_type_and_name_length byte)
    static let ST_DELETED: UInt8 = 0x00
    static let ST_SEEDLING: UInt8 = 0x01    // ≤ 512 bytes
    static let ST_SAPLING: UInt8 = 0x02     // ≤ 128 KB
    static let ST_TREE: UInt8 = 0x03        // ≤ 16 MB
    static let ST_EXTENDED: UInt8 = 0x05    // GS/OS extended (data + rsrc fork)
    static let ST_SUBDIR: UInt8 = 0x0D      // subdirectory
    static let ST_VOLDIR_HDR: UInt8 = 0x0F  // volume directory header

    // MARK: - File Entry

    public struct FileEntry {
        public var storageType: UInt8 = 0
        public var fileName: String = ""
        public var fileType: UInt8 = 0
        public var auxType: UInt16 = 0
        public var keyBlock: UInt16 = 0
        public var blocksUsed: UInt16 = 0
        public var eof: UInt32 = 0          // 3 bytes in ProDOS, up to 16MB
        public var createDate: Date?
        public var modDate: Date?
        public var access: UInt8 = 0xFF
        public var headerPointer: UInt16 = 0 // points to parent directory key block
        public var isDirectory: Bool { storageType == ST_SUBDIR }
        public var isExtended: Bool { storageType == ST_EXTENDED }
    }

    // MARK: - Public API

    /// Check if raw disk data is a ProDOS volume.
    public static func isProDOS(_ data: Data) -> Bool {
        guard data.count >= 6 * BLOCK_SIZE else { return false }
        // Volume directory starts at block 2. First entry has storage type 0xF_
        let offset = 2 * BLOCK_SIZE + 4  // skip prev/next pointers
        let stByte = data[offset]
        return (stByte >> 4) == 0x0F
    }

    /// Extract all files from a ProDOS volume.
    public static func extractAll(from rawData: Data) throws -> (volumeName: String, files: [ExtractedFile]) {
        guard isProDOS(rawData) else {
            throw ContainerError.invalidFormat("Not a ProDOS volume")
        }

        // Parse volume directory header (block 2, entry 0)
        let volDirOffset = 2 * BLOCK_SIZE + 4
        let volNameLen = Int(rawData[volDirOffset]) & 0x0F
        let volumeName = readProDOSName(rawData, at: volDirOffset + 1, length: volNameLen)

        // Recursively read all files
        var results: [ExtractedFile] = []
        readDirectory(rawData, keyBlock: 2, path: "", into: &results)
        return (volumeName, results)
    }

    // MARK: - Directory Reading

    /// Read all entries from a directory starting at keyBlock.
    private static func readDirectory(_ data: Data, keyBlock: UInt16, path: String, into results: inout [ExtractedFile]) {
        var blockNum = keyBlock
        var isFirst = true
        var safety = 0

        while blockNum != 0 && safety < 500 {
            safety += 1
            let blockOffset = Int(blockNum) * BLOCK_SIZE
            guard blockOffset + BLOCK_SIZE <= data.count else { break }

            let nextBlock = readLE16(data, at: blockOffset + 2)
            let startEntry = isFirst ? 1 : 0  // skip header in first block
            isFirst = false

            for i in startEntry..<ENTRIES_PER_BLOCK {
                let entryOffset = blockOffset + 4 + i * ENTRY_SIZE
                guard entryOffset + ENTRY_SIZE <= data.count else { break }

                let stByte = data[entryOffset]
                let storageType = stByte >> 4
                guard storageType != ST_DELETED else { continue }
                guard storageType != ST_VOLDIR_HDR else { continue }
                // Skip subdirectory headers (0x0E)
                guard storageType != 0x0E else { continue }

                let nameLen = Int(stByte & 0x0F)
                guard nameLen > 0 else { continue }

                var entry = FileEntry()
                entry.storageType = storageType
                entry.fileName = readProDOSName(data, at: entryOffset + 1, length: nameLen)
                entry.fileType = data[entryOffset + 16]
                entry.keyBlock = readLE16(data, at: entryOffset + 17)
                entry.blocksUsed = readLE16(data, at: entryOffset + 19)
                entry.eof = UInt32(data[entryOffset + 21])
                       | UInt32(data[entryOffset + 22]) << 8
                       | UInt32(data[entryOffset + 23]) << 16
                entry.createDate = proDOSDateTime(data, at: entryOffset + 24)
                entry.access = data[entryOffset + 30]
                entry.auxType = readLE16(data, at: entryOffset + 31)
                entry.modDate = proDOSDateTime(data, at: entryOffset + 33)
                entry.headerPointer = readLE16(data, at: entryOffset + 37)

                let fullPath = path.isEmpty ? entry.fileName : "\(path)/\(entry.fileName)"

                if entry.isDirectory {
                    // Recurse into subdirectory
                    readDirectory(data, keyBlock: entry.keyBlock, path: fullPath, into: &results)
                } else if entry.isExtended {
                    // GS/OS extended file: data fork + resource fork
                    let (dataFork, rsrcFork, hfsType, hfsCreator) = readExtendedFile(data, keyBlock: entry.keyBlock)
                    results.append(ExtractedFile(
                        name: fullPath,
                        dataFork: dataFork,
                        rsrcFork: rsrcFork,
                        typeCode: hfsType ?? String(format: "$%02X", entry.fileType),
                        creatorCode: hfsCreator ?? String(format: "$%04X", entry.auxType),
                        created: entry.createDate,
                        modified: entry.modDate
                    ))
                } else {
                    // Regular file (seedling/sapling/tree)
                    let fileData = readFileData(data, storageType: entry.storageType,
                                               keyBlock: entry.keyBlock, eof: entry.eof)
                    results.append(ExtractedFile(
                        name: fullPath,
                        dataFork: fileData,
                        typeCode: String(format: "$%02X", entry.fileType),
                        creatorCode: String(format: "$%04X", entry.auxType),
                        created: entry.createDate,
                        modified: entry.modDate
                    ))
                }
            }
            blockNum = nextBlock
        }
    }

    // MARK: - File Data Reading

    /// Read file data based on storage type.
    private static func readFileData(_ data: Data, storageType: UInt8, keyBlock: UInt16, eof: UInt32) -> Data {
        let eofInt = Int(eof)
        guard eofInt > 0 && keyBlock > 0 else { return Data() }

        switch storageType {
        case ST_SEEDLING:
            // Key block IS the data block (up to 512 bytes)
            return readBlock(data, block: keyBlock, maxBytes: eofInt)

        case ST_SAPLING:
            // Key block is an index block (up to 256 block pointers)
            return readSapling(data, indexBlock: keyBlock, eof: eofInt)

        case ST_TREE:
            // Key block is a master index (up to 128 index blocks)
            return readTree(data, masterBlock: keyBlock, eof: eofInt)

        default:
            return Data()
        }
    }

    /// Read a sapling file: index block → data blocks.
    private static func readSapling(_ data: Data, indexBlock: UInt16, eof: Int) -> Data {
        let blockPtrs = readIndexBlock(data, block: indexBlock)
        var result = Data()
        for ptr in blockPtrs {
            guard result.count < eof else { break }
            let remaining = eof - result.count
            if ptr == 0 {
                // Sparse: zero-fill
                result.append(Data(repeating: 0, count: min(BLOCK_SIZE, remaining)))
            } else {
                result.append(readBlock(data, block: ptr, maxBytes: remaining))
            }
        }
        return Data(result.prefix(eof))
    }

    /// Read a tree file: master index → index blocks → data blocks.
    private static func readTree(_ data: Data, masterBlock: UInt16, eof: Int) -> Data {
        let masterPtrs = readIndexBlock(data, block: masterBlock)
        var result = Data()
        for indexPtr in masterPtrs {
            guard result.count < eof else { break }
            if indexPtr == 0 {
                // Sparse: zero-fill 128 blocks (64K)
                let fill = min(256 * BLOCK_SIZE, eof - result.count)
                result.append(Data(repeating: 0, count: fill))
            } else {
                let chunk = readSapling(data, indexBlock: indexPtr, eof: eof - result.count)
                result.append(chunk)
            }
        }
        return Data(result.prefix(eof))
    }

    /// Read a GS/OS extended file (storage type 5).
    /// Key block is an extended info block with data fork and rsrc fork descriptors.
    private static func readExtendedFile(_ data: Data, keyBlock: UInt16) -> (Data, Data, String?, String?) {
        let offset = Int(keyBlock) * BLOCK_SIZE
        guard offset + BLOCK_SIZE <= data.count else { return (Data(), Data(), nil, nil) }

        // Data fork mini-entry at +0
        let dataStorageType = data[offset]
        let dataKeyBlock = readLE16(data, at: offset + 1)
        let dataEof = UInt32(data[offset + 3]) | UInt32(data[offset + 4]) << 8 | UInt32(data[offset + 5]) << 16

        // Resource fork mini-entry at +256
        let rsrcStorageType = data[offset + 256]
        let rsrcKeyBlock = readLE16(data, at: offset + 257)
        let rsrcEof = UInt32(data[offset + 259]) | UInt32(data[offset + 260]) << 8 | UInt32(data[offset + 261]) << 16

        // HFS Finder info at +18 (optional, 32 bytes: type + creator + ...)
        var hfsType: String? = nil
        var hfsCreator: String? = nil
        // Check if there's a Finder info entry (entry type 1 = Finder info at +18)
        if offset + 50 < data.count {
            let finderInfoType = data[offset + 18]
            if finderInfoType == 1 {
                // 4 bytes type + 4 bytes creator at offset +26
                hfsType = String(data: data[(offset + 26)..<(offset + 30)], encoding: .macOSRoman)
                hfsCreator = String(data: data[(offset + 30)..<(offset + 34)], encoding: .macOSRoman)
            }
        }

        let dataFork = readFileData(data, storageType: dataStorageType, keyBlock: dataKeyBlock, eof: dataEof)
        let rsrcFork = readFileData(data, storageType: rsrcStorageType, keyBlock: rsrcKeyBlock, eof: rsrcEof)
        return (dataFork, rsrcFork, hfsType, hfsCreator)
    }

    // MARK: - Helpers

    /// Read an index block: 256 little-endian 16-bit block pointers.
    /// Low bytes at +0..+255, high bytes at +256..+511.
    private static func readIndexBlock(_ data: Data, block: UInt16) -> [UInt16] {
        let offset = Int(block) * BLOCK_SIZE
        guard offset + BLOCK_SIZE <= data.count else { return [] }
        var ptrs = [UInt16]()
        for i in 0..<256 {
            let lo = UInt16(data[offset + i])
            let hi = UInt16(data[offset + 256 + i])
            ptrs.append(lo | (hi << 8))
        }
        return ptrs
    }

    /// Read raw block data, clamped to maxBytes.
    private static func readBlock(_ data: Data, block: UInt16, maxBytes: Int) -> Data {
        let offset = Int(block) * BLOCK_SIZE
        let end = min(offset + min(BLOCK_SIZE, maxBytes), data.count)
        guard offset >= 0 && end > offset else { return Data() }
        return Data(data[offset..<end])
    }

    /// Read a ProDOS filename (ASCII uppercase, up to 15 chars).
    private static func readProDOSName(_ data: Data, at offset: Int, length: Int) -> String {
        guard length > 0 && offset + length <= data.count else { return "" }
        return String(data: data[offset..<(offset + length)], encoding: .ascii) ?? ""
    }

    /// Parse ProDOS date+time (4 bytes: 2 date + 2 time).
    /// Date: bits 15-9=year(0-99), 8-5=month(1-12), 4-0=day(1-31)
    /// Time: bits 12-8=hour(0-23), 5-0=minute(0-59)
    private static func proDOSDateTime(_ data: Data, at offset: Int) -> Date? {
        guard offset + 3 < data.count else { return nil }
        let d = readLE16(data, at: offset)
        let t = readLE16(data, at: offset + 2)
        guard d != 0 else { return nil }
        let year = Int((d >> 9) & 0x7F)
        let month = Int((d >> 5) & 0x0F)
        let day = Int(d & 0x1F)
        let hour = Int((t >> 8) & 0x1F)
        let minute = Int(t & 0x3F)
        let fullYear = year < 40 ? 2000 + year : 1900 + year
        var c = DateComponents()
        c.year = fullYear; c.month = max(1, min(12, month))
        c.day = max(1, min(31, day)); c.hour = min(23, hour); c.minute = min(59, minute)
        return Calendar.current.date(from: c)
    }

    private static func readLE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }
}
