import Foundation

/// Native CP/M filesystem reader for Apple II (read-only).
/// Supports 140K (5.25" floppy, CP/M 2.2) and 800K (3.5", CP/AM) formats.
///
/// CP/M disks are NOT self-describing — the layout must be inferred from disk size.
/// Directory entries are 32 bytes each, files span multiple "extents".
///
/// Based on cpmtools diskdefs and CiderPress2 CPM*.cs.
public enum CPMReader {

    // MARK: - Disk Geometry Profiles

    struct DiskProfile {
        let blockSize: Int          // allocation block size (1024 or 2048)
        let maxDirEntries: Int      // number of directory entries
        let dirStartBlock: Int      // first alloc block of directory (after boot area)
        let bootTracks: Int         // reserved boot tracks
        let sectorsPerTrack: Int
        let sectorSize: Int
        let tracks: Int
        let blockNumberSize: Int    // 1 = byte, 2 = 16-bit LE
        let skewTable: [Int]?       // sector skew (nil = sequential)
    }

    // 5.25" floppy — Microsoft SoftCard / Apple II CP/M 2.2
    static let profile140K = DiskProfile(
        blockSize: 1024, maxDirEntries: 64, dirStartBlock: 0,
        bootTracks: 3, sectorsPerTrack: 16, sectorSize: 256, tracks: 35,
        blockNumberSize: 1,
        skewTable: [0,6,12,3,9,15,14,5,11,2,8,7,13,4,10,1]
    )

    // 3.5" floppy — Applied Engineering CP/AM
    static let profile800K = DiskProfile(
        blockSize: 2048, maxDirEntries: 256, dirStartBlock: 8,
        bootTracks: 0, sectorsPerTrack: 0, sectorSize: 512, tracks: 0,
        blockNumberSize: 2, skewTable: nil
    )

    // MARK: - Public API

    /// Check if raw disk data looks like a CP/M volume.
    public static func isCPM(_ data: Data) -> Bool {
        // Try 140K format: directory at track 3 (after boot tracks)
        if data.count == 143_360 {
            let dirOffset = 3 * 16 * 256  // 3 boot tracks × 16 sectors × 256 bytes
            return looksLikeCPMDirectory(data, at: dirOffset)
        }
        // Try 800K format: directory at block 8 (offset 8 * 2048 = 16384)
        if data.count == 819_200 {
            let dirOffset = 8 * 2048
            return looksLikeCPMDirectory(data, at: dirOffset)
        }
        return false
    }

    /// Check if a region looks like CP/M directory entries.
    private static func looksLikeCPMDirectory(_ data: Data, at offset: Int) -> Bool {
        guard offset + 32 <= data.count else { return false }
        var validEntries = 0
        for i in 0..<8 {  // check first 8 entries
            let entryOff = offset + i * 32
            guard entryOff + 32 <= data.count else { break }
            let userNum = data[entryOff]
            if userNum == 0xE5 { continue }  // deleted
            if userNum > 31 { return false }  // invalid user number
            // Check filename has printable ASCII (with high bit stripped)
            let ch = data[entryOff + 1] & 0x7F
            if ch >= 0x20 && ch < 0x7F { validEntries += 1 }
        }
        return validEntries >= 1
    }

