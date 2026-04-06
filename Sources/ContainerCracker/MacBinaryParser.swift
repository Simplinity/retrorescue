import Foundation

/// Parses MacBinary I, II, and III encoded files.
///
/// MacBinary wraps a classic Mac file (data fork + resource fork + metadata)
/// into a single flat file for transport over non-Mac filesystems.
///
/// Format: 128-byte header + data fork (padded to 128) + resource fork (padded to 128)
public enum MacBinaryParser {

    /// Check if data looks like a valid MacBinary file.
    public static func canParse(_ data: Data) -> Bool {
        guard data.count >= 128 else { return false }
        // Byte 0 must be 0
        guard data[0] == 0x00 else { return false }
        // Byte 74 must be 0
        guard data[74] == 0x00 else { return false }
        // Byte 82 must be 0
        guard data[82] == 0x00 else { return false }
        // Filename length 1-63
        let nameLen = Int(data[1])
        guard nameLen >= 1, nameLen <= 63 else { return false }
        // Data + resource fork sizes must be plausible
        let dataSize = readUInt32(data, offset: 83)
        let rsrcSize = readUInt32(data, offset: 87)
        let expected = 128 + padTo128(dataSize) + padTo128(rsrcSize)
        guard data.count >= Int(expected) else { return false }
        return true
    }

    /// Parse a MacBinary file into its components.
    public static func parse(_ data: Data) throws -> ExtractedFile {
        guard canParse(data) else {
            throw ContainerError.invalidFormat("Not a valid MacBinary file")
        }

        // Filename (Pascal string at offset 1)
        let nameLen = Int(data[1])
        let nameBytes = data[2..<(2 + nameLen)]
        let name = String(data: nameBytes, encoding: .macOSRoman) ?? "Untitled"

        // Type and creator codes (4 bytes each)
        let typeCode = String(data: data[65..<69], encoding: .macOSRoman)
        let creatorCode = String(data: data[69..<73], encoding: .macOSRoman)

        // Finder flags
        let finderFlagsHigh = UInt16(data[73]) << 8
        let finderFlagsLow: UInt16 = data.count > 101 ? UInt16(data[101]) : 0
        let finderFlags = finderFlagsHigh | finderFlagsLow

        // Fork sizes
        let dataSize = Int(readUInt32(data, offset: 83))
        let rsrcSize = Int(readUInt32(data, offset: 87))

        // Dates (seconds since 1904-01-01)
        let createdMac = readUInt32(data, offset: 91)
        let modifiedMac = readUInt32(data, offset: 95)

        // Extract forks
        let dataStart = 128
        let dataFork = data[dataStart..<(dataStart + dataSize)]

        let rsrcStart = 128 + padTo128(UInt32(dataSize))
        let rsrcFork: Data
        if rsrcSize > 0 {
            rsrcFork = Data(data[Int(rsrcStart)..<(Int(rsrcStart) + rsrcSize)])
        } else {
            rsrcFork = Data()
        }

        return ExtractedFile(
            name: name,
            dataFork: Data(dataFork),
            rsrcFork: rsrcFork,
            typeCode: typeCode,
            creatorCode: creatorCode,
            finderFlags: finderFlags,
            created: macDateToDate(createdMac),
            modified: macDateToDate(modifiedMac)
        )
    }

    /// MacBinary version detected: 1, 2, or 3.
    public static func version(of data: Data) -> Int? {
        guard canParse(data), data.count >= 128 else { return nil }
        let v = data[122]
        if v == 0x82 { return 3 }
        if v == 0x81 { return 2 }
        return 1
    }

    // MARK: - Helpers

    /// Read big-endian UInt32 from data at offset.
    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset]) << 24
        let b1 = UInt32(data[offset + 1]) << 16
        let b2 = UInt32(data[offset + 2]) << 8
        let b3 = UInt32(data[offset + 3])
        return b0 | b1 | b2 | b3
    }

    /// Pad a size up to the next 128-byte boundary.
    private static func padTo128(_ size: UInt32) -> UInt32 {
        (size + 127) & ~127
    }

    /// Convert Mac epoch (1904-01-01) timestamp to Date.
    static func macDateToDate(_ macSeconds: UInt32) -> Date? {
        guard macSeconds > 0 else { return nil }
        // Mac epoch is 2082844800 seconds before Unix epoch
        let unixSeconds = Double(macSeconds) - 2_082_844_800
        return Date(timeIntervalSince1970: unixSeconds)
    }
}
