import Foundation

/// Manages all external tool dependencies for RetroRescue.
/// Checks availability at startup, prefers bundled tools over system tools.
///
/// Tool categories:
/// - System: Always present on macOS (sips, textutil, qlmanage)
/// - Bundled: Shipped inside RetroRescue.app/Contents/Resources/
/// - Homebrew: Development fallback, found in /opt/homebrew/bin/
/// - Native: Implemented in Swift (no external dependency)
@MainActor
final class ToolChain: ObservableObject {
    static let shared = ToolChain()

    // MARK: - Tool Status

    struct Tool: Identifiable {
        let id: String
        let name: String
        let purpose: String
        var path: String?
        var isAvailable: Bool { path != nil }
        var source: Source = .unavailable

        enum Source: String {
            case system = "macOS Built-in"
            case bundled = "Bundled"
            case homebrew = "Homebrew (dev)"
            case native = "Native Swift"
            case unavailable = "Not Available"
        }
    }

    @Published var tools: [String: Tool] = [:]

    // MARK: - Quick accessors

    var unar: String?      { tools["unar"]?.path }
    var sips: String?      { tools["sips"]?.path }
    var textutil: String?  { tools["textutil"]?.path }
    var qlmanage: String?  { tools["qlmanage"]?.path }
    var ffmpeg: String?    { tools["ffmpeg"]?.path }
    var hmount: String?    { tools["hmount"]?.path }
    var hcopy: String?     { tools["hcopy"]?.path }
    var hls: String?       { tools["hls"]?.path }
    var humount: String?   { tools["humount"]?.path }

    // MARK: - Feature flags

    var canExtractArchives: Bool { unar != nil }
    var canExtractHFS: Bool { hmount != nil && hcopy != nil }
    var canConvertImages: Bool { sips != nil }
    var canConvertDocuments: Bool { textutil != nil }
    var canTranscodeMedia: Bool { ffmpeg != nil }
    var canQuickLook: Bool { qlmanage != nil }

    // MARK: - Init

    private init() {
        discover()
    }

    // MARK: - Discovery

    func discover() {
        let bundle = Bundle.main.resourcePath ?? ""

        // macOS built-in tools (always present)
        register("sips", purpose: "Image conversion (PICT→PNG, resize)",
                 system: "/usr/bin/sips")
        register("textutil", purpose: "Document conversion (RTF/DOC→TXT)",
                 system: "/usr/bin/textutil")
        register("qlmanage", purpose: "Quick Look preview",
                 system: "/usr/bin/qlmanage")

        // Archive extraction
        register("unar", purpose: "Archive extraction (StuffIt, ZIP, RAR, 7z, etc.)",
                 bundled: "\(bundle)/unar",
                 homebrew: "/opt/homebrew/bin/unar")

        // HFS disk image tools
        register("hmount", purpose: "Mount HFS disk images",
                 bundled: "\(bundle)/hmount",
                 homebrew: "/opt/homebrew/bin/hmount")
        register("hls", purpose: "List HFS volume contents",
                 bundled: "\(bundle)/hls",
                 homebrew: "/opt/homebrew/bin/hls")
        register("hcopy", purpose: "Copy files from HFS volumes",
                 bundled: "\(bundle)/hcopy",
                 homebrew: "/opt/homebrew/bin/hcopy")
        register("humount", purpose: "Unmount HFS volumes",
                 bundled: "\(bundle)/humount",
                 homebrew: "/opt/homebrew/bin/humount")

        // Media transcoding
        register("ffmpeg", purpose: "Audio/video transcoding (QuickTime→MP4)",
                 bundled: "\(bundle)/ffmpeg",
                 homebrew: "/opt/homebrew/bin/ffmpeg")

        // ffprobe (companion to ffmpeg)
        register("ffprobe", purpose: "Media file analysis",
                 bundled: "\(bundle)/ffprobe",
                 homebrew: "/opt/homebrew/bin/ffprobe")
    }

    // MARK: - Registration

    private func register(_ id: String, purpose: String,
                          system: String? = nil,
                          bundled: String? = nil,
                          homebrew: String? = nil) {
        var tool = Tool(id: id, name: id, purpose: purpose)
        let fm = FileManager.default

        // Priority: bundled > system > homebrew
        if let p = bundled, fm.isExecutableFile(atPath: p) {
            tool.path = p
            tool.source = .bundled
        } else if let p = system, fm.isExecutableFile(atPath: p) {
            tool.path = p
            tool.source = .system
        } else if let p = homebrew, fm.isExecutableFile(atPath: p) {
            tool.path = p
            tool.source = .homebrew
        }

        tools[id] = tool
    }

    // MARK: - Run

    /// Run a tool and return stdout. Returns nil if tool not available.
    func run(_ toolID: String, arguments: [String]) throws -> Data? {
        guard let path = tools[toolID]?.path else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }

    /// Run a tool and return stdout as String.
    func runString(_ toolID: String, arguments: [String]) throws -> String? {
        guard let data = try run(toolID, arguments: arguments) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Summary of all tools and their status.
    var summary: String {
        tools.values
            .sorted { $0.id < $1.id }
            .map { "\($0.isAvailable ? "✅" : "❌") \($0.name): \($0.source.rawValue) — \($0.purpose)" }
            .joined(separator: "\n")
    }
}
