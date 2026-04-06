import Foundation

/// A single file or directory stored in a .retrovault bundle.
public struct VaultEntry: Identifiable, Codable, Sendable {
    public let id: String
    public var name: String
    public var originalPath: String
    public var typeCode: String?
    public var creatorCode: String?
    public var finderFlags: UInt16
    public var labelColor: Int
    public var created: Date?
    public var modified: Date?
    public var dataForkSize: Int64
    public var rsrcForkSize: Int64
    public var dataChecksum: String?
    public var rsrcChecksum: String?
    public var encoding: String
    public var sourceArchive: String?
    public var parentID: String?
    public var isDirectory: Bool
    public var addedAt: Date

    public init(
        id: String,
        name: String,
        originalPath: String = "",
        typeCode: String? = nil,
        creatorCode: String? = nil,
        finderFlags: UInt16 = 0,
        labelColor: Int = 0,
        created: Date? = nil,
        modified: Date? = nil,
        dataForkSize: Int64 = 0,
        rsrcForkSize: Int64 = 0,
        dataChecksum: String? = nil,
        rsrcChecksum: String? = nil,
        encoding: String = "MacRoman",
        sourceArchive: String? = nil,
        parentID: String? = nil,
        isDirectory: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.originalPath = originalPath
        self.typeCode = typeCode
        self.creatorCode = creatorCode
        self.finderFlags = finderFlags
        self.labelColor = labelColor
        self.created = created
        self.modified = modified
        self.dataForkSize = dataForkSize
        self.rsrcForkSize = rsrcForkSize
        self.dataChecksum = dataChecksum
        self.rsrcChecksum = rsrcChecksum
        self.encoding = encoding
        self.sourceArchive = sourceArchive
        self.parentID = parentID
        self.isDirectory = isDirectory
        self.addedAt = addedAt
    }
}

extension VaultEntry {
    /// Display string for type/creator (e.g. "TEXT/ttxt")
    public var typeCreatorDisplay: String? {
        guard let type = typeCode else { return nil }
        if let creator = creatorCode {
            return "\(type)/\(creator)"
        }
        return type
    }

    /// Whether this file has a resource fork
    public var hasResourceFork: Bool {
        rsrcForkSize > 0
    }
}
