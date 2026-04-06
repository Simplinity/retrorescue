import Testing
import Foundation
@testable import ContainerCracker

struct AppleDoubleParserTests {

    /// Build a minimal AppleSingle file with data fork, rsrc fork, and Finder info.
    private static func makeAppleSingle(
        dataFork: Data = Data("data".utf8),
        rsrcFork: Data = Data([0xDE, 0xAD]),
        type: String = "TEXT",
        creator: String = "ttxt"
    ) -> Data {
        // AppleSingle header: magic(4) + version(4) + filler(16) + entryCount(2)
        var file = Data()
        // Magic: 0x00051600
        file.append(contentsOf: [0x00, 0x05, 0x16, 0x00])
        // Version: 0x00020000
        file.append(contentsOf: [0x00, 0x02, 0x00, 0x00])
        // Filler: 16 zero bytes
        file.append(Data(repeating: 0, count: 16))
        // Entry count: 3 (data fork, rsrc fork, Finder info)
        file.append(contentsOf: [0x00, 0x03])

        // Entry table starts at offset 26, each entry is 12 bytes
        // Entries start after: 26 + 3*12 = 62
        let finderOffset: UInt32 = 62
        let finderLen: UInt32 = 32
        let dataOffset = finderOffset + finderLen
        let dataLen = UInt32(dataFork.count)
        let rsrcOffset = dataOffset + dataLen
        let rsrcLen = UInt32(rsrcFork.count)

        // Entry 1: Finder info (ID=9)
        file.append(contentsOf: toBE32(9))
        file.append(contentsOf: toBE32(finderOffset))
        file.append(contentsOf: toBE32(finderLen))
        // Entry 2: Data fork (ID=1)
        file.append(contentsOf: toBE32(1))
        file.append(contentsOf: toBE32(dataOffset))
        file.append(contentsOf: toBE32(dataLen))
        // Entry 3: Resource fork (ID=2)
        file.append(contentsOf: toBE32(2))
        file.append(contentsOf: toBE32(rsrcOffset))
        file.append(contentsOf: toBE32(rsrcLen))

        // Finder info: type(4) + creator(4) + flags(2) + padding(22)
        var finder = Data(repeating: 0, count: 32)
        let tb = Array(type.utf8.prefix(4))
        let cb = Array(creator.utf8.prefix(4))
        for (i, b) in tb.enumerated() { finder[i] = b }
        for (i, b) in cb.enumerated() { finder[4 + i] = b }
        file.append(finder)

        // Data fork
        file.append(dataFork)
        // Resource fork
        file.append(rsrcFork)

        return file
    }

    private static func toBE32(_ v: UInt32) -> [UInt8] {
        [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF),
         UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    @Test func detectAppleSingle() {
        let data = Self.makeAppleSingle()
        #expect(AppleDoubleParser.canParse(data) == true)
        #expect(ContainerCracker.identify(data: data) == .appleSingle)
    }

    @Test func parseAppleSingle() throws {
        let data = Self.makeAppleSingle(
            dataFork: Data("content".utf8),
            rsrcFork: Data([0xCA, 0xFE]),
            type: "APPL",
            creator: "TEST"
        )
        let result = try AppleDoubleParser.parse(data)

        #expect(result.dataFork == Data("content".utf8))
        #expect(result.rsrcFork == Data([0xCA, 0xFE]))

        // Check Finder info extraction
        let (type, creator) = AppleDoubleParser.typeCreator(from: result.finderInfo!)
        #expect(type == "APPL")
        #expect(creator == "TEST")
    }
}
