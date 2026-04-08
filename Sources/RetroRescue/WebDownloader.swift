import Foundation
import VaultEngine

/// M1-M4: Web integration — download, extract, and store classic Mac files from URLs.
public class WebDownloader {

    public static let shared = WebDownloader()
    private let session = URLSession.shared
    private init() {}

    // MARK: - M4: Download History

    /// A record of a downloaded URL.
    public struct DownloadRecord: Codable {
        public var url: String
        public var filename: String
        public var date: Date
        public var vaultEntryID: String?
        public var source: String?  // "macintoshgarden", "macintoshrepository", "direct"
    }

    /// Load download history from vault.
    public func loadHistory(vault: Vault) -> [DownloadRecord] {
        let historyURL = vault.url.appendingPathComponent("download-history.json")
        guard let data = try? Data(contentsOf: historyURL),
              let records = try? JSONDecoder().decode([DownloadRecord].self, from: data)
        else { return [] }
        return records
    }

    /// Save a download record to vault history.
    private func saveRecord(_ record: DownloadRecord, vault: Vault) {
        var history = loadHistory(vault: vault)
        history.append(record)
        let historyURL = vault.url.appendingPathComponent("download-history.json")
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyURL)
        }
    }

    /// Check if a URL has already been downloaded to this vault.
    public func alreadyDownloaded(url: String, vault: Vault) -> Bool {
        loadHistory(vault: vault).contains { $0.url == url }
    }

    // MARK: - M2: Content-Disposition Header Parsing

    /// Extract filename from Content-Disposition header.
    /// Handles: `attachment; filename="System 7.5.3.sit"` and `filename*=UTF-8''encoded%20name`
    public static func parseContentDisposition(_ header: String) -> String? {
        // Try filename*= (RFC 5987, UTF-8 encoded)
        if let range = header.range(of: "filename\\*=(?:UTF-8|utf-8)''(.+?)(?:;|$)",
                                    options: .regularExpression) {
            let encoded = String(header[range]).components(separatedBy: "''").last ?? ""
            let clean = encoded.trimmingCharacters(in: .whitespaces.union(.init(charactersIn: ";\"")))
            return clean.removingPercentEncoding ?? clean
        }
        // Try filename= (standard)
        if let range = header.range(of: "filename=\"([^\"]+)\"", options: .regularExpression) {
            let match = String(header[range])
            return match.replacingOccurrences(of: "filename=\"", with: "")
                       .replacingOccurrences(of: "\"", with: "")
        }
        // Try unquoted filename=
        if let range = header.range(of: "filename=([^;\\s]+)", options: .regularExpression) {
            let match = String(header[range])
            return match.replacingOccurrences(of: "filename=", with: "")
                       .trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    // MARK: - M1: Download + Extract + Store

    /// Download a URL, extract if archive, and store in vault.
    /// Returns the vault entry ID of the imported file.
    public func downloadAndImport(
        url: URL, vault: Vault,
        progress: ((String, Double) -> Void)? = nil
    ) async throws -> String {
        progress?("Downloading \(url.lastPathComponent)…", 0.1)

        // Check if already downloaded
        if alreadyDownloaded(url: url.absoluteString, vault: vault) {
            throw WebDownloadError.alreadyDownloaded(url.absoluteString)
        }

        // Download the file
        let (tempURL, response) = try await session.download(from: url)
        let httpResponse = response as? HTTPURLResponse

        // M2: Determine filename from Content-Disposition > URL path > fallback
        var filename = url.lastPathComponent
        if let cd = httpResponse?.value(forHTTPHeaderField: "Content-Disposition"),
           let parsed = Self.parseContentDisposition(cd) {
            filename = parsed
        }
        // Clean up filename
        filename = filename.removingPercentEncoding ?? filename
        if filename.isEmpty || filename == "/" { filename = "download" }

        progress?("Importing \(filename)…", 0.5)

        // Move to a location with the correct filename
        let destDir = FileManager.default.temporaryDirectory.appendingPathComponent("retrorescue-dl")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        // Import into vault
        progress?("Storing in vault…", 0.8)
        let data = try Data(contentsOf: destURL)
        let entry = try vault.addFile(
            name: filename, data: data,
            sourceArchive: url.absoluteString
        )

        // M4: Record download in history
        let record = DownloadRecord(
            url: url.absoluteString, filename: filename,
            date: Date(), vaultEntryID: entry.id,
            source: detectSource(url: url))
        saveRecord(record, vault: vault)

        progress?("Done", 1.0)
        return entry.id
    }

    private func detectSource(url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("macintoshgarden") { return "macintoshgarden" }
        if host.contains("macintoshrepository") { return "macintoshrepository" }
        return "direct"
    }

    // MARK: - M3: Macintosh Garden / Repository Scraper

    /// Metadata scraped from a Mac software archive page.
    public struct SoftwareInfo {
        public var title: String
        public var description: String?
        public var downloadURLs: [URL]
        public var category: String?
        public var year: String?
        public var source: String  // "macintoshgarden" or "macintoshrepository"
    }

    /// Scrape software info from a Macintosh Garden page URL.
    /// Extracts title, description, and download links.
    public func scrapeMacintoshGarden(pageURL: URL) async throws -> SoftwareInfo {
        let (data, _) = try await session.data(from: pageURL)
        let html = String(data: data, encoding: .utf8) ?? ""

        // Extract title: <h1 class="title">...</h1> or <title>...</title>
        let title = extractBetween(html, start: "<h1", end: "</h1>")
            .flatMap { extractBetween("<h1" + $0 + "</h1>", start: ">", end: "</") }
            ?? extractBetween(html, start: "<title>", end: "</title>")
            ?? pageURL.lastPathComponent

        // Extract description from meta or content div
        let desc = extractBetween(html, start: "name=\"description\" content=\"", end: "\"")

        // Extract download links: look for href containing file extensions
        let downloadExts = ["sit", "hqx", "bin", "img", "dsk", "sea", "cpt", "zip", "dmg", "smi", "toast"]
        var downloadURLs: [URL] = []
        let hrefPattern = "href=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: hrefPattern) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let href = String(html[range])
                    let hrefLower = href.lowercased()
                    if downloadExts.contains(where: { hrefLower.hasSuffix(".\($0)") }) {
                        if let dlURL = URL(string: href, relativeTo: pageURL)?.absoluteURL {
                            downloadURLs.append(dlURL)
                        }
                    }
                }
            }
        }

        return SoftwareInfo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: desc, downloadURLs: downloadURLs,
            category: nil, year: nil, source: "macintoshgarden")
    }

    /// Scrape software info from a Macintosh Repository page URL.
    public func scrapeMacintoshRepository(pageURL: URL) async throws -> SoftwareInfo {
        let (data, _) = try await session.data(from: pageURL)
        let html = String(data: data, encoding: .utf8) ?? ""

        let title = extractBetween(html, start: "<title>", end: "</title>")
            ?? pageURL.lastPathComponent
        let desc = extractBetween(html, start: "name=\"description\" content=\"", end: "\"")

        // Repository uses direct download links, often with /download/ in path
        var downloadURLs: [URL] = []
        let hrefPattern = "href=\"([^\"]*download[^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: hrefPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let href = String(html[range])
                    if let dlURL = URL(string: href, relativeTo: pageURL)?.absoluteURL {
                        downloadURLs.append(dlURL)
                    }
                }
            }
        }

        return SoftwareInfo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: desc, downloadURLs: downloadURLs,
            category: nil, year: nil, source: "macintoshrepository")
    }

    /// Scrape any supported Mac software site.
    public func scrape(pageURL: URL) async throws -> SoftwareInfo {
        let host = pageURL.host?.lowercased() ?? ""
        if host.contains("macintoshgarden") {
            return try await scrapeMacintoshGarden(pageURL: pageURL)
        } else if host.contains("macintoshrepository") {
            return try await scrapeMacintoshRepository(pageURL: pageURL)
        }
        throw WebDownloadError.unsupportedSite(host)
    }

    // MARK: - Helpers

    private func extractBetween(_ html: String, start: String, end: String) -> String? {
        guard let startRange = html.range(of: start) else { return nil }
        let after = html[startRange.upperBound...]
        guard let endRange = after.range(of: end) else { return nil }
        return String(after[..<endRange.lowerBound])
    }
}

// MARK: - Errors

public enum WebDownloadError: LocalizedError {
    case alreadyDownloaded(String)
    case unsupportedSite(String)
    case downloadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyDownloaded(let url): return "Already downloaded: \(url)"
        case .unsupportedSite(let host): return "Unsupported site: \(host). Supported: macintoshgarden.org, macintoshrepository.org"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        }
    }
}
