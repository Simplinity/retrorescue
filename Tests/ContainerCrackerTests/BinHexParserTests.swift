import Testing
import Foundation
@testable import ContainerCracker

/// Tests for the BinHex 4.0 parser.
struct BinHexParserTests {

    /// Encode data as BinHex 4.0 for testing.
    /// Builds the binary stream, applies RLE, then 6-bit encodes.
    private static func makeBinHex(
        name: String = "Test",
        type: String = "TEXT",
        creator: String = "ttxt",
        dataFork: Data = Data("hi".utf8),
        rsrcFork: Data = Data()
    ) -> Data {
        // Build binary stream
        var stream = Data()
        let nameBytes = Array(name.utf8.prefix(63))
        stream.append(UInt8(nameBytes.count))
        stream.append(contentsOf: nameBytes)
        stream.append(0) // version
        stream.append(contentsOf: type.utf8.prefix(4))
        stream.append(contentsOf: creator.utf8.prefix(4))
        // Finder flags (2 bytes)
        stream.append(contentsOf: [0x00, 0x00])
        // Data fork length (4 bytes BE)
        appendBE32(&stream, UInt32(dataFork.count))
        // Resource fork length (4 bytes BE)
        appendBE32(&stream, UInt32(rsrcFork.count))
        // Header CRC (2 bytes, dummy)
        stream.append(contentsOf: [0x00, 0x00])
        // Data fork
        stream.append(dataFork)
        // Data CRC (2 bytes, dummy)
        stream.append(contentsOf: [0x00, 0x00])
        // Resource fork
        stream.append(rsrcFork)
        // Resource CRC (2 bytes, dummy)
        stream.append(contentsOf: [0x00, 0x00])

        // 6-bit encode (no RLE needed for simple test data)
        let encoded = sixBitEncode(stream)

        // Wrap in BinHex text format
        let text = "(This file must be converted with BinHex 4.0)\n:\(encoded):\n"
        return Data(text.utf8)
    }

    private static let encodeTable = Array("!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr".utf8)

    private static func sixBitEncode(_ data: Data) -> String {
        var result = ""
        var accumulator: UInt32 = 0
        var bits = 0
        for byte in data {
            accumulator = (accumulator << 8) | UInt32(byte)
            bits += 8
            while bits >= 6 {
                bits -= 6
                let index = Int((accumulator >> bits) & 0x3F)
                result.append(Character(UnicodeScalar(encodeTable[index])))
            }
        }
        if bits > 0 {
            let index = Int((accumulator << (6 - bits)) & 0x3F)
            result.append(Character(UnicodeScalar(encodeTable[index])))
        }
        return result
    }

    private static func appendBE32(_ data: inout Data, _ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    // MARK: - Tests

    @Test func detectBinHex() {
        let data = Self.makeBinHex()
        #expect(BinHexParser.canParse(data) == true)
    }

    @Test func rejectNonBinHex() {
        let random = Data("Just a regular text file".utf8)
        #expect(BinHexParser.canParse(random) == false)
    }

    @Test func decode() throws {
        let data = Self.makeBinHex(
            name: "ReadMe",
            type: "TEXT",
            creator: "ttxt",
            dataFork: Data("Hello BinHex!\r".utf8)
        )
        let result = try BinHexParser.parse(data)

        #expect(result.name == "ReadMe")
        #expect(result.typeCode == "TEXT")
        #expect(result.creatorCode == "ttxt")
        #expect(String(data: result.dataFork, encoding: .utf8) == "Hello BinHex!\r")
    }

    @Test func decodeWithResourceFork() throws {
        let rsrc = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let data = Self.makeBinHex(
            name: "WithRsrc",
            type: "APPL",
            creator: "TEST",
            dataFork: Data("data".utf8),
            rsrcFork: rsrc
        )
        let result = try BinHexParser.parse(data)

        #expect(result.name == "WithRsrc")
        #expect(result.typeCode == "APPL")
        #expect(result.rsrcFork == rsrc)
    }

    @Test func formatDetection() {
        let data = Self.makeBinHex()
        #expect(ContainerCracker.identify(data: data) == .binHex)
    }
}
