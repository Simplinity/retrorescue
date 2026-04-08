import Foundation

/// Parses Binary II (.bny, .bqy) archives — Apple II file wrapper format.
///
/// Binary II was developed by Gary B. Little (1986) to preserve ProDOS file attributes
/// when transferring files via modem. Each file has a 128-byte header followed by data
/// padded to 128-byte boundary. Multiple files are concatenated.
///
/// Reference: Apple II File Type Note $e0/8000, CiderPress2 Binary2-notes.md
public enum BinaryIIParser {

    /// Magic bytes: 0x0A ('LF'), 0x47 ('G'), 0x4C ('L')
    private static let magic: [UInt8] = [0x0A, 0x47, 0x4C]

    /// Check if data looks like a Binary II archive.
    public static func canParse(_ data: Data) -> Bool {
        guard data.count >= 128 else { return false }
        guard data[0] == magic[0], data[1] == magic[1], data[2] == magic[2] else { return false }
        // ID byte at offset 18 must be 0x02
        guard data[0x12] == 0x02 else { return false }
        return true
    }

    /// Parse all files from a Binary II archive.
    public static func parseAll(_ data: Data) throws -> [ExtractedFile] {
        guard canParse(data) else {
            throw ContainerError.invalidFormat("Not a Binary II archive")
        }

        var results: [ExtractedFile] = []
        var offset = 0

        while offset + 128 <= data.count {
            // Verify magic at start of each entry
            guard data[offset] == magic[0],
                  data[offset + 1] == magic[1],
                  data[offset + 2] == magic[2] else { break }

            // Parse header
            let access = data[offset + 0x03]
            let fileType = data[offset + 0x04]
            let auxType = UInt16(data[offset + 0x05]) | UInt16(data[offset + 0x06]) << 8
            let storageType = data[offset + 0x07]

            // File length (3 bytes, little-endian)
            let fileLen = Int(data[offset + 0x14])
                        | Int(data[offset + 0x15]) << 8
                        | Int(data[offset + 0x16]) << 16

            // Filename (Pascal string at offset 0x17, length byte + up to 64 chars)
            let nameLen = Int(data[offset + 0x17])
            let nameStart = offset + 0x18
            let name: String
            if nameLen > 0, nameLen <= 64, nameStart + nameLen <= data.count {
                name = String(data: data[nameStart..<(nameStart + nameLen)], encoding: .ascii)
                    ?? "file_\(results.count)"
            } else {
                name = "file_\(results.count)"
            }

            // Dates (ProDOS format: 16-bit date + 16-bit time)
            let modDate = proDOSDate(
                date: UInt16(data[offset + 0x0A]) | UInt16(data[offset + 0x0B]) << 8,
                time: UInt16(data[offset + 0x0C]) | UInt16(data[offset + 0x0D]) << 8
            )
            let createDate = proDOSDate(
                date: UInt16(data[offset + 0x0E]) | UInt16(data[offset + 0x0F]) << 8,
                time: UInt16(data[offset + 0x10]) | UInt16(data[offset + 0x11]) << 8
            )

            // Skip directories (storageType 0x0D or fileType 0x0F)
            let isDir = storageType == 0x0D || fileType == 0x0F

            // Data starts after header
            let dataStart = offset + 128
            let dataEnd = dataStart + fileLen
            let paddedEnd = dataStart + ((fileLen + 127) & ~127)

            if !isDir && fileLen > 0 && dataEnd <= data.count {
                let fileData = Data(data[dataStart..<dataEnd])
                results.append(ExtractedFile(
                    name: name,
                    dataFork: fileData,
                    typeCode: String(format: "$%02X", fileType),
                    creatorCode: String(format: "$%04X", auxType),
                    created: createDate,
                    modified: modDate
                ))
            }

            // Advance to next entry (header + padded data)
            offset = paddedEnd > offset + 128 ? paddedEnd : offset + 128
        }

        return results
    }

    /// Convert ProDOS date/time to Swift Date.
    /// ProDOS date: bits 15-9=year(0-99), 8-5=month(1-12), 4-0=day(1-31)
    /// ProDOS time: bits 15-8=hour(0-23), 7-0=minute(0-59)
    private static func proDOSDate(date: UInt16, time: UInt16) -> Date? {
        guard date != 0 else { return nil }
        let year = Int((date >> 9) & 0x7F)
        let month = Int((date >> 5) & 0x0F)
        let day = Int(date & 0x1F)
        let hour = Int((time >> 8) & 0xFF)
        let minute = Int(time & 0xFF)
        // ProDOS year 0-39 → 2000-2039, 40-99 → 1940-1999
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
