import Testing
import Foundation
@testable import ContainerCracker

/// Tests for the AppleSingle/AppleDouble parser.
struct AppleDoubleParserTests {

    /// Build a minimal AppleSingle file for testing.
    private static func makeAppleSingle(
        name: String = "Test",
        type: String = "TEXT",
        creator: String = "ttxt",
        dataFork: Data = Data("hello".utf8),
        rsrcFork: Data = Data()
    ) -> Data {
        var file = Data()

        // Header
        appendBE32(&file, 0x00051600) // AppleSingle magic
        appendBE32(&file, 0x00020000) // Version 2
        file.append(Data(repeating: 0, count: 16)) // Filler

        // Count entries: data fork (1) + resource fork (2) + real name (3) + finder info (9)
        var entryCount: UInt16 = 2 // always have name + finder info
        if !dataFork.isEmpty { entryCount += 1 }
        if !rsrcFork.isEmpty { entryCount += 1 }
        appendBE16(&file, entryCount)

        // Calculate offsets (header=26, each entry descriptor=12)
        let entryTableSize = Int(entryCount) * 12
        var dataOffset = 26 + entryTableSize

        // Build entry table + data sections
        var entries = Data()
        var payload = Data()

        // Entry: Real name (ID=3)
        let nameData = Data(name.utf8)
        appendBE32(&entries, 3) // ID
        appendBE32(&entries, UInt32(dataOffset)) // offset
        appendBE32(&entries, UInt32(nameData.count)) // length
        payload.append(nameData)
        dataOffset += nameData.count

        // Entry: Finder info (ID=9, 32 bytes)
        var finderInfo = Data(repeating: 0, count: 32)
        // Type at offset 0, creator at offset 4
        let typeBytes = Array(type.utf8.prefix(4))
        let creatorBytes = Array(creator.utf8.prefix(4))
        for (i, b) in typeBytes.enumerated() { finderInfo[i] = b }
        for (i, b) in creatorBytes.enumerated() { finderInfo[4 + i] = b }

        appendBE32(&entries, 9)
        appendBE32(&entries, UInt32(dataOffset))
        appendBE32(&entries, 32)
        payload.append(finderInfo)
        dataOffset += 32

        // Entry: Data fork (ID=1)
        if !dataFork.isEmpty {
            appendBE32(&entries, 1)
            appendBE32(&entries, UInt32(dataOffset))
            appendBE32(&entries, UInt32(dataFork.count))
            payload.append(dataFork)
            dataOffset += dataFork.count
        }

        // Entry: Resource fork (ID=2)
        if !rsrcFork.isEmpty {
            appendBE32(&entries, 2)
            appendBE32(&entries, UInt32(dataOffset))
            appendBE32(&entries, UInt32(rsrcFork.count))
            payload.append(rsrcFork)
        }

        file.append(entries)
        file.append(payload)
        return file
    }

    private static func appendBE32(_ data: inout Data, _ v: UInt32) {
        data.append(UInt8((v >> 24) & 0xFF))
        data.append(UInt8((v >> 16) & 0xFF))
        data.append(UInt8((v >> 8) & 0xFF))
        data.append(UInt8(v & 0xFF))
    }

    private static func appendBE16(_ data: inout Data, _ v: UInt16) {
        data.append(UInt8((v >> 8) & 0xFF))
        data.append(UInt8(v & 0xFF))
    }

    // MARK: - Tests

    @Test func detectAppleSingle() {
        let data = Self.makeAppleSingle()
        #expect(AppleDoubleParser.canParse(data) == true)
        #expect(ContainerCracker.identify(data: data) == .appleSingle)
    }

    @Test func parseAppleSingle() throws {
        let data = Self.makeAppleSingle(
            name: "MyFile",
            type: "TEXT",
            creator: "ttxt",
            dataFork: Data("content".utf8),
            rsrcFork: Data([0xCA, 0xFE])
        )
        let result = try AppleDoubleParser.parse(data)

        #expect(result.realName == "MyFile")
        #expect(result.dataFork == Data("content".utf8))
        #expect(result.rsrcFork == Data([0xCA, 0xFE]))

        // Check Finder info type/creator extraction
        let (type, creator) = AppleDoubleParser.typeCreator(from: result.finderInfo!)
        #expect(type == "TEXT")
        #expect(creator == "ttxt")
    }

    @Test func rejectNonAppleDouble() {
        let random = Data("not apple double".utf8)
        #expect(AppleDoubleParser.canParse(random) == false)
    }
}
