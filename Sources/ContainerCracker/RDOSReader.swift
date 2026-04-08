import Foundation

/// Native RDOS filesystem reader (read-only).
/// SSI's custom DOS for Apple II wargames (Questron, Wizard's Crown, etc.)
/// Three variants: RDOS33 (16-sector), RDOS32 (13-sector), RDOS3 (13-on-16).
///
/// Directory on track 1, 32-byte entries, contiguous sector storage.
/// Based on RDOS 2.1 disassembly and CiderPress2 RDOS*.cs.
public enum RDOSReader {

    static let SECTOR_SIZE = 256
    static let ENTRY_SIZE = 32
    static let DIR_TRACK: UInt8 = 1

    // MARK: - Public API

    public static func isRDOS(_ data: Data) -> Bool {
        // Check for RDOS signature in first directory entry
        // First entry name starts with "RDOS" or "SSI" or " >-SSI"
        for spt in [16, 13] {
            let dirOff = Int(DIR_TRACK) * spt * SECTOR_SIZE
            guard dirOff + ENTRY_SIZE <= data.count else { continue }
            var name = [UInt8]()
            for j in 0..<24 { name.append(data[dirOff + j] & 0x7F) }
            let nameStr = String(bytes: name, encoding: .ascii) ?? ""
            if nameStr.contains("RDOS") || nameStr.contains("SSI") { return true }
        }
        return false
    }

    public static func extractAll(from rawData: Data) throws -> [ExtractedFile] {
        guard isRDOS(rawData) else {
            throw ContainerError.invalidFormat("Not an RDOS volume")
        }

        // Detect variant from disk size and content
        let spt: Int
        if rawData.count == 116_480 { spt = 13 }       // RDOS32
        else if rawData.count == 143_360 { spt = 16 }   // RDOS33 or RDOS3
        else { spt = 16 }  // default

        // Determine how many directory sectors to scan
        let dirSectors = spt == 13 ? 11 : 16  // T1 S0-S10 for 13-sector, all of T1 for 16

        var results: [ExtractedFile] = []

        for s in 0..<dirSectors {
            let dirOff = Int(DIR_TRACK) * spt * SECTOR_SIZE + s * SECTOR_SIZE
            let entriesPerSector = SECTOR_SIZE / ENTRY_SIZE  // 8
            for i in 0..<entriesPerSector {
                let eOff = dirOff + i * ENTRY_SIZE
                guard eOff + ENTRY_SIZE <= rawData.count else { break }

                // Filename: 24 bytes high ASCII, space-padded
                let firstByte = rawData[eOff]
                if firstByte == 0x80 || firstByte == 0x00 { continue }  // deleted or empty

                var nameBytes = [UInt8]()
                for j in 0..<24 { nameBytes.append(rawData[eOff + j] & 0x7F) }
                let name = String(bytes: nameBytes, encoding: .ascii)?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                guard !name.isEmpty else { continue }

                // File type at offset 24: 'A'=Applesoft, 'B'=Binary, 'T'=Text, 'S'=???
                let typeByte = rawData[eOff + 0x18] & 0x7F
                let typeStr: String
                switch typeByte {
                case 0x41: typeStr = "A"    // Applesoft
                case 0x42: typeStr = "B"    // Binary
                case 0x54: typeStr = "T"    // Text
                case 0x53: typeStr = "S"    // System/Special
                default:   typeStr = "?"
                }

                let sectorCount = Int(rawData[eOff + 0x19])
                let fileLen = Int(readLE16(rawData, at: eOff + 0x1C))
                let firstSector = Int(readLE16(rawData, at: eOff + 0x1E))

                // Skip the OS/catalog entry (first entry, very large)
                if name.contains("RDOS") || name.contains("SSI") { continue }

                // Read contiguous sectors
                let dataStart = firstSector * SECTOR_SIZE
                let dataSize = sectorCount * SECTOR_SIZE
                let dataEnd = min(dataStart + dataSize, rawData.count)
                guard dataStart >= 0 && dataEnd > dataStart else { continue }

                var fileData = Data(rawData[dataStart..<dataEnd])
                // Trim to actual file length if specified
                if fileLen > 0 && fileLen < fileData.count {
                    fileData = Data(fileData.prefix(fileLen))
                }
                guard !fileData.isEmpty else { continue }

                results.append(ExtractedFile(
                    name: name, dataFork: fileData,
                    typeCode: typeStr, creatorCode: "RDOS"
                ))
            }
        }
        return results
    }

    // MARK: - Helpers

    private static func readLE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }
}
