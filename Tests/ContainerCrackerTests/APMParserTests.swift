import Testing
import Foundation
@testable import ContainerCracker

/// R6: APM parser tests — DDR, partition table, HFS partition extraction.
struct APMParserTests {

    /// Build a minimal APM disk image with DDR + 1 partition entry.
    private static func makeAPM(partType: String = "Apple_HFS",
                                partName: String = "Macintosh",
                                partStart: UInt32 = 64,
                                partBlocks: UInt32 = 200) -> Data {
        var data = Data(repeating: 0, count: Int(partStart + partBlocks) * 512)
        // Block 0: DDR — signature 'ER'
        data[0] = 0x45; data[1] = 0x52  // 'ER'
        data[2] = 0x02; data[3] = 0x00  // blockSize = 512
        // Block 1: Partition entry — signature 'PM'
        let off = 512
        data[off] = 0x50; data[off+1] = 0x4D  // 'PM'
        // mapBlockCount = 1
        data[off+7] = 1
        // startBlock
        data[off+8] = UInt8((partStart >> 24) & 0xFF)
        data[off+9] = UInt8((partStart >> 16) & 0xFF)
        data[off+10] = UInt8((partStart >> 8) & 0xFF)
        data[off+11] = UInt8(partStart & 0xFF)
        // blockCount
        data[off+12] = UInt8((partBlocks >> 24) & 0xFF)
        data[off+13] = UInt8((partBlocks >> 16) & 0xFF)
        data[off+14] = UInt8((partBlocks >> 8) & 0xFF)
        data[off+15] = UInt8(partBlocks & 0xFF)
        // partName at offset 16 (32 bytes)
        let nameBytes = Array(partName.utf8.prefix(31))
        for (i, b) in nameBytes.enumerated() { data[off+16+i] = b }
        // partType at offset 48 (32 bytes)
        let typeBytes = Array(partType.utf8.prefix(31))
        for (i, b) in typeBytes.enumerated() { data[off+48+i] = b }
        return data
    }

    @Test func detectAPM() {
        let data = Self.makeAPM()
        #expect(APMParser.isAPM(data))
    }

    @Test func rejectNonAPM() {
        let data = Data(repeating: 0, count: 2048)
        #expect(!APMParser.isAPM(data))
    }

    @Test func parseDDR() {
        let data = Self.makeAPM()
        let ddr = APMParser.parseDDR(data)
        #expect(ddr.signature == 0x4552)
        #expect(ddr.blockSize == 512)
    }

    @Test func parsePartitions() throws {
        let data = Self.makeAPM(partType: "Apple_HFS", partName: "TestVol")
        let parts = try APMParser.parsePartitions(data)
        #expect(parts.count == 1)
        #expect(parts[0].type == "Apple_HFS")
        #expect(parts[0].name == "TestVol")
        #expect(parts[0].isHFS)
        #expect(!parts[0].isFree)
    }

    @Test func partitionClampedToDataSize() throws {
        // Create APM with partition claiming 99999 blocks but data only has 300 blocks total
        var data = Self.makeAPM(partStart: 64, partBlocks: 99999)
        // Truncate to only 300 blocks (153600 bytes)
        data = Data(data.prefix(300 * 512))
        let parts = try APMParser.parsePartitions(data)
        #expect(!parts.isEmpty)
        #expect(parts[0].blockCount < 99999)
        #expect(parts[0].blockCount <= 300 - 64)  // clamped to available space
    }

    @Test func macTSDetection() {
        var data = Data(repeating: 0, count: 2048)
        data[0] = 0x45; data[1] = 0x52  // 'ER'
        data[512] = 0x54; data[513] = 0x53  // 'TS'
        #expect(MacTSParser.isMacTS(data))
        #expect(!APMParser.isAPM(data))  // TS is not APM
    }
}
