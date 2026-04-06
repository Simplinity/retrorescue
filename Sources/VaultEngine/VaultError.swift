import Foundation

/// Errors thrown by VaultEngine operations.
public enum VaultError: LocalizedError {
    case vaultAlreadyExists(String)
    case vaultNotFound(String)
    case invalidVault(String)
    case databaseError(String)
    case fileNotFound(String)
    case ioError(String)

    public var errorDescription: String? {
        switch self {
        case .vaultAlreadyExists(let path):
            return "Vault already exists at \(path)"
        case .vaultNotFound(let path):
            return "No vault found at \(path)"
        case .invalidVault(let reason):
            return "Invalid vault: \(reason)"
        case .databaseError(let msg):
            return "Database error: \(msg)"
        case .fileNotFound(let id):
            return "File not found: \(id)"
        case .ioError(let msg):
            return "I/O error: \(msg)"
        }
    }
}
