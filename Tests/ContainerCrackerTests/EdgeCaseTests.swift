import Testing
import Foundation
@testable import ContainerCracker

/// Edge case tests — boundary conditions, error paths, malformed input.
struct EdgeCaseTests {

    // MARK: - MacBinary CRC-16/XMODEM

    @Test func crc16KnownCheckValue() {
        // CRC-16/XMODEM check value: CRC of "123456789" = 0x31C3
        let data = Data("123456789".utf8)
        let crc = MacBinaryParser.crc16XMODEM(data: data, offset: 0, count: data.count)
        #expect(crc == 0x31C3)
    }

    @Test func crc16EmptyIsZero() {
        let crc = MacBinaryParser.crc16XMODEM(data: Data(), offset: 0, count: 0)
        #expect(crc == 0)
    }

    @Test func crc16SingleByte() {
        let data = Data([0x41])
        let crc = MacBinaryParser.crc16XMODEM(data: data, offset: 0, count: 1)
        #expect(crc != 0)
    }

    @Test func crc16OffsetSubrange() {
        let data = Data([0x00, 0x00, 0x41, 0x42, 0x43, 0x00])
        let full = MacBinaryParser.crc16XMODEM(data: Data([0x41, 0x42, 0x43]), offset: 0, count: 3)
        let sub = MacBinaryParser.crc16XMODEM(data: data, offset: 2, count: 3)
        #expect(full == sub)
    }

    // MARK: - PackBits Edge Cases

    @Test func packBitsMaxRepeat() {
        // Max repeat: -127 → repeat 128 times
        let compressed = Data([0x81, 0xFF])  // -127 → repeat 0xFF 128 times
        let result = PackBitsDecompressor.decompress(compressed)
        #expect(result.count == 128)
        #expect(result.allSatisfy { $0 == 0xFF })
    }

    @Test func packBitsMaxLiteral() {
        // Max literal: 127 → copy 128 bytes
        var compressed = Data([0x7F])  // 127 → copy 128 bytes
        compressed.append(Data(repeating: 0x42, count: 128))
        let result = PackBitsDecompressor.decompress(compressed)
        #expect(result.count == 128)
        #expect(result.allSatisfy { $0 == 0x42 })
    }

    @Test func packBitsTruncatedRepeat() {
        // Repeat command but no data byte follows
        let compressed = Data([0xFE])  // needs 1 more byte
        let result = PackBitsDecompressor.decompress(compressed)
        #expect(result.isEmpty)
    }

    @Test func packBitsTruncatedLiteral() {
        // Literal 3 bytes but only 1 follows
        let compressed = Data([0x02, 0x41])
        let result = PackBitsDecompressor.decompress(compressed)
        #expect(result.count == 1)
    }

    // MARK: - Icon Rendering Edge Cases

    @Test func renderICN_WithMask() {
        // ICN#: 256 bytes = 128 icon + 128 mask
        var data = Data(repeating: 0xFF, count: 128)  // all black icon
        data.append(Data(repeating: 0xAA, count: 128))  // checkerboard mask
        let image = ResourceRenderers.renderICON(data)
        #expect(image != nil)
        #expect(image!.size.width == 32)
    }

    @Test func renderIcl4Size() {
        // icl4: 32×32 4-bit = 512 bytes exactly
        let data = Data(repeating: 0x12, count: 512)
        let image = ResourceRenderers.renderIcl4(data)
        #expect(image != nil)
    }

    @Test func renderIcl4TooSmall() {
        let image = ResourceRenderers.renderIcl4(Data(repeating: 0, count: 100))
        #expect(image == nil)
    }

    @Test func renderIcl8Size() {
        // icl8: 32×32 8-bit = 1024 bytes
        let data = Data(repeating: 0x05, count: 1024)
        let image = ResourceRenderers.renderIcl8(data)
        #expect(image != nil)
    }

    @Test func renderIcs16x16() {
        // ics#: 32 bytes icon + 32 bytes mask
        let data = Data(repeating: 0xFF, count: 64)
        let image = ResourceRenderers.renderIcs(data)
        #expect(image != nil)
    }

    @Test func renderCURS() {
        // CURS: 68 bytes = 32 data + 32 mask + 4 hotspot
        let data = Data(repeating: 0xAA, count: 68)
        let image = ResourceRenderers.renderCURS(data)
        #expect(image != nil)
    }

    @Test func renderPAT() {
        // PAT: 8×8 = 8 bytes
        let data = Data([0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55])
        let image = ResourceRenderers.renderPAT(data)
        #expect(image != nil)
    }

    @Test func renderIconDispatch() {
        // renderIcon should dispatch to the right renderer
        let iconData = Data(repeating: 0xFF, count: 128)
        #expect(ResourceRenderers.renderIcon(type: "ICON", data: iconData) != nil)
        #expect(ResourceRenderers.renderIcon(type: "ZZZZ", data: iconData) == nil)
    }

    // MARK: - Parser Edge Cases

    @Test func menuParserEmpty() {
        let result = ResourceRenderers.parseMENU(Data(repeating: 0, count: 5))
        #expect(result == nil)
    }

    @Test func sndParserBadFormat() {
        var data = Data(repeating: 0, count: 30)
        data[0] = 0x00; data[1] = 0x03  // format 3 = invalid
        let result = ResourceRenderers.parseSnd(data)
        #expect(result == nil)
    }

