import Testing
import Foundation
import CryptoKit
@testable import VaultEngine

/// Tests for adding, listing, searching, and deleting vault entries.
struct VaultEntryTests {
    private func createTempVault() throws -> (Vault, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-test-\(UUID().uuidString)")
            .appendingPathExtension("retrovault")
        let vault = try Vault.create(at: dir)
        return (vault, dir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test func addFile() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let entry = try vault.addFile(
            name: "ReadMe",
            data: Data("Hello from 1997!\r".utf8),
            typeCode: "TEXT",
            creatorCode: "ttxt"
        )

        #expect(entry.name == "ReadMe")
        #expect(entry.typeCode == "TEXT")
        #expect(entry.creatorCode == "ttxt")
        #expect(entry.dataForkSize == 17)
        #expect(entry.rsrcForkSize == 0)
        #expect(vault.entryCount == 1)

        // Data fork readable back
        let data = try vault.dataFork(for: entry.id)
        #expect(String(data: data, encoding: .utf8) == "Hello from 1997!\r")
    }

    @Test func addFileWithResourceFork() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let dataFork = Data("data fork content".utf8)
        let rsrcFork = Data([0x00, 0x00, 0x01, 0x00, 0xFF, 0xAB, 0xCD])

        let entry = try vault.addFile(
            name: "MyApp",
            data: dataFork,
            rsrc: rsrcFork,
            typeCode: "APPL",
            creatorCode: "????")

        #expect(entry.dataForkSize == Int64(dataFork.count))
        #expect(entry.rsrcForkSize == Int64(rsrcFork.count))
        #expect(entry.hasResourceFork == true)

        let readBack = try vault.rsrcFork(for: entry.id)
        #expect(readBack == rsrcFork)
    }

    @Test func addDirectory() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let folderID = try vault.addDirectory(name: "Applications")
        let entries = try vault.entries()

        #expect(entries.count == 1)
        #expect(entries[0].id == folderID)
        #expect(entries[0].name == "Applications")
        #expect(entries[0].isDirectory == true)
    }

    @Test func nestedDirectories() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let parentID = try vault.addDirectory(name: "System Folder")
        let childID = try vault.addDirectory(name: "Extensions", parentID: parentID)

        let children = try vault.entries(parentID: parentID)
        #expect(children.count == 1)
        #expect(children[0].id == childID)
        #expect(children[0].name == "Extensions")
    }

    @Test func listRootEntries() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        try vault.addFile(name: "File1", data: Data("a".utf8))
        try vault.addFile(name: "File2", data: Data("b".utf8))
        let folderID = try vault.addDirectory(name: "Folder")
        try vault.addFile(name: "Nested", data: Data("c".utf8), parentID: folderID)

        let root = try vault.entries()
        // Root should have 3 items (File1, File2, Folder) — not Nested
        #expect(root.count == 3)
        // Directories sort first
        #expect(root[0].isDirectory == true)
        #expect(root[0].name == "Folder")
    }

    @Test func listChildEntries() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let folderID = try vault.addDirectory(name: "Apps")
        try vault.addFile(name: "SimpleText", data: Data("hi".utf8), parentID: folderID)
        try vault.addFile(name: "TeachText", data: Data("hey".utf8), parentID: folderID)

        let children = try vault.entries(parentID: folderID)
        #expect(children.count == 2)
        let names = children.map(\.name).sorted()
        #expect(names == ["SimpleText", "TeachText"])
    }

    @Test func deleteEntry() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let entry = try vault.addFile(name: "Trash Me", data: Data("bye".utf8))
        #expect(vault.entryCount == 1)

        try vault.delete(id: entry.id)
        #expect(vault.entryCount == 0)

        // File on disk should be gone too
        let filePath = dir.appendingPathComponent("files/\(entry.id)/data")
        #expect(!FileManager.default.fileExists(atPath: filePath.path))
    }

    @Test func searchByName() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        try vault.addFile(name: "SimpleText", data: Data("a".utf8))
        try vault.addFile(name: "TeachText", data: Data("b".utf8))
        try vault.addFile(name: "ResEdit", data: Data("c".utf8))

        let results = try vault.search(query: "Text")
        let names = results.map(\.name).sorted()
        #expect(names == ["SimpleText", "TeachText"])
    }

    @Test func checksums() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let data = Data("checksum test".utf8)
        let entry = try vault.addFile(name: "Test", data: data)

        #expect(entry.dataChecksum != nil)
        #expect(entry.dataChecksum!.count == 64) // SHA-256 hex = 64 chars

        // Verify it matches a fresh hash
        let expected = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #expect(entry.dataChecksum == expected)
    }

    @Test func metaJsonConsistency() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        let entry = try vault.addFile(
            name: "Consistent",
            data: Data("test".utf8),
            typeCode: "TEXT",
            creatorCode: "ttxt"
        )

        // Read meta.json from disk
        let metaPath = dir
            .appendingPathComponent("files")
            .appendingPathComponent(entry.id)
            .appendingPathComponent("meta.json")
        let metaData = try Data(contentsOf: metaPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fromDisk = try decoder.decode(VaultEntry.self, from: metaData)

        // DB and meta.json should match
        #expect(fromDisk.id == entry.id)
        #expect(fromDisk.name == entry.name)
        #expect(fromDisk.typeCode == entry.typeCode)
        #expect(fromDisk.creatorCode == entry.creatorCode)
        #expect(fromDisk.dataForkSize == entry.dataForkSize)
        #expect(fromDisk.dataChecksum == entry.dataChecksum)
    }
}
