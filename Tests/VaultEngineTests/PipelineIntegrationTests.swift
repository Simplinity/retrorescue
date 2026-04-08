import Testing
import Foundation
@testable import VaultEngine
@testable import ContainerCracker

/// R11: Integration tests — full pipeline from import to extract to preview.
struct PipelineIntegrationTests {

    /// Create a temp vault for testing.
    private static func makeTempVault() throws -> Vault {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-test-\(UUID().uuidString)")
            .appendingPathExtension("retrovault")
        return try Vault.create(at: tempDir)
    }

    @Test func importAndRetrieveFile() throws {
        let vault = try Self.makeTempVault()
        defer { try? FileManager.default.removeItem(at: vault.url) }

        let testData = Data("Hello, RetroRescue!".utf8)
        let entry = try vault.addFile(name: "test.txt", data: testData)

        let retrieved = try vault.dataFork(for: entry.id)
        #expect(retrieved == testData)
        #expect(entry.name == "test.txt")
    }


    @Test func importWithResourceFork() throws {
        let vault = try Self.makeTempVault()
        defer { try? FileManager.default.removeItem(at: vault.url) }

        let data = Data("data fork content".utf8)
        let rsrc = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let entry = try vault.addFile(name: "test.rsrc", data: data, rsrc: rsrc,
                                      typeCode: "TEXT", creatorCode: "ttxt")

        let readData = try vault.dataFork(for: entry.id)
        let readRsrc = try vault.rsrcFork(for: entry.id)
        #expect(readData == data)
        #expect(readRsrc == rsrc)
        #expect(entry.typeCode == "TEXT")
        #expect(entry.creatorCode == "ttxt")
    }

    @Test func parentChildRelationship() throws {
        let vault = try Self.makeTempVault()
        defer { try? FileManager.default.removeItem(at: vault.url) }

        let parent = try vault.addFile(name: "archive.sit", data: Data("archive".utf8))
        let child = try vault.addFile(name: "readme.txt", data: Data("hello".utf8),
                                      parentID: parent.id)

        let children = try vault.entries(parentID: parent.id)
        #expect(children.count == 1)
        #expect(children[0].id == child.id)
        #expect(children[0].name == "readme.txt")
    }

    @Test func thumbnailStorage() throws {
        let vault = try Self.makeTempVault()
        defer { try? FileManager.default.removeItem(at: vault.url) }

        let entry = try vault.addFile(name: "icon.rsrc", data: Data("test".utf8))

        #expect(!vault.hasThumbnail(for: entry.id))

        let pngData = Data([0x89, 0x50, 0x4E, 0x47])  // fake PNG header
        try vault.setThumbnail(for: entry.id, pngData: pngData)

        #expect(vault.hasThumbnail(for: entry.id))
        #expect(vault.thumbnail(for: entry.id) == pngData)

        vault.deleteThumbnail(for: entry.id)
        #expect(!vault.hasThumbnail(for: entry.id))
    }

    @Test func deleteAllThumbnails() throws {
        let vault = try Self.makeTempVault()
        defer { try? FileManager.default.removeItem(at: vault.url) }

        let e1 = try vault.addFile(name: "a.txt", data: Data("a".utf8))
        let e2 = try vault.addFile(name: "b.txt", data: Data("b".utf8))
        try vault.setThumbnail(for: e1.id, pngData: Data([0x01]))
        try vault.setThumbnail(for: e2.id, pngData: Data([0x02]))

        let removed = vault.deleteAllThumbnails()
        #expect(removed == 2)
        #expect(!vault.hasThumbnail(for: e1.id))
    }

    @Test func deleteRemovesFromVault() throws {
        let vault = try Self.makeTempVault()
        defer { try? FileManager.default.removeItem(at: vault.url) }

        let entry = try vault.addFile(name: "delete-me.txt", data: Data("bye".utf8))
        var all = try vault.entries()
        #expect(all.count == 1)

        try vault.delete(id: entry.id)
        all = try vault.entries()
        #expect(all.isEmpty)
    }

    @Test func macBinaryUnwrapIntegration() throws {
        // Build a minimal MacBinary, import it, verify unwrapping
        var header = Data(repeating: 0, count: 128)
        let name = "TestFile"
        header[1] = UInt8(name.count)
        for (i, b) in name.utf8.enumerated() { header[2 + i] = b }
        // Type "TEXT", Creator "ttxt"
        for (i, b) in "TEXT".utf8.enumerated() { header[65 + i] = b }
        for (i, b) in "ttxt".utf8.enumerated() { header[69 + i] = b }
        // Data fork: 5 bytes
        header[86] = 5
        // Version byte 122 = 129 (MacBinary II)
        header[122] = 129
        var macbin = header
        macbin.append(Data("hello".utf8))
        macbin.append(Data(repeating: 0, count: 512 - 5))  // pad to 512

        // Try to unwrap
        let unwrapped = try? ContainerCracker.extract(data: macbin, filename: "test.bin")
        #expect(unwrapped != nil)
        #expect(unwrapped?.typeCode == "TEXT")
        #expect(unwrapped?.dataFork == Data("hello".utf8))
    }
}