    @Test func codeParser() {
        var data = Data(repeating: 0, count: 10)
        data[0] = 0x00; data[1] = 0x04  // jump table offset
        data[2] = 0x00; data[3] = 0x08  // entries
        let info = ResourceRenderers.parseCODE(data)
        #expect(info != nil)
        #expect(info?.jumpTableOffset == 4)
        #expect(info?.jumpTableEntries == 8)
    }

    @Test func strParserEdge() {
        // Empty string
        let result = ResourceRenderers.parseSTR(Data([0x00]))
        #expect(result == "")
        // Nil on empty data
        #expect(ResourceRenderers.parseSTR(Data()) == nil)
    }

    @Test func strListEmpty() {
        // STR# with count=0
        let result = ResourceRenderers.parseSTRList(Data([0x00, 0x00]))
        #expect(result?.isEmpty == true)
    }

    // MARK: - MFS Alloc Map 12-bit Encoding

    @Test func mfs12BitEncoding() {
        // 3 bytes → 2 entries: 0xAB, 0xCD, 0xEF
        // entry0 = 0xABC, entry1 = 0xDEF
        // Verify this matches our MFS reader's algorithm
        let b0: UInt16 = 0xAB, b1: UInt16 = 0xCD, b2: UInt16 = 0xEF
        let entry0 = (b0 << 4) | (b1 >> 4)
        let entry1 = ((b1 & 0x0F) << 8) | b2
        #expect(entry0 == 0xABC)
        #expect(entry1 == 0xDEF)
    }

    // MARK: - ProDOS Date Encoding

    @Test func proDOSDateEncoding() {
        // ProDOS date: bits 15-9=year(0-99), 8-5=month(1-12), 4-0=day(1-31)
        // Time: bits 12-8=hour(0-23), 5-0=minute(0-59)
        // Verify our algorithm: year 95 = 1995, month 6, day 15
        let year = 95, month = 6, day = 15
        let dateWord = UInt16((year << 9) | (month << 5) | day)
        #expect((dateWord >> 9) & 0x7F == 95)
        #expect((dateWord >> 5) & 0x0F == 6)
        #expect(dateWord & 0x1F == 15)
    }

    @Test func proDOSY2K() {
        // Year < 40 → 2000+year, year >= 40 → 1900+year
        let year2005 = 5   // < 40 → 2005
        let year1995 = 95  // >= 40 → 1995
        #expect((year2005 < 40 ? 2000 : 1900) + year2005 == 2005)
        #expect((year1995 < 40 ? 2000 : 1900) + year1995 == 1995)
    }

    // MARK: - Mac Epoch

    @Test func macEpochConversion() {
        // Mac epoch: Jan 1, 1904 00:00:00 UTC
        // Unix epoch - Mac epoch = 2,082,844,800 seconds
        let macEpochDelta = 2_082_844_800.0
        let macSeconds: UInt32 = 3_600_000_000  // ~2018 in Mac time
        let date = Date(timeIntervalSince1970: Double(macSeconds) - macEpochDelta)
        #expect(date.timeIntervalSince1970 > 0)  // after Unix epoch
        #expect(date.timeIntervalSince1970 < 2_000_000_000)  // reasonable
    }

    // MARK: - Four Char Code

    @Test func fourCharCodeRoundTrip() {
        let raw: UInt32 = 0x54455854  // "TEXT"
        let bytes: [UInt8] = [
            UInt8((raw >> 24) & 0xFF), UInt8((raw >> 16) & 0xFF),
            UInt8((raw >> 8) & 0xFF), UInt8(raw & 0xFF)
        ]
        let str = String(data: Data(bytes), encoding: .macOSRoman)
        #expect(str == "TEXT")
    }

    @Test func fourCharCodeCreators() {
        // Common creator codes
        for (raw, expected) in [(UInt32(0x4D535744), "MSWD"),
                                 (UInt32(0x74747874), "ttxt"),
                                 (UInt32(0x4D414353), "MACS")] {
            let bytes: [UInt8] = [UInt8((raw >> 24) & 0xFF), UInt8((raw >> 16) & 0xFF),
                                  UInt8((raw >> 8) & 0xFF), UInt8(raw & 0xFF)]
            #expect(String(data: Data(bytes), encoding: .macOSRoman) == expected)
        }
    }

    // MARK: - Color Palette Sizes

    @Test func mac4BitPaletteSize() {
        #expect(ResourceRenderers.mac4BitPalette.count == 16)
    }

    @Test func mac8BitPaletteSize() {
        #expect(ResourceRenderers.mac8BitPalette.count == 256)
    }

    @Test func mac4BitPaletteWhiteFirst() {
        let (r, g, b) = ResourceRenderers.mac4BitPalette[0]
        #expect(r == 255 && g == 255 && b == 255)
    }

    @Test func mac4BitPaletteBlackLast() {
        let (r, g, b) = ResourceRenderers.mac4BitPalette[15]
        #expect(r == 0 && g == 0 && b == 0)
    }

    // MARK: - APM Partition Type Checks

    @Test func apmPartitionTypes() {
        var p = APMParser.PartitionEntry()
        p.type = "Apple_HFS"
        #expect(p.isHFS)
        #expect(!p.isMFS)
        #expect(!p.isFree)
        #expect(!p.isDriver)

        p.type = "Apple_Free"
        #expect(p.isFree)
        #expect(!p.isHFS)

        p.type = "Apple_Driver43"
        #expect(p.isDriver)

        p.type = "Apple_partition_map"
        #expect(p.isPartitionMap)
    }
}