    /// Extract all files from a CP/M volume.
    public static func extractAll(from rawData: Data) throws -> [ExtractedFile] {
        let profile: DiskProfile
        if rawData.count == 143_360 {
            profile = profile140K
        } else if rawData.count == 819_200 {
            profile = profile800K
        } else {
            throw ContainerError.invalidFormat("Unsupported CP/M disk size: \(rawData.count)")
        }

        // Calculate directory offset
        let dirOffset: Int
        if profile.bootTracks > 0 {
            dirOffset = profile.bootTracks * profile.sectorsPerTrack * profile.sectorSize
        } else {
            dirOffset = profile.dirStartBlock * profile.blockSize
        }

        // Parse all directory entries
        var extents: [(user: UInt8, name: String, ext: String, extentNum: Int,
                       records: Int, blocks: [Int])] = []

        for i in 0..<profile.maxDirEntries {
            let entryOff = dirOffset + i * 32
            guard entryOff + 32 <= rawData.count else { break }

            let userNum = rawData[entryOff]
            if userNum == 0xE5 { continue }  // deleted entry
            if userNum > 31 { continue }     // invalid

            // Filename: 8 bytes (strip high bits = attribute flags)
            var nameChars = [UInt8]()
            for j in 1...8 { nameChars.append(rawData[entryOff + j] & 0x7F) }
            let name = String(bytes: nameChars, encoding: .ascii)?
                .trimmingCharacters(in: .whitespaces) ?? ""

            // Extension: 3 bytes (strip high bits)
            var extChars = [UInt8]()
            for j in 9...11 { extChars.append(rawData[entryOff + j] & 0x7F) }
            let ext = String(bytes: extChars, encoding: .ascii)?
                .trimmingCharacters(in: .whitespaces) ?? ""

            guard !name.isEmpty else { continue }

            let extentLo = Int(rawData[entryOff + 12])
            let extentHi = Int(rawData[entryOff + 14])
            let extentNum = extentLo + extentHi * 32
            let recordCount = Int(rawData[entryOff + 15])

            // Allocation block numbers
            var blocks: [Int] = []
            if profile.blockNumberSize == 1 {
                for j in 0..<16 {
                    let blk = Int(rawData[entryOff + 16 + j])
                    if blk != 0 { blocks.append(blk) }
                }
            } else {
                for j in 0..<8 {
                    let lo = Int(rawData[entryOff + 16 + j * 2])
                    let hi = Int(rawData[entryOff + 17 + j * 2])
                    let blk = lo | (hi << 8)
                    if blk != 0 { blocks.append(blk) }
                }
            }

            extents.append((user: userNum, name: name, ext: ext,
                           extentNum: extentNum, records: recordCount, blocks: blocks))
        }

        // Group extents by (user, name, ext) → assemble files
        var fileMap: [String: [(extentNum: Int, records: Int, blocks: [Int])]] = [:]
        for ext in extents {
            let key = "\(ext.user):\(ext.name).\(ext.ext)"
            fileMap[key, default: []].append((ext.extentNum, ext.records, ext.blocks))
        }

        // Calculate data area offset (where alloc blocks start)
        let dataAreaOffset: Int
        if profile.bootTracks > 0 {
            dataAreaOffset = profile.bootTracks * profile.sectorsPerTrack * profile.sectorSize
        } else {
            dataAreaOffset = 0  // for 800K, blocks are absolute
        }

        var results: [ExtractedFile] = []
        for (key, fileExtents) in fileMap.sorted(by: { $0.key < $1.key }) {
            let sorted = fileExtents.sorted { $0.extentNum < $1.extentNum }
            let parts = key.split(separator: ":", maxSplits: 1)
            let fileName = parts.count > 1 ? String(parts[1]) : key

            // Read all blocks in order
            var fileData = Data()
            var totalRecords = 0
            for extent in sorted {
                for blk in extent.blocks {
                    let blkOffset = dataAreaOffset + blk * profile.blockSize
                    let end = min(blkOffset + profile.blockSize, rawData.count)
                    guard blkOffset >= 0 && end > blkOffset else { continue }
                    fileData.append(rawData[blkOffset..<end])
                }
                totalRecords += extent.records
            }

            // Trim to actual size (record count × 128 bytes)
            let actualSize = totalRecords * 128
            if actualSize > 0 && actualSize < fileData.count {
                fileData = Data(fileData.prefix(actualSize))
            }

            guard !fileData.isEmpty else { continue }

            results.append(ExtractedFile(
                name: fileName,
                dataFork: fileData,
                typeCode: "CP/M",
                creatorCode: "CPM"
            ))
        }

        return results
    }
}
