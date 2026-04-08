import Foundation

/// Native Apple Pascal (UCSD) filesystem reader (read-only).
/// Block-based (512 bytes), directory at block 2, contiguous file storage.
/// No allocation bitmap — files are described by start block + length.
///
/// Based on Apple Pascal 1.3 manual (p.IV-15) and CiderPress2 Pascal*.cs.
public enum PascalReader {

    static let BLOCK_SIZE = 512
    static let DIR_START_BLOCK = 2
    static let ENTRY_SIZE = 26
    static let MAX_DIR_ENTRIES = 77   // standard directory

    // File types
    static let typeNames: [UInt8: String] = [
        0: "VOL", 1: "BAD", 2: "CODE", 3: "TEXT",
        4: "INFO", 5: "DATA", 6: "GRAF", 7: "FOTO", 8: "SEC"
    ]

    // MARK: - Public API

    public static func isPascal(_ data: Data) -> Bool {
        guard data.count >= 6 * BLOCK_SIZE else { return false }
        // Volume header is first entry in directory (block 2)
        let off = DIR_START_BLOCK * BLOCK_SIZE
        let fileType = readLE16(data, at: off + 4)
        guard fileType == 0 else { return false }  // volume header must be type 0
        // Volume name length at offset 6 must be 1-7
        let nameLen = Int(data[off + 6])
        return nameLen >= 1 && nameLen <= 7
    }

    /// Extract all files from a Pascal volume.
    public static func extractAll(from rawData: Data) throws -> (volumeName: String, files: [ExtractedFile]) {
        guard isPascal(rawData) else {
            throw ContainerError.invalidFormat("Not an Apple Pascal volume")
        }

        let dirBase = DIR_START_BLOCK * BLOCK_SIZE

        // Volume header (entry 0)
        let nextBlock = Int(readLE16(rawData, at: dirBase + 2))
        let nameLen = Int(rawData[dirBase + 6])
        let volumeName = String(data: rawData[(dirBase + 7)..<(dirBase + 7 + min(nameLen, 7))],
                                encoding: .ascii) ?? "PASCAL"
        let volBlockCount = Int(readLE16(rawData, at: dirBase + 22))
        let fileCount = Int(readLE16(rawData, at: dirBase + 24))

        // Read full directory
        let dirBlocks = nextBlock - DIR_START_BLOCK
        guard dirBlocks > 0 && dirBlocks <= 20 else {
            throw ContainerError.corruptedData("Invalid Pascal directory size: \(dirBlocks) blocks")
        }

        var results: [ExtractedFile] = []
        let maxEntries = (dirBlocks * BLOCK_SIZE) / ENTRY_SIZE - 1

        for i in 0..<min(fileCount, maxEntries) {
            let off = dirBase + ENTRY_SIZE * (i + 1)  // skip volume header
            guard off + ENTRY_SIZE <= rawData.count else { break }

            let startBlock = Int(readLE16(rawData, at: off))
            let fileNextBlock = Int(readLE16(rawData, at: off + 2))
            let typeVal = readLE16(rawData, at: off + 4) & 0x0F
            let fNameLen = Int(rawData[off + 6])
            guard fNameLen >= 1 && fNameLen <= 15 else { continue }
            guard startBlock > 0 else { continue }

            let fileName = String(data: rawData[(off + 7)..<(off + 7 + fNameLen)],
                                  encoding: .ascii) ?? "FILE\(i)"
            let bytesInLastBlock = Int(readLE16(rawData, at: off + 22))
            let typeName = typeNames[UInt8(typeVal)] ?? "?"

            // File data: startBlock to fileNextBlock - 1 (contiguous)
            let blockCount = fileNextBlock - startBlock
            guard blockCount > 0 else { continue }
            let dataStart = startBlock * BLOCK_SIZE
            let dataEnd = min(fileNextBlock * BLOCK_SIZE, rawData.count)
            guard dataStart < dataEnd && dataStart < rawData.count else { continue }

            var fileData = Data(rawData[dataStart..<dataEnd])
            // Trim last block to actual byte count
            if bytesInLastBlock > 0 && bytesInLastBlock < BLOCK_SIZE && blockCount > 0 {
                let exactLen = (blockCount - 1) * BLOCK_SIZE + bytesInLastBlock
                if exactLen < fileData.count { fileData = Data(fileData.prefix(exactLen)) }
            }

            results.append(ExtractedFile(
                name: fileName, dataFork: fileData,
                typeCode: typeName, creatorCode: "PASC"
            ))
        }
        return (volumeName, results)
    }

    // MARK: - Helpers

    private static func readLE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }
}
