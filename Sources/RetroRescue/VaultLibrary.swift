import Foundation

/// Persists a list of known vaults and their last-opened dates.
/// Stored in UserDefaults, validates paths on load.
final class VaultLibrary: ObservableObject {
    static let shared = VaultLibrary()

    @Published var vaults: [KnownVault] = []

    private let key = "com.simplinity.retrorescue.knownVaults"

    struct KnownVault: Identifiable, Codable {
        var id: String { path }
        let path: String
        let name: String
        var lastOpened: Date
        var exists: Bool { FileManager.default.fileExists(atPath: path) }
    }

    private init() {
        load()
    }

    func register(url: URL) {
        let path = url.path
        let name = url.deletingPathExtension().lastPathComponent

        // Update if already known, otherwise add
        if let idx = vaults.firstIndex(where: { $0.path == path }) {
            vaults[idx].lastOpened = Date()
        } else {
            vaults.insert(KnownVault(path: path, name: name, lastOpened: Date()), at: 0)
        }
        save()
    }

    func remove(path: String) {
        vaults.removeAll { $0.path == path }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([KnownVault].self, from: data)
        else { return }
        // Sort by last opened, filter out stale entries older than 1 year
        let cutoff = Date().addingTimeInterval(-365 * 24 * 3600)
        vaults = decoded
            .filter { $0.lastOpened > cutoff }
            .sorted { $0.lastOpened > $1.lastOpened }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(vaults) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
