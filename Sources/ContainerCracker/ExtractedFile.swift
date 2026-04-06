import Foundation
import VaultEngine

/// Result of extracting a file from a classic Mac container.
public struct ExtractedFile {
    public var name: String
    public var dataFork: Data
    public var rsrcFork: Data
    public var typeCode: String?
    public var creatorCode: String?
    public var finderFlags: UInt16
    public var created: Date?
    public var modified: Date?

    public init(
        name: String,
        dataFork: Data,
        rsrcFork: Data = Data(),
        typeCode: String? = nil,
        creatorCode: String? = nil,
        finderFlags: UInt16 = 0,
        created: Date? = nil,
        modified: Date? = nil
    ) {
        self.name = name
        self.dataFork = dataFork
        self.rsrcFork = rsrcFork
        self.typeCode = typeCode
        self.creatorCode = creatorCode
        self.finderFlags = finderFlags
        self.created = created
        self.modified = modified
    }
}

/// Errors from container parsing.
public enum ContainerError: LocalizedError {
    case invalidFormat(String)
    case corruptedData(String)
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let msg): return "Invalid format: \(msg)"
        case .corruptedData(let msg): return "Corrupted data: \(msg)"
        case .unsupportedFormat(let msg): return "Unsupported format: \(msg)"
        }
    }
}
