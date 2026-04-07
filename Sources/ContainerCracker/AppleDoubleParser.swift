import Foundation

/// Parses AppleSingle and AppleDouble encoded files.
///
/// AppleSingle (magic 0x00051600): both forks in one file.
/// AppleDouble (magic 0x00051607): resource fork + Finder info only
///   (data fork is the regular file alongside the ._ file).
public enum AppleDoubleParser {

    private static let appleSingleMagic: UInt32 = 0x00051600
    private static let appleDoubleMagic: UInt32 = 0x00051607
    private static let version1: UInt32 = 0x00010000
    private static let version2: UInt32 = 0x00020000

    public static func canParse(_ data: Data) -> Bool {
        guard data.count >= 26 else { return false }
        let magic = readBE32(data, at: 0)
        guard magic == appleSingleMagic || magic == appleDoubleMagic else {
            // Check for rare little-endian variant (CP2: "bad-Mac variety")
            let magicLE = readLE32(data, at: 0)
            guard magicLE == appleSingleMagic || magicLE == appleDoubleMagic else { return false }
            return true
        }
        // Validate version
        let version = readBE32(data, at: 4)
        return version == version1 || version == version2
    }

    public static var isAppleSingle: (Data) -> Bool = { data in
        guard data.count >= 4 else { return false }
        return readBE32(data, at: 0) == appleSingleMagic
    }

    public static var isAppleDouble: (Data) -> Bool = { data in
        guard data.count >= 4 else { return false }
        return readBE32(data, at: 0) == appleDoubleMagic
    }

    /// Parsed result with optional components.
    public struct ParseResult {
        public var dataFork: Data?
        public var rsrcFork: Data?
        public var realName: String?
        public var finderInfo: Data?  // 32 bytes: type(4) + creator(4) + flags(2) + ...
        public var created: Date?
        public var modified: Date?
    }

    public static func parse(_ data: Data) throws -> ParseResult {
        guard canParse(data) else {
            throw ContainerError.invalidFormat("Not AppleSingle/AppleDouble")
        }
        guard data.count >= 26 else {
            throw ContainerError.corruptedData("Header too short")
        }

        // Detect endianness
        let magic = readBE32(data, at: 0)
        let isLE = (magic != appleSingleMagic && magic != appleDoubleMagic)

        // Number of entries at offset 24
        let entryCount = Int(isLE ? readLE16(data, at: 24) : readBE16(data, at: 24))
        let headerEnd = 26 + entryCount * 12

        guard data.count >= headerEnd else {
            throw ContainerError.corruptedData("Entry table truncated")
        }

        var result = ParseResult()

        for i in 0..<entryCount {
            let base = 26 + i * 12
            let entryID = isLE ? readLE32(data, at: base) : readBE32(data, at: base)
            let offset = Int(isLE ? readLE32(data, at: base + 4) : readBE32(data, at: base + 4))
            let length = Int(isLE ? readLE32(data, at: base + 8) : readBE32(data, at: base + 8))

            guard offset >= 0, length >= 0, offset + length <= data.count else { continue }
            let entryData = Data(data[offset..<(offset + length)])

            switch entryID {
            case 1: result.dataFork = entryData                             // Data Fork
            case 2: result.rsrcFork = entryData                             // Resource Fork
            case 3: result.realName = String(data: entryData, encoding: .macOSRoman) // Real Name
            case 8: parseFileDates(entryData, into: &result)                // File Dates (v2)
            case 9: result.finderInfo = entryData                           // Finder Info
            default: break  // 4=comment, 5=iconBW, 6=iconColor, 7=fileInfo, 10+=other
            }
        }
        return result
    }

    /// Parse FileDates entry (v2): 4 × signed 32-bit, seconds since Jan 1, 2000 00:00 UTC.
    private static func parseFileDates(_ data: Data, into result: inout ParseResult) {
        guard data.count >= 16 else { return }
        let epoch2000 = Date(timeIntervalSince1970: 946_684_800) // Jan 1, 2000
        let creation = Int32(bitPattern: readBE32(data, at: 0))
        let modification = Int32(bitPattern: readBE32(data, at: 4))
        result.created = epoch2000.addingTimeInterval(TimeInterval(creation))
        result.modified = epoch2000.addingTimeInterval(TimeInterval(modification))
    }

    /// Extract type/creator from Finder info (32 bytes, type at 0, creator at 4).
    public static func typeCreator(from finderInfo: Data) -> (type: String?, creator: String?) {
        guard finderInfo.count >= 8 else { return (nil, nil) }
        let type = String(data: finderInfo[0..<4], encoding: .macOSRoman)
        let creator = String(data: finderInfo[4..<8], encoding: .macOSRoman)
        return (type, creator)
    }

    /// Extract Finder flags from Finder info (at offset 8, big-endian UInt16).
    public static func finderFlags(from finderInfo: Data) -> UInt16 {
        guard finderInfo.count >= 10 else { return 0 }
        return UInt16(finderInfo[8]) << 8 | UInt16(finderInfo[9])
    }

    // MARK: - Helpers

    private static func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 |
        UInt32(data[offset + 1]) << 16 |
        UInt32(data[offset + 2]) << 8 |
        UInt32(data[offset + 3])
    }

    private static func readBE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readLE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
        UInt32(data[offset + 1]) << 8 |
        UInt32(data[offset + 2]) << 16 |
        UInt32(data[offset + 3]) << 24
    }

    private static func readLE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }
}
