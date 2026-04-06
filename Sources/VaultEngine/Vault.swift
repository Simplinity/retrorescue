import Foundation
import CryptoKit

/// Manages a .retrovault bundle on disk.
/// A vault is a macOS bundle (directory) containing a SQLite database,
/// per-file data/resource forks, and JSON metadata.
public final class Vault {
    public let url: URL
    private let db: SQLiteDatabase
    private let fm = FileManager.default

    private var nextID: Int

    // MARK: - Bundle paths

    private var dbPath: URL { url.appendingPathComponent("vault.sqlite") }
    private var filesDir: URL { url.appendingPathComponent("files") }
    private var manifestPath: URL { url.appendingPathComponent("manifest.json") }
    private var thumbnailsDir: URL { url.appendingPathComponent("thumbnails") }
    private var sourcesDir: URL { url.appendingPathComponent("sources") }

    private init(url: URL, db: SQLiteDatabase, nextID: Int) {
        self.url = url
        self.db = db
        self.nextID = nextID
    }

    // MARK: - Create new vault

    public static func create(at url: URL) throws -> Vault {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else {
            throw VaultError.vaultAlreadyExists(url.path)
        }
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try fm.createDirectory(
            at: url.appendingPathComponent("files"),
            withIntermediateDirectories: true
        )
        try fm.createDirectory(
            at: url.appendingPathComponent("thumbnails"),
            withIntermediateDirectories: true
        )
        try fm.createDirectory(
            at: url.appendingPathComponent("sources"),
            withIntermediateDirectories: true
        )

        // Create SQLite database
        let dbPath = url.appendingPathComponent("vault.sqlite").path
        let db = try SQLiteDatabase(path: dbPath)
        try VaultSchema.create(in: db)

        // Write manifest
        let manifest: [String: String] = [
            "version": "1",
            "app_version": VaultEngine.version,
            "created": ISO8601DateFormatter().string(from: Date()),
        ]
        let manifestData = try JSONSerialization.data(
            withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]
        )
        let manifestPath = url.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestPath)

        return Vault(url: url, db: db, nextID: 1)
    }

    // MARK: - Open existing vault

    public static func open(at url: URL) throws -> Vault {
        let fm = FileManager.default
        let dbPath = url.appendingPathComponent("vault.sqlite").path
        guard fm.fileExists(atPath: dbPath) else {
            throw VaultError.vaultNotFound(url.path)
        }
        let db = try SQLiteDatabase(path: dbPath)

        // Determine next ID from existing entries
        let maxID: Int64? = try db.scalar(
            "SELECT MAX(CAST(id AS INTEGER)) FROM entries"
        )
        let nextID = Int((maxID ?? 0) + 1)

        return Vault(url: url, db: db, nextID: nextID)
    }

    // MARK: - ID generation

    private func generateID() -> String {
        let id = String(format: "%04d", nextID)
        nextID += 1
        return id
    }

    // MARK: - Add file

    @discardableResult
    public func addFile(
        name: String,
        data: Data,
        rsrc: Data? = nil,
        typeCode: String? = nil,
        creatorCode: String? = nil,
        finderFlags: UInt16 = 0,
        labelColor: Int = 0,
        created: Date? = nil,
        modified: Date? = nil,
        encoding: String = "MacRoman",
        sourceArchive: String? = nil,
        parentID: String? = nil,
        originalPath: String = ""
    ) throws -> VaultEntry {
        let id = generateID()
        let rsrcData = rsrc ?? Data()
        let dataSHA = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let rsrcSHA = rsrcData.isEmpty ? nil :
            SHA256.hash(data: rsrcData).map { String(format: "%02x", $0) }.joined()

        // Write forks to disk
        let fileDir = filesDir.appendingPathComponent(id)
        try fm.createDirectory(at: fileDir, withIntermediateDirectories: true)
        try data.write(to: fileDir.appendingPathComponent("data"))
        try rsrcData.write(to: fileDir.appendingPathComponent("rsrc"))

        let now = Date()
        let isoFmt = ISO8601DateFormatter()

        let entry = VaultEntry(
            id: id,
            name: name,
            originalPath: originalPath,
            typeCode: typeCode,
            creatorCode: creatorCode,
            finderFlags: finderFlags,
            labelColor: labelColor,
            created: created,
            modified: modified,
            dataForkSize: Int64(data.count),
            rsrcForkSize: Int64(rsrcData.count),
            dataChecksum: dataSHA,
            rsrcChecksum: rsrcSHA,
            encoding: encoding,
            sourceArchive: sourceArchive,
            parentID: parentID,
            isDirectory: false,
            addedAt: now
        )

        // Insert into database
        try db.execute("""
            INSERT INTO entries (
                id, parent_id, is_dir, name, path, type_code, creator_code,
                finder_flags, label_color, created_at, modified_at,
                data_size, rsrc_size, data_sha256, rsrc_sha256,
                encoding, source, added_at
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, params: [
            id, parentID, 0, name, originalPath,
            typeCode, creatorCode, Int(finderFlags), labelColor,
            created.map { isoFmt.string(from: $0) },
            modified.map { isoFmt.string(from: $0) },
            Int64(data.count), Int64(rsrcData.count),
            dataSHA, rsrcSHA, encoding, sourceArchive,
            isoFmt.string(from: now),
        ])

        // Write meta.json
        let metaJSON = try JSONEncoder.iso8601Encoder.encode(entry)
        try metaJSON.write(to: fileDir.appendingPathComponent("meta.json"))

        return entry
    }

    // MARK: - Add directory

    @discardableResult
    public func addDirectory(
        name: String,
        parentID: String? = nil,
        originalPath: String = ""
    ) throws -> String {
        let id = generateID()
        let isoFmt = ISO8601DateFormatter()
        let now = isoFmt.string(from: Date())
        try db.execute("""
            INSERT INTO entries (id, parent_id, is_dir, name, path, added_at)
            VALUES (?,?,1,?,?,?)
        """, params: [id, parentID, name, originalPath, now])

        return id
    }

    // MARK: - Query entries

    public func entries(parentID: String? = nil) throws -> [VaultEntry] {
        let rows: [[String: Any?]]
        if let pid = parentID {
            rows = try db.query(
                "SELECT * FROM entries WHERE parent_id = ? ORDER BY is_dir DESC, name",
                params: [pid]
            )
        } else {
            rows = try db.query(
                "SELECT * FROM entries WHERE parent_id IS NULL ORDER BY is_dir DESC, name"
            )
        }
        return rows.map { Self.entryFromRow($0) }
    }

    public var entryCount: Int {
        (try? db.scalar("SELECT COUNT(*) FROM entries") as Int64?)?.flatMap { Int($0) } ?? 0
    }

    public func entry(id: String) throws -> VaultEntry? {
        let rows = try db.query("SELECT * FROM entries WHERE id = ?", params: [id])
        return rows.first.map { Self.entryFromRow($0) }
    }

    // MARK: - Search

    public func search(query: String) throws -> [VaultEntry] {
        let pattern = "%\(query)%"
        let rows = try db.query(
            "SELECT * FROM entries WHERE name LIKE ? OR path LIKE ? OR source LIKE ? ORDER BY name",
            params: [pattern, pattern, pattern]
        )
        return rows.map { Self.entryFromRow($0) }
    }

    // MARK: - Read forks

    public func dataFork(for id: String) throws -> Data {
        let path = filesDir.appendingPathComponent(id).appendingPathComponent("data")
        guard fm.fileExists(atPath: path.path) else {
            throw VaultError.fileNotFound(id)
        }
        return try Data(contentsOf: path)
    }

    public func rsrcFork(for id: String) throws -> Data {
        let path = filesDir.appendingPathComponent(id).appendingPathComponent("rsrc")
        guard fm.fileExists(atPath: path.path) else {
            return Data()
        }
        return try Data(contentsOf: path)
    }

    // MARK: - Delete

    public func delete(id: String) throws {
        let fileDir = filesDir.appendingPathComponent(id)
        if fm.fileExists(atPath: fileDir.path) {
            try fm.removeItem(at: fileDir)
        }
        try db.execute("DELETE FROM entries WHERE id = ?", params: [id])
    }

    // MARK: - Export

    public func export(id: String, to destination: URL) throws {
        let data = try dataFork(for: id)
        try data.write(to: destination)
    }

    // MARK: - Row mapping

    private static func entryFromRow(_ row: [String: Any?]) -> VaultEntry {
        let isoFmt = ISO8601DateFormatter()
        return VaultEntry(
            id: row["id"] as? String ?? "",
            name: row["name"] as? String ?? "",
            originalPath: row["path"] as? String ?? "",
            typeCode: row["type_code"] as? String,
            creatorCode: row["creator_code"] as? String,
            finderFlags: UInt16(row["finder_flags"] as? Int64 ?? 0),
            labelColor: Int(row["label_color"] as? Int64 ?? 0),
            created: (row["created_at"] as? String).flatMap { isoFmt.date(from: $0) },
            modified: (row["modified_at"] as? String).flatMap { isoFmt.date(from: $0) },
            dataForkSize: row["data_size"] as? Int64 ?? 0,
            rsrcForkSize: row["rsrc_size"] as? Int64 ?? 0,
            dataChecksum: row["data_sha256"] as? String,
            rsrcChecksum: row["rsrc_sha256"] as? String,
            encoding: row["encoding"] as? String ?? "MacRoman",
            sourceArchive: row["source"] as? String,
            parentID: row["parent_id"] as? String,
            isDirectory: (row["is_dir"] as? Int64 ?? 0) == 1,
            addedAt: (row["added_at"] as? String).flatMap { isoFmt.date(from: $0) } ?? Date()
        )
    }
}

// MARK: - JSON Encoder helper

extension JSONEncoder {
    static let iso8601Encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()
}
