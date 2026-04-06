import Testing
import Foundation
@testable import VaultEngine

/// Integration tests: end-to-end workflows without UI.
struct VaultIntegrationTests {
    private func createTempVault() throws -> (Vault, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-int-\(UUID().uuidString)")
            .appendingPathExtension("retrovault")
        let vault = try Vault.create(at: dir)
        return (vault, dir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test func createPopulateReopenBrowse() throws {
        let (vault, dir) = try createTempVault()
        defer { cleanup(dir) }

        // Populate
        let folderID = try vault.addDirectory(name: "System Folder")
        try vault.addFile(
            name: "Finder",
            data: Data("finder data".utf8),
            rsrc: Data([0x00, 0x00, 0x01, 0x00]),
            typeCode: "APPL",
            creatorCode: "MACS",
            parentID: folderID
        )
        try vault.addFile(
            name: "ReadMe",
            data: Data("Hello\r".utf8),
            typeCode: "TEXT",
            creatorCode: "ttxt"
        )

        // Reopen
        let reopened = try Vault.open(at: dir)

        // Browse root — should have folder + ReadMe
        let root = try reopened.entries()
        #expect(root.count == 2)
        #expect(root[0].isDirectory == true) // folders sort first
        #expect(root[0].name == "System Folder")

        // Browse inside folder
        let children = try reopened.entries(parentID: root[0].id)
        #expect(children.count == 1)
        #expect(children[0].name == "Finder")
        #expect(children[0].typeCode == "APPL")

        // Read data back
        let data = try reopened.dataFork(for: children[0].id)
        #expect(String(data: data, encoding: .utf8) == "finder data")

        // Read resource fork
        let rsrc = try reopened.rsrcFork(for: children[0].id)
        #expect(rsrc == Data([0x00, 0x00, 0x01, 0x00]))
    }

    @Test func vaultSurvivesCopy() throws {
        let (vault, dir) = try createTempVault()
        let copyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-copy-\(UUID().uuidString)")
            .appendingPathExtension("retrovault")
        defer { cleanup(dir); cleanup(copyDir) }

        // Populate with diverse content
        try vault.addFile(
            name: "Icon",
            data: Data(repeating: 0xAA, count: 128),
            rsrc: Data(repeating: 0xBB, count: 256),
            typeCode: "ICON",
            creatorCode: "test"
        )
        try vault.addFile(
            name: "Text",
            data: Data("caf\u{00E9}".utf8),
            typeCode: "TEXT"
        )

        // Copy entire vault bundle
        try FileManager.default.copyItem(at: dir, to: copyDir)

        // Open the copy
        let copied = try Vault.open(at: copyDir)

        let entries = try copied.entries()
        #expect(entries.count == 2)

        // Find the icon entry
        let icon = entries.first { $0.typeCode == "ICON" }!
        let iconData = try copied.dataFork(for: icon.id)
        #expect(iconData == Data(repeating: 0xAA, count: 128))
        let iconRsrc = try copied.rsrcFork(for: icon.id)
        #expect(iconRsrc == Data(repeating: 0xBB, count: 256))

        // Find the text entry
        let text = entries.first { $0.typeCode == "TEXT" }!
        let textData = try copied.dataFork(for: text.id)
        #expect(String(data: textData, encoding: .utf8) == "café")
    }
}
