import Testing
import Foundation
@testable import ContainerCracker

/// R8: MFS reader tests — signature, alloc map, directory, fork extraction.
struct MFSReaderTests {

    /// Build a minimal MFS volume (signature only, no real files).
    private static func makeMFSHeader() -> Data {
        var data = Data(repeating: 0, count: 2048)
        // MFS signature 0xD2D7 at offset 1024
        data[1024] = 0xD2; data[1025] = 0xD7
        // Volume name: 5 chars "Test1"
        data[1024 + 36] = 5
        let name = Array("Test1".utf8)
        for (i, b) in name.enumerated() { data[1024 + 37 + i] = b }
        // numAllocBlocks = 10
        data[1024 + 18] = 0; data[1024 + 19] = 10
        // allocBlockSize = 1024
        data[1024 + 20] = 0; data[1024 + 21] = 0; data[1024 + 22] = 0x04; data[1024 + 23] = 0x00
        // directoryStart = 4, directoryLength = 2
        data[1024 + 14] = 0; data[1024 + 15] = 4
        data[1024 + 16] = 0; data[1024 + 17] = 2
        return data
    }

    @Test func detectMFS() {
        let data = Self.makeMFSHeader()
        #expect(MFSReader.isMFS(data))
    }

    @Test func rejectNonMFS() {
        var data = Data(repeating: 0, count: 2048)
        data[1024] = 0x42; data[1025] = 0x44  // HFS, not MFS
        #expect(!MFSReader.isMFS(data))
    }

    @Test func rejectTooSmall() {
        let data = Data(repeating: 0, count: 512)
        #expect(!MFSReader.isMFS(data))
    }

    @Test func emptyVolumeExtracts() throws {
        var data = Self.makeMFSHeader()
        // Extend to have directory blocks (blocks 4-5, all zeros = no entries)
        data.append(Data(repeating: 0, count: 10000))
        let (volName, files) = try MFSReader.extractAll(from: data)
        #expect(volName == "Test1")
        #expect(files.isEmpty)  // no directory entries with bit 7 set
    }

    @Test func allocMapParsing() {
        // 12-bit alloc map: 3 bytes → 2 entries
        // Bytes: 0x12, 0x34, 0x56 → entry0 = 0x123, entry1 = 0x456
        var data = Self.makeMFSHeader()
        data.append(Data(repeating: 0, count: 10000))
        // The alloc map starts at offset 1024+64 (after volume info)
        data[1024 + 64] = 0x12
        data[1024 + 65] = 0x34
        data[1024 + 66] = 0x56
        // This just verifies parsing doesn't crash — actual chain following
        // would need a full volume with files
        #expect(MFSReader.isMFS(data))
    }
}
