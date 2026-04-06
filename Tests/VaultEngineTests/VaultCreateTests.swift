import Testing
import Foundation
@testable import VaultEngine

/// Tests for Vault creation and opening.
struct VaultCreateTests {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-test-\(UUID().uuidString)")
    }

    @Test func createNewVault() throws {
        let dir = tempDir().appendingPathExtension("retrovault")
        defer { try? FileManager.default.removeItem(at: dir) }

        let vault = try Vault.create(at: dir)

        // Bundle structure exists
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: dir.appendingPathComponent("vault.sqlite").path))
        #expect(fm.fileExists(atPath: dir.appendingPathComponent("manifest.json").path))
        #expect(fm.fileExists(atPath: dir.appendingPathComponent("files").path))
        #expect(fm.fileExists(atPath: dir.appendingPathComponent("thumbnails").path))
        #expect(fm.fileExists(atPath: dir.appendingPathComponent("sources").path))
        _ = vault  // silence unused warning
    }

    @Test func createAtExistingPathThrows() throws {
        let dir = tempDir().appendingPathExtension("retrovault")
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try Vault.create(at: dir)

        #expect(throws: VaultError.self) {
            _ = try Vault.create(at: dir)
        }
    }

    @Test func openVault() throws {
        let dir = tempDir().appendingPathExtension("retrovault")
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try Vault.create(at: dir)

        let reopened = try Vault.open(at: dir)
        #expect(reopened.entryCount == 0)
    }

    @Test func openInvalidPathThrows() {
        let bogus = tempDir().appendingPathExtension("retrovault")
        #expect(throws: VaultError.self) {
            _ = try Vault.open(at: bogus)
        }
    }

    @Test func manifestContent() throws {
        let dir = tempDir().appendingPathExtension("retrovault")
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try Vault.create(at: dir)

        let data = try Data(contentsOf: dir.appendingPathComponent("manifest.json"))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: String]
        #expect(json["version"] == "1")
        #expect(json["app_version"] == VaultEngine.version)
        #expect(json["created"] != nil)
    }
}
