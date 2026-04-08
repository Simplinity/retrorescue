import Foundation

/// Native Apple II DOS 3.2/3.3 filesystem reader (read-only).
/// Reads 5.25" floppy disk images with Apple's original Disk Operating System.
///
/// DOS 3.2: 13 sectors/track (113K). DOS 3.3: 16 sectors/track (140K).
/// VTOC at Track 17, Sector 0. Catalog as linked T/S list.
///
/// Based on _Beneath Apple DOS_ and CiderPress2 DOS*.cs.
public enum DOSReader {

    // MARK: - Constants

    static let SECTOR_SIZE = 256
    static let VTOC_TRACK: UInt8 = 17
    static let VTOC_SECTOR: UInt8 = 0
    static let ENTRY_SIZE = 35
    static let ENTRIES_PER_SECTOR = 7
    static let CATALOG_START_OFFSET = 0x0B  // first entry in catalog sector

    // File type codes (bits 0-6 of type byte)
    static let fileTypeNames: [UInt8: String] = [
        0x00: "T",   // Text
        0x01: "I",   // Integer BASIC
        0x02: "A",   // Applesoft BASIC
        0x04: "B",   // Binary
        0x08: "S",   // S type
        0x10: "R",   // Relocatable
        0x20: "a",   // A type
        0x40: "b",   // B type
    ]

    // MARK: - Public API

    /// Check if raw disk data is a DOS 3.x volume.
    public static func isDOS(_ data: Data, sectorsPerTrack: Int = 16) -> Bool {
        let vtocOffset = sectorOffset(track: VTOC_TRACK, sector: VTOC_SECTOR, spt: sectorsPerTrack)
        guard vtocOffset + SECTOR_SIZE <= data.count else { return false }
        // First catalog track/sector must be valid
        let catTrack = data[vtocOffset + 1]
        let catSector = data[vtocOffset + 2]
        guard catTrack > 0 && catTrack < 50 else { return false }
        guard catSector < 32 else { return false }
        // Number of tracks and sectors must be reasonable
        let numTracks = data[vtocOffset + 0x34]
        let numSectors = data[vtocOffset + 0x35]
        guard numTracks >= 17 && numTracks <= 80 else { return false }
        guard numSectors == 13 || numSectors == 16 || numSectors == 32 else { return false }
        return true
    }

    /// Extract all files from a DOS 3.x volume.
    public static func extractAll(from rawData: Data, sectorsPerTrack: Int = 16) throws -> (volumeNum: Int, files: [ExtractedFile]) {
        let spt = sectorsPerTrack
        guard isDOS(rawData, sectorsPerTrack: spt) else {
            throw ContainerError.invalidFormat("Not a DOS 3.x volume")
        }

        let vtocOff = sectorOffset(track: VTOC_TRACK, sector: VTOC_SECTOR, spt: spt)
        let volumeNum = Int(rawData[vtocOff + 0x06])
        let firstCatTrack = rawData[vtocOff + 1]
        let firstCatSector = rawData[vtocOff + 2]

        // Walk the catalog chain
        var results: [ExtractedFile] = []
        var catTrack = firstCatTrack
        var catSector = firstCatSector
        var safety = 0

        while catTrack != 0 && safety < 100 {
            safety += 1
            let catOff = sectorOffset(track: catTrack, sector: catSector, spt: spt)
            guard catOff + SECTOR_SIZE <= rawData.count else { break }

            // Next catalog sector
            let nextTrack = rawData[catOff + 1]
            let nextSector = rawData[catOff + 2]

            // Parse 7 file entries per catalog sector
            for i in 0..<ENTRIES_PER_SECTOR {
                let entryOff = catOff + CATALOG_START_OFFSET + i * ENTRY_SIZE
                guard entryOff + ENTRY_SIZE <= rawData.count else { break }

                let tslTrack = rawData[entryOff]
                let tslSector = rawData[entryOff + 1]
                // T=0 means unused entry (end of catalog on well-formed disks)
                if tslTrack == 0 { continue }
                // T=0xFF means deleted entry
                if tslTrack == 0xFF { continue }

                let typeByte = rawData[entryOff + 2]
                let isLocked = (typeByte & 0x80) != 0
                let fileType = typeByte & 0x7F
                let typeName = fileTypeNames[fileType] ?? "?"

                // Filename: 30 bytes of high ASCII, space-padded
                var nameBytes = [UInt8]()
                for j in 0..<30 {
                    nameBytes.append(rawData[entryOff + 3 + j] & 0x7F) // strip high bit
                }
                let rawName = String(bytes: nameBytes, encoding: .ascii) ?? ""
                let fileName = rawName.trimmingCharacters(in: .whitespaces)
                guard !fileName.isEmpty else { continue }

                // Read file data by following T/S list chain
                let fileData = readFileData(rawData, tslTrack: tslTrack, tslSector: tslSector, spt: spt)

                results.append(ExtractedFile(
                    name: fileName,
                    dataFork: fileData,
                    typeCode: typeName,
                    creatorCode: isLocked ? "LOCK" : "DOS\(spt == 13 ? "32" : "33")"
                ))
            }

            catTrack = nextTrack
            catSector = nextSector
        }

        return (volumeNum, results)
    }

    // MARK: - File Data Reading

    /// Read file data by following the Track/Sector list chain.
    /// Each T/S list sector has: +$01/+$02 = next T/S list, +$0C = pairs of T/S for data sectors.
    private static func readFileData(_ data: Data, tslTrack: UInt8, tslSector: UInt8, spt: Int) -> Data {
        var result = Data()
        var track = tslTrack
        var sector = tslSector
        var safety = 0

        while track != 0 && safety < 500 {
            safety += 1
            let tslOff = sectorOffset(track: track, sector: sector, spt: spt)
            guard tslOff + SECTOR_SIZE <= data.count else { break }

            // Next T/S list sector
            let nextTrack = data[tslOff + 1]
            let nextSector = data[tslOff + 2]

            // Data sector pairs start at offset $0C, up to 122 pairs
            for i in 0..<122 {
                let pairOff = tslOff + 0x0C + i * 2
                guard pairOff + 1 < data.count else { break }
                let dTrack = data[pairOff]
                let dSector = data[pairOff + 1]
                if dTrack == 0 && dSector == 0 { continue } // sparse/end
                let dataOff = sectorOffset(track: dTrack, sector: dSector, spt: spt)
                let end = min(dataOff + SECTOR_SIZE, data.count)
                guard dataOff >= 0 && end > dataOff else { continue }
                result.append(data[dataOff..<end])
            }

            track = nextTrack
            sector = nextSector
        }
        return result
    }

    // MARK: - Helpers

    /// Calculate byte offset for a given track and sector.
    private static func sectorOffset(track: UInt8, sector: UInt8, spt: Int) -> Int {
        Int(track) * spt * SECTOR_SIZE + Int(sector) * SECTOR_SIZE
    }
}
