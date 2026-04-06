import Testing
import Foundation
@testable import ContainerCracker

/// Tests for BinHex and AppleDouble parsers.
struct BinHexParserTests {

    /// Encode data in BinHex 6-bit format (inverse of parser's decode).
    private static func binHexEncode(_ data: Data) -> String {
        let chars = Array("!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr")
        var result = ""
        var accumulator: UInt32 = 0
        var bits = 0
        for byte in data {
            accumulator = (accumulator << 8) | UInt32(byte)
            bits += 8
            while bits >= 6 {
                bits -= 6
                let index = Int((accumulator >> bits) & 0x3F)
                result.append(chars[index])
            }
        }
        if bits > 0 {
            let index = Int((accumulator << (6 - bits)) & 0x3F)
            result.append(chars[index])
        }
        return result
    }

    /// Build a minimal BinHex binary stream (pre-encoding, pre-RLE).
    private static func makeBinHexStream(
        name: String = "Test",
        type: String = "TEXT",
        creator: String = "ttxt",
        dataFork: Data = Data("hi".utf8),
        rsrcFork: Data = Data()
    ) -> Data {
        var stream = Data()
        // Filename (Pascal string)
        let nameBytes = Array(name.utf8)
        stream.append(UInt8(nameBytes.count))
        stream.append(contentsOf: nameBytes)
        // Version
        stream.append(0x00)
        // Type (4 bytes)
        stream.append(contentsOf: Array(type.utf8.prefix(4)))
        // Creator (4 bytes)
        stream.append(contentsOf: Array(creator.utf8.prefix(4)))
        // Finder flags (2 bytes)
        stream.append(contentsOf: [0x00, 0x00])
        // Data fork length (4 bytes BE)
        let ds = UInt32(dataFork.count)
        stream.append(contentsOf: [UInt8((ds >> 24) & 0xFF), UInt8((ds >> 16) & 0xFF),
                                   UInt8((ds >> 8) & 0xFF), UInt8(ds & 0xFF)])
        // Resource fork length (4 bytes BE)
        let rs = UInt32(rsrcFork.count)
        stream.append(contentsOf: [UInt8((rs >> 24) & 0xFF), UInt8((rs >> 16) & 0xFF),
                                   UInt8((rs >> 8) & 0xFF), UInt8(rs & 0xFF)])
        // Header CRC (2 bytes, fake)
        stream.append(contentsOf: [0x00, 0x00])
        // Data fork
        stream.append(dataFork)
        // Data CRC (2 bytes, fake)
        stream.append(contentsOf: [0x00, 0x00])
        // Resource fork
        stream.append(rsrcFork)
        // Resource CRC (2 bytes, fake)
        stream.append(contentsOf: [0x00, 0x00])
        return stream
    }

    /// Build a complete .hqx text file.
    private static func makeBinHexFile(
        name: String = "Test",
        type: String = "TEXT",
        creator: String = "ttxt",
        dataFork: Data = Data("hi".utf8),
        rsrcFork: Data = Data()
    ) -> Data {
        let stream = makeBinHexStream(name: name, type: type, creator: creator,
                                       dataFork: dataFork, rsrcFork: rsrcFork)
        let encoded = binHexEncode(stream)
        let text = "(This file must be converted with BinHex 4.0)\n\n:\(encoded):\n"
        return Data(text.utf8)
    }

    @Test func detectBinHex() {
        let data = Self.makeBinHexFile()
        #expect(BinHexParser.canParse(data) == true)
        #expect(ContainerCracker.identify(data: data) == .binHex)
    }

    @Test func rejectNonBinHex() {
        let data = Data("Just a regular text file".utf8)
        #expect(BinHexParser.canParse(data) == false)
    }

    @Test func parseBinHex() throws {
        let data = Self.makeBinHexFile(
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
}
