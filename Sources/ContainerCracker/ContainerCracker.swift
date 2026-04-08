import Foundation

/// Identifies and extracts files from classic Mac containers.
/// Detects MacBinary, BinHex, AppleSingle/AppleDouble by magic bytes.
public enum ContainerCracker {

    /// Detected container format.
    public enum Format: String {
        case macBinary = "MacBinary"
        case binHex = "BinHex 4.0"
        case appleSingle = "AppleSingle"
        case appleDouble = "AppleDouble"
        case binaryII = "Binary II"
        case appleLinkPE = "AppleLink PE"
        case unknown = "Unknown"
    }

    /// Identify the format of the given data.
    public static func identify(data: Data, filename: String = "") -> Format {
        // Check magic bytes first
        if MacBinaryParser.canParse(data) { return .macBinary }
        if AppleDoubleParser.canParse(data) {
            if AppleDoubleParser.isAppleSingle(data) { return .appleSingle }
            return .appleDouble
        }
        if BinHexParser.canParse(data) { return .binHex }
        if BinaryIIParser.canParse(data) { return .binaryII }
        if AppleLinkParser.canParse(data) { return .appleLinkPE }

        // Fall back to extension
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "bin": return .macBinary
        case "hqx": return .binHex
        case "bny", "bqy": return .binaryII
        case "acu": return .appleLinkPE
        default: return .unknown
        }
    }

    /// Extract files from a container. Returns nil if not a recognized format.
    public static func extract(data: Data, filename: String = "") throws -> ExtractedFile? {
        let format = identify(data: data, filename: filename)

        switch format {
        case .macBinary:
            return try MacBinaryParser.parse(data)

        case .binHex:
            return try BinHexParser.parse(data)

        case .appleSingle:
            let result = try AppleDoubleParser.parse(data)
            let (type, creator) = result.finderInfo.map {
                AppleDoubleParser.typeCreator(from: $0)
            } ?? (nil, nil)
            let flags = result.finderInfo.map {
                AppleDoubleParser.finderFlags(from: $0)
            } ?? 0
            return ExtractedFile(
                name: result.realName ?? filename,
                dataFork: result.dataFork ?? Data(),
                rsrcFork: result.rsrcFork ?? Data(),
                typeCode: type,
                creatorCode: creator,
                finderFlags: flags
            )

        case .appleDouble:
            // AppleDouble only has rsrc + metadata, not data fork
            // The data fork is the companion file (without ._ prefix)
            let result = try AppleDoubleParser.parse(data)
            let (type, creator) = result.finderInfo.map {
                AppleDoubleParser.typeCreator(from: $0)
            } ?? (nil, nil)
            let flags = result.finderInfo.map {
                AppleDoubleParser.finderFlags(from: $0)
            } ?? 0
            return ExtractedFile(
                name: result.realName ?? filename,
                dataFork: Data(), // caller must provide data fork separately
                rsrcFork: result.rsrcFork ?? Data(),
                typeCode: type,
                creatorCode: creator,
                finderFlags: flags
            )

        case .binaryII:
            let files = try BinaryIIParser.parseAll(data)
            return files.first

        case .appleLinkPE:
            let files = try AppleLinkParser.parseAll(data)
            return files.first

        case .unknown:
            return nil
        }
    }

    /// Extract all files from a Binary II archive.
    public static func extractBinaryII(data: Data) throws -> [ExtractedFile] {
        return try BinaryIIParser.parseAll(data)
    }

    /// Extract an archive (StuffIt, Compact Pro, etc.) into multiple files.
    /// Returns nil if the file is not an archive unar can handle.
    public static func extractArchive(url: URL) throws -> [ExtractedFile]? {
        guard UnarExtractor.canHandle(filename: url.lastPathComponent) else {
            return nil
        }
        guard UnarExtractor.isAvailable() else {
            throw ContainerError.unsupportedFormat("unar not installed. Run: brew install unar")
        }
        return try UnarExtractor.extract(archiveURL: url)
    }
}
