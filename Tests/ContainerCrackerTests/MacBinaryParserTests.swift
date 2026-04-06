import Testing
import Foundation
@testable import ContainerCracker

/// Tests for the MacBinary parser.
struct MacBinaryParserTests {

    /// Build a minimal MacBinary II file for testing.
    private static func makeMacBinary(
        name: String = "Test",
        type: String = "TEXT",
        creator: String = "ttxt",
        dataFork: Data = Data("hello".utf8),
        rsrcFork: Data = Data()
    ) -> Data {
        var header = Data(repeating: 0, count: 128)
        // Byte 0: always 0
        // Byte 1: filename length
        let nameBytes = Array(name.utf8.prefix(63))
        header[1] = UInt8(nameBytes.count)
        // Bytes 2-64: filename
        for (i, b) in nameBytes.enumerated() { header[2 + i] = b }
        // Bytes 65-68: type code
        let typeB = Array(type.utf8)
        for (i, b) in typeB.prefix(4).enumerated() { header[65 + i] = b }
        // Bytes 69-72: creator code
        let creatorB = Array(creator.utf8)
        for (i, b) in creatorB.prefix(4).enumerated() { header[69 + i] = b }
        // Byte 74: must be 0 (already is)
        // Byte 82: must be 0 (already is)
        // Bytes 83-86: data fork length (big-endian)
        let ds = UInt32(dataFork.count)
        header[83] = UInt8((ds >> 24) & 0xFF)
        header[84] = UInt8((ds >> 16) & 0xFF)
        header[85] = UInt8((ds >> 8) & 0xFF)
        header[86] = UInt8(ds & 0xFF)
        // Bytes 87-90: resource fork length
        let rs = UInt32(rsrcFork.count)
        header[87] = UInt8((rs >> 24) & 0xFF)
        header[88] = UInt8((rs >> 16) & 0xFF)
        header[89] = UInt8((rs >> 8) & 0xFF)
        header[90] = UInt8(rs & 0xFF)
        // Byte 122: version = 0x81 (MacBinary II)
        header[122] = 0x81

        // Pad data fork to 128-byte boundary
        var file = header
        file.append(dataFork)
        let dataPad = (128 - (dataFork.count % 128)) % 128
        file.append(Data(repeating: 0, count: dataPad))
        // Append resource fork (padded)
        file.append(rsrcFork)
        let rsrcPad = (128 - (rsrcFork.count % 128)) % 128
        file.append(Data(repeating: 0, count: rsrcPad))

        return file
    }

    @Test func detectMacBinaryII() {
        let data = Self.makeMacBinary()
        #expect(MacBinaryParser.canParse(data) == true)
        #expect(MacBinaryParser.version(of: data) == 2)
    }

    @Test func detectMacBinaryIII() {
        var data = Self.makeMacBinary()
        data[122] = 0x82 // MacBinary III
        #expect(MacBinaryParser.canParse(data) == true)
        #expect(MacBinaryParser.version(of: data) == 3)
    }

    @Test func rejectNonMacBinary() {
        let random = Data("This is just some random text file content".utf8)
        #expect(MacBinaryParser.canParse(random) == false)
    }

    @Test func parseSimple() throws {
        let data = Self.makeMacBinary(
            name: "ReadMe",
            type: "TEXT",
            creator: "ttxt",
            dataFork: Data("Hello from 1997!\r".utf8)
        )
        let result = try MacBinaryParser.parse(data)

        #expect(result.name == "ReadMe")
        #expect(result.typeCode == "TEXT")
        #expect(result.creatorCode == "ttxt")
        #expect(String(data: result.dataFork, encoding: .utf8) == "Hello from 1997!\r")
        #expect(result.rsrcFork.isEmpty)
    }

    @Test func parseWithResourceFork() throws {
        let rsrc = Data([0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00,
                         0x00, 0x00, 0x00, 0x1E, 0x00, 0x00, 0x00, 0x1E])
        let data = Self.makeMacBinary(
            name: "MyApp",
            type: "APPL",
            creator: "MYAP",
            dataFork: Data("code".utf8),
            rsrcFork: rsrc
        )
        let result = try MacBinaryParser.parse(data)

        #expect(result.name == "MyApp")
        #expect(result.typeCode == "APPL")
        #expect(result.rsrcFork == rsrc)
        #expect(result.dataFork == Data("code".utf8))
    }

    @Test func macDateConversion() {
        // 2082844800 = offset from Mac epoch (1904) to Unix epoch (1970)
        // So macSeconds = 2082844800 should be Jan 1, 1970 00:00:00 UTC
        let date = MacBinaryParser.macDateToDate(2_082_844_800)
        #expect(date != nil)
        #expect(date!.timeIntervalSince1970 == 0) // Unix epoch
    }

    @Test func formatDetection() {
        let mbData = Self.makeMacBinary()
        #expect(ContainerCracker.identify(data: mbData) == .macBinary)

        let random = Data("not a container".utf8)
        #expect(ContainerCracker.identify(data: random) == .unknown)

        // Extension fallback
        #expect(ContainerCracker.identify(data: random, filename: "file.bin") == .macBinary)
        #expect(ContainerCracker.identify(data: random, filename: "file.hqx") == .binHex)
    }

    @Test func fullExtractViaCracker() throws {
        let data = Self.makeMacBinary(
            name: "TestFile",
            type: "TEXT",
            creator: "test",
            dataFork: Data("content".utf8)
        )
        let extracted = try ContainerCracker.extract(data: data, filename: "TestFile.bin")
        #expect(extracted != nil)
        #expect(extracted!.name == "TestFile")
        #expect(extracted!.typeCode == "TEXT")
    }
}
