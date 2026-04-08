import Foundation

/// Native Gutenberg word processor filesystem reader (read-only).
/// Sectors are doubly-linked lists with 6-byte headers. Directory at T17/S7.
/// Each directory sector: 9-byte volume name + 15 × 16-byte entries.
///
/// Based on reverse engineering by David Schmidt, CiderPress2 Gutenberg*.cs.
public enum GutenbergReader {

    static let SECTOR_SIZE = 256
    static let DIR_TRACK: UInt8 = 17
    static let DIR_SECTOR: UInt8 = 7
    static let DATA_PER_SECTOR = 250  // 256 - 6 bytes linked list header
    static let ENTRIES_PER_SECTOR = 15

    // MARK: - Public API

    public static func isGutenberg(_ data: Data, sectorsPerTrack: Int = 16) -> Bool {
        let dirOff = sectorOffset(track: DIR_TRACK, sector: DIR_SECTOR, spt: sectorsPerTrack)
        guard dirOff + SECTOR_SIZE <= data.count else { return false }
        // Check volume name area (offset +6, 9 bytes high ASCII)
        // And first entry should be "DIR" (the directory itself)
        let entryOff = dirOff + 0x10  // first entry at offset 16
        guard entryOff + 16 <= data.count else { return false }
        let firstChar = data[entryOff] & 0x7F
        return firstChar == 0x44  // 'D' for "DIR"
    }

    public static func extractAll(from rawData: Data, sectorsPerTrack: Int = 16) throws -> [ExtractedFile] {
        let spt = sectorsPerTrack
        guard isGutenberg(rawData, sectorsPerTrack: spt) else {
            throw ContainerError.invalidFormat("Not a Gutenberg volume")
        }

        var results: [ExtractedFile] = []
        var dirTrack = DIR_TRACK
        var dirSector = DIR_SECTOR
        var safety = 0

        // Walk directory sectors (linked list)
        while safety < 50 {
            safety += 1
            let dirOff = sectorOffset(track: dirTrack, sector: dirSector, spt: spt)
            guard dirOff + SECTOR_SIZE <= rawData.count else { break }

            for i in 0..<ENTRIES_PER_SECTOR {
                let eOff = dirOff + 0x10 + i * 16
                guard eOff + 16 <= rawData.count else { break }

                // Filename: 12 bytes high ASCII, space-padded
                var nameBytes = [UInt8]()
                for j in 0..<12 { nameBytes.append(rawData[eOff + j] & 0x7F) }
                let name = String(bytes: nameBytes, encoding: .ascii)?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                guard !name.isEmpty, name != " " else { continue }

                // File type at offset 12: ' '=doc, 'L'=locked doc, 'P'=program, 'M'=program
                let typeByte = rawData[eOff + 12] & 0x7F
                let typeStr = typeByte == 0x50 || typeByte == 0x4D ? "PRG" : "DOC"

                // Track/sector of first file sector at offsets 13-14 (with $40 = 0 encoding)
                var fileTrack = rawData[eOff + 13] & 0x7F
                var fileSector = rawData[eOff + 14] & 0x7F
                if fileTrack == 0x40 { fileTrack = 0 }
                if fileSector == 0x40 { fileSector = 0 }

                // Skip DIR entry itself
                if name == "DIR" { continue }

                // Read file by following linked list
                let fileData = readLinkedFile(rawData, track: fileTrack, sector: fileSector, spt: spt)
                guard !fileData.isEmpty else { continue }

                results.append(ExtractedFile(
                    name: name, dataFork: fileData,
                    typeCode: typeStr, creatorCode: "GTNB"
                ))
            }

            // Follow linked list to next directory sector
            let nextTrack = rawData[dirOff + 4] & 0x7F
            let nextSector = rawData[dirOff + 5] & 0x7F
            // High bit set on track = wraps to start
            if rawData[dirOff + 4] & 0x80 != 0 { break }
            if nextTrack == 0 && nextSector == 0 { break }
            dirTrack = nextTrack
            dirSector = nextSector
        }
        return results
    }

    /// Read file data by following the doubly-linked sector list.
    /// Each sector: [prevT, prevS, curT, curS, nextT, nextS, ...data(250 bytes)...]
    private static func readLinkedFile(_ data: Data, track: UInt8, sector: UInt8, spt: Int) -> Data {
        var result = Data()
        var t = track, s = sector
        var safety = 0
        while safety < 2000 {
            safety += 1
            let off = sectorOffset(track: t, sector: s, spt: spt)
            guard off + SECTOR_SIZE <= data.count else { break }
            result.append(data[(off + 6)..<(off + SECTOR_SIZE)])
            let nextT = data[off + 4]
            let nextS = data[off + 5]
            if nextT & 0x80 != 0 { break }  // high bit = wraps to start = end
            t = nextT & 0x7F; s = nextS & 0x7F
            if t == 0 && s == 0 { break }
        }
        return result
    }

    private static func sectorOffset(track: UInt8, sector: UInt8, spt: Int) -> Int {
        Int(track) * spt * SECTOR_SIZE + Int(sector) * SECTOR_SIZE
    }
}
