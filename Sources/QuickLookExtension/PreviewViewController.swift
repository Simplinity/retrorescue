import Cocoa
import Quartz
import WebKit
import SQLite3

/// L7: Quick Look Preview Extension for .retrovault files.
/// Shows a summary of vault contents when pressing Space in Finder.
class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!

    override func loadView() {
        webView = WKWebView()
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let dbPath = url.appendingPathComponent("vault.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            handler(NSError(domain: "RetroRescue", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Not a valid RetroVault"]))
            return
        }

        // Query vault database directly (can't use VaultEngine in extension)
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            handler(NSError(domain: "RetroRescue", code: 2,
                           userInfo: [NSLocalizedDescriptionKey: "Cannot open vault database"]))
            return
        }
        defer { sqlite3_close(db) }

        let vaultName = url.deletingPathExtension().lastPathComponent
        let totalFiles = queryInt(db, "SELECT COUNT(*) FROM entries WHERE is_dir = 0")
        let totalDirs = queryInt(db, "SELECT COUNT(*) FROM entries WHERE is_dir = 1")
        let topLevel = queryInt(db, "SELECT COUNT(*) FROM entries WHERE parent_id IS NULL")
        let totalDataSize = queryInt(db, "SELECT COALESCE(SUM(data_size), 0) FROM entries")
        let totalRsrcSize = queryInt(db, "SELECT COALESCE(SUM(rsrc_size), 0) FROM entries WHERE rsrc_size > 0")
        let filesWithRsrc = queryInt(db, "SELECT COUNT(*) FROM entries WHERE rsrc_size > 0")

        // Get top-level file names
        let topFiles = queryStrings(db,
            "SELECT name FROM entries WHERE parent_id IS NULL ORDER BY is_dir DESC, name LIMIT 25")

        // Get type code breakdown
        let typeCodes = queryPairs(db,
            "SELECT type_code, COUNT(*) FROM entries WHERE type_code IS NOT NULL AND type_code != '' GROUP BY type_code ORDER BY COUNT(*) DESC LIMIT 10")

        // Build HTML preview
        let html = buildHTML(
            vaultName: vaultName, totalFiles: totalFiles, totalDirs: totalDirs,
            topLevel: topLevel, dataSize: totalDataSize, rsrcSize: totalRsrcSize,
            filesWithRsrc: filesWithRsrc, topFiles: topFiles, typeCodes: typeCodes)

        webView.loadHTMLString(html, baseURL: nil)
        handler(nil)
    }

    // MARK: - HTML Generation

    private func buildHTML(vaultName: String, totalFiles: Int, totalDirs: Int,
                          topLevel: Int, dataSize: Int, rsrcSize: Int,
                          filesWithRsrc: Int, topFiles: [String],
                          typeCodes: [(String, String)]) -> String {
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(dataSize), countStyle: .file)
        let rsrcStr = ByteCountFormatter.string(fromByteCount: Int64(rsrcSize), countStyle: .file)

        var typeRows = ""
        for (code, count) in typeCodes {
            typeRows += "<tr><td><code>\(esc(code))</code></td><td>\(esc(count))</td></tr>"
        }

        var fileList = ""
        for name in topFiles {
            let icon = name.contains(".") ? "📄" : "📁"
            fileList += "<div class='file'>\(icon) \(esc(name))</div>"
        }

        return """
        <!DOCTYPE html>
        <html><head><style>
        body { font-family: -apple-system, sans-serif; margin: 20px; background: #f5f5f7; color: #1d1d1f; }
        h1 { font-size: 20px; margin-bottom: 4px; }
        .subtitle { color: #86868b; font-size: 13px; margin-bottom: 16px; }
        .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 16px; }
        .stat { background: white; padding: 10px 14px; border-radius: 8px; }
        .stat-num { font-size: 22px; font-weight: 600; color: #0071e3; }
        .stat-label { font-size: 11px; color: #86868b; }
        .section { font-size: 13px; font-weight: 600; margin: 12px 0 6px; color: #1d1d1f; }
        .file { font-size: 12px; padding: 2px 0; }
        table { font-size: 12px; border-collapse: collapse; width: 100%; }
        td { padding: 2px 8px; } td:first-child { font-weight: 500; }
        code { background: #e8e8ed; padding: 1px 5px; border-radius: 3px; font-size: 11px; }
        </style></head><body>
        <h1>🗄️ \(esc(vaultName))</h1>
        <div class='subtitle'>RetroVault Archive</div>
        <div class='stats'>
          <div class='stat'><div class='stat-num'>\(totalFiles)</div><div class='stat-label'>Files</div></div>
          <div class='stat'><div class='stat-num'>\(topLevel)</div><div class='stat-label'>Archives</div></div>
          <div class='stat'><div class='stat-num'>\(sizeStr)</div><div class='stat-label'>Total Size</div></div>
          <div class='stat'><div class='stat-num'>\(filesWithRsrc)</div><div class='stat-label'>With Resource Fork</div></div>
        </div>
        \(typeRows.isEmpty ? "" : "<div class='section'>Top Type Codes</div><table>\(typeRows)</table>")
        \(rsrcSize > 0 ? "<div class='section'>Resource Forks: \(rsrcStr)</div>" : "")
        <div class='section'>Contents (\(topLevel) items)</div>
        \(fileList)
        \(topFiles.count >= 25 ? "<div class='file' style='color:#86868b'>… and more</div>" : "")
        </body></html>
        """
    }

    // MARK: - SQLite Helpers

    private func queryInt(_ db: OpaquePointer?, _ sql: String) -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private func queryStrings(_ db: OpaquePointer?, _ sql: String) -> [String] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: cStr))
            }
        }
        return results
    }

    private func queryPairs(_ db: OpaquePointer?, _ sql: String) -> [(String, String)] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        var results: [(String, String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let col0 = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
            let col1 = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            results.append((col0, col1))
        }
        return results
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
