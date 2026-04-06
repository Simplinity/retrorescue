import Foundation
import AppKit
import Quartz
import VaultEngine

/// Handles previewing and opening vault files using macOS APIs.
enum FilePreviewHelper {

    /// File extensions that macOS can natively Quick Look / open.
    static let quickLookable: Set<String> = [
        "pdf", "txt", "rtf", "rtfd", "md", "markdown",
        "html", "htm", "css", "js", "json", "xml", "csv",
        "c", "h", "m", "swift", "py", "rb", "sh", "pl",
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp",
        "heic", "webp", "svg", "ico",
        "mp3", "aiff", "aif", "wav", "m4a", "aac",
        "mp4", "mov", "m4v", "avi",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "pages", "numbers", "keynote",
    ]

    /// Text-based formats we can preview inline.
    static let textPreviewable: Set<String> = [
        "txt", "rtf", "md", "markdown", "text",
        "html", "htm", "css", "js", "json", "xml", "csv",
        "c", "h", "m", "swift", "py", "rb", "sh", "pl",
        "yaml", "yml", "toml", "ini", "cfg", "conf",
        "log", "readme",
    ]

    /// Classic Mac type codes that are text-based.
    static let textTypeCodes: Set<String> = ["TEXT", "ttro", "sEXT", "utxt"]

    /// Check if a file can be previewed as text.
    static func isTextPreviewable(entry: VaultEntry) -> Bool {
        if let type = entry.typeCode, textTypeCodes.contains(type) { return true }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        return textPreviewable.contains(ext)
    }

    /// Check if a file can be Quick Looked.
    static func isQuickLookable(entry: VaultEntry) -> Bool {
        let ext = (entry.name as NSString).pathExtension.lowercased()
        return quickLookable.contains(ext) || isTextPreviewable(entry: entry)
    }

    /// Write a vault file to a temp location for preview/open.
    static func writeTempFile(vault: Vault, entry: VaultEntry) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-preview")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent(entry.name)
        let data = try vault.dataFork(for: entry.id)
        try data.write(to: tempURL)
        return tempURL
    }

    /// Open a file in the default macOS app.
    static func openInDefaultApp(vault: Vault, entry: VaultEntry) {
        guard let url = try? writeTempFile(vault: vault, entry: entry) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Read the text content of a file (MacRoman or UTF-8).
    static func readTextContent(vault: Vault, entry: VaultEntry) -> String? {
        guard let data = try? vault.dataFork(for: entry.id) else { return nil }
        // Try UTF-8 first, then MacRoman
        if let text = String(data: data, encoding: .utf8) {
            return text.replacingOccurrences(of: "\r\n", with: "\n")
                       .replacingOccurrences(of: "\r", with: "\n")
        }
        if let text = String(data: data, encoding: .macOSRoman) {
            return text.replacingOccurrences(of: "\r\n", with: "\n")
                       .replacingOccurrences(of: "\r", with: "\n")
        }
        return nil
    }
}
