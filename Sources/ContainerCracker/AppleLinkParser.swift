import Foundation

/// Parses AppleLink PE (.acu) archives — Apple II file package format.
///
/// Created by Floyd Zink for AppleLink Personal Edition (later AOL).
/// Uses ProDOS file attributes. Optional SQueeze (RLE+Huffman) compression.
///
/// Reference: CiderPress2 AppleLink-notes.md (reverse-engineered)
public enum AppleLinkParser {

    /// Signature bytes at offset 4: "fZink"
    private static let signature: [UInt8] = [0x66, 0x5A, 0x69, 0x6E, 0x6B] // "fZink"

    /// Check if data looks like an ACU archive.
    public static func canParse(_ data: Data) -> Bool {
        guard data.count >= 20 else { return false }
        // Signature "fZink" at offset 4
        for i in 0..<5 {
            guard data[4 + i] == signature[i] else { return false }
        }
        // Version must be 1
        guard data[9] == 0x01 else { return false }
        return true
    }

    /// Parse all files from an ACU archive.
    public static func parseAll(_ data: Data) throws -> [ExtractedFile] {
        guard canParse(data) else {
            throw ContainerError.invalidFormat("Not an AppleLink PE archive")
        }

        let recordCount = Int(readLE16(data, at: 0))
        var offset = 20  // skip file header
        var results: [ExtractedFile] = []

        for _ in 0..<recordCount {
            guard offset + 0x36 <= data.count else { break }

            let rsrcCompMethod = data[offset + 0x00]
            let dataCompMethod = data[offset + 0x01]
            let rsrcCompLen = Int(readLE32(data, at: offset + 0x0E))
            let dataCompLen = Int(readLE32(data, at: offset + 0x12))
            let fileType = data[offset + 0x18]
            let auxType = readLE16(data, at: offset + 0x1A)
            let storageType = readLE16(data, at: offset + 0x20)
            let rsrcUncompLen = Int(readLE32(data, at: offset + 0x22))
            let dataUncompLen = Int(readLE32(data, at: offset + 0x26))

            let createDate = proDOSDate(
                date: readLE16(data, at: offset + 0x2A),
                time: readLE16(data, at: offset + 0x2C)
            )
            let modDate = proDOSDate(
                date: readLE16(data, at: offset + 0x2E),
                time: readLE16(data, at: offset + 0x30)
            )

            let nameLen = Int(readLE16(data, at: offset + 0x32))
            let nameStart = offset + 0x36
            guard nameStart + nameLen <= data.count else { break }

            let name: String
            if nameLen > 0 {
                name = String(data: data[nameStart..<(nameStart + nameLen)], encoding: .ascii)
                    ?? "file_\(results.count)"
            } else {
                name = "file_\(results.count)"
            }

            // Data follows immediately after header: rsrc fork then data fork
            let dataOffset = nameStart + nameLen
            let rsrcEnd = dataOffset + rsrcCompLen
            let dataEnd = rsrcEnd + dataCompLen
            guard dataEnd <= data.count else { break }

            // Skip directories (storageType 0x0D)
            let isDir = storageType == 0x0D

            if !isDir {
                var rsrcFork = Data()
                var dataFork = Data()

                // Resource fork
                if rsrcCompLen > 0 {
                    if rsrcCompMethod == 0 {
                        rsrcFork = Data(data[dataOffset..<rsrcEnd])
                    }
                    // SQueeze (method 3) not yet supported — data left empty
                }

                // Data fork
                if dataCompLen > 0 {
                    if dataCompMethod == 0 {
                        dataFork = Data(data[rsrcEnd..<dataEnd])
                    }
                    // SQueeze (method 3) not yet supported — data left empty
                }

                // Only add if we extracted something useful
                if !dataFork.isEmpty || !rsrcFork.isEmpty {
                    results.append(ExtractedFile(
                        name: name,
                        dataFork: dataFork,
                        rsrcFork: rsrcFork,
                        typeCode: String(format: "$%02X", fileType),
                        creatorCode: String(format: "$%04X", auxType),
                        created: createDate,
                        modified: modDate
                    ))
                }
            }

            offset = dataEnd
        }

        return results
    }

    // MARK: - Helpers

    private static func readLE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readLE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
        UInt32(data[offset + 1]) << 8 |
        UInt32(data[offset + 2]) << 16 |
        UInt32(data[offset + 3]) << 24
    }

    /// Convert ProDOS date/time to Swift Date.
    private static func proDOSDate(date: UInt16, time: UInt16) -> Date? {
        guard date != 0 else { return nil }
        let year = Int((date >> 9) & 0x7F)
        let month = Int((date >> 5) & 0x0F)
        let day = Int(date & 0x1F)
        let hour = Int((time >> 8) & 0xFF)
        let minute = Int(time & 0xFF)
        let fullYear = year < 40 ? 2000 + year : 1900 + year
        var components = DateComponents()
        components.year = fullYear
        components.month = max(1, min(12, month))
        components.day = max(1, min(31, day))
        components.hour = min(23, hour)
        components.minute = min(59, minute)
        return Calendar.current.date(from: components)
    }
}
