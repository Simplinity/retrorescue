import Foundation

/// Parses and converts Apple disk image formats to raw sector data.
/// Supports DiskCopy 4.2, NDIF (DiskCopy 6.x), UDIF (.dmg), and raw images.
///
/// References:
/// - DC42 spec: https://www.discferret.com/wiki/Apple_DiskCopy_4.2
/// - NDIF/UDIF: https://en.wikipedia.org/wiki/NDIF
public enum DiskImageParser {

    /// Detected disk image format.
    public enum Format: String {
        case diskCopy42 = "DiskCopy 4.2"
        case ndif = "NDIF (DiskCopy 6.x)"
        case udif = "UDIF (.dmg)"
        case iso9660 = "ISO 9660"
        case hybridISO_HFS = "Hybrid ISO 9660/HFS"
        case raw = "Raw disk image"
        case unknown = "Unknown"
    }

    /// Detected filesystem on the volume.
    public enum Filesystem: String {
        case hfs = "HFS"
        case mfs = "MFS"
        case hfsPlus = "HFS+"
        case unknown = "Unknown"
    }

    /// Information about a parsed disk image.
    public struct ImageInfo {
        public let format: Format
        public let filesystem: Filesystem
        public let diskName: String?
        public let dataSize: Int
        public let diskType: String  // "400K GCR", "800K GCR", "1440K MFM", etc.
    }

    // MARK: - Format Detection

    /// Detect the format of a disk image file.
    public static func detect(data: Data) -> Format {
        guard data.count > 84 else {
            return data.count > 1026 ? .raw : .unknown
        }

        // DiskCopy 4.2: magic 0x0100 at offset 82-83
        if data[82] == 0x01 && data[83] == 0x00 {
            // Verify: name length at byte 0 should be 1-63
            let nameLen = Int(data[0])
            if nameLen >= 1 && nameLen <= 63 {
                return .diskCopy42
            }
        }

        // UDIF: 'koly' magic in last 512 bytes
        if data.count >= 512 {
            let trailer = data.suffix(512)
            let start = trailer.startIndex
            if trailer[start] == 0x6B && trailer[start+1] == 0x6F
                && trailer[start+2] == 0x6C && trailer[start+3] == 0x79 {
                return .udif
            }
        }

        // ISO 9660: "CD001" at offset 32769 (sector 16 + 1 byte)
        if data.count > 32774 {
            let iso = data[32769..<32774]
            if iso.elementsEqual("CD001".utf8) {
                // Check if also HFS (hybrid disc)
                if data.count > 1026 {
                    let hfsMagic = UInt16(data[1024]) << 8 | UInt16(data[1025])
                    if hfsMagic == 0x4244 {
                        return .hybridISO_HFS
                    }
                }
                return .iso9660
            }
        }

        // NDIF: check for 'bcem' resource map signature or other NDIF markers
        // NDIF images often have resource fork data; without it, check hdiutil
        if data.count > 4 {
            // Some NDIF images have specific signatures
            let sig = String(data: data[0..<4], encoding: .ascii) ?? ""
            if sig == "RdWr" || sig == "Rdxx" || sig == "ROCo" {
                return .ndif
            }
        }

        // Raw: check for filesystem magic at expected offsets
        if data.count > 1026 {
            return .raw
        }

        return .unknown
    }

    // MARK: - Filesystem Detection

    /// Detect the filesystem on raw disk data.
    /// HFS magic "BD" (0x4244) at offset 1024.
    /// MFS magic 0xD2D7 at offset 1024.
    /// HFS+ magic "H+" (0x482B) at offset 1024.
    public static func detectFilesystem(rawData: Data) -> Filesystem {
        guard rawData.count > 1026 else { return .unknown }
        let magic = UInt16(rawData[1024]) << 8 | UInt16(rawData[1025])
        switch magic {
        case 0x4244: return .hfs     // "BD"
        case 0xD2D7: return .mfs     // Classic MFS
        case 0x482B: return .hfsPlus // "H+"
        default:     return .unknown
        }
    }

    // MARK: - DiskCopy 4.2 Parsing

    /// Parse a DiskCopy 4.2 image and extract the raw disk data.
    public static func parseDiskCopy42(_ data: Data) -> ImageInfo? {
        guard data.count > 84, data[82] == 0x01, data[83] == 0x00 else {
            return nil
        }

        // Disk name (Pascal string: length byte + chars)
        let nameLen = min(Int(data[0]), 63)
        let diskName = String(data: data[1..<(1 + nameLen)], encoding: .macOSRoman)

        // Data size (big-endian uint32 at offset 64)
        let dataSize = Int(data[64]) << 24 | Int(data[65]) << 16
                      | Int(data[66]) << 8  | Int(data[67])

        // Disk encoding type (offset 80)
        let encoding = data[80]
        let diskType: String
        switch encoding {
        case 0x00: diskType = "400K GCR (single-sided)"
        case 0x01: diskType = "800K GCR (double-sided)"
        case 0x02: diskType = "720K MFM"
        case 0x03: diskType = "1440K MFM (High Density)"
        default:   diskType = "Unknown (\(String(format: "0x%02X", encoding)))"
        }

        // Extract raw data (starts at offset 84)
        let end = min(84 + dataSize, data.count)
        let rawData = data[84..<end]
        let fs = detectFilesystem(rawData: Data(rawData))

        return ImageInfo(format: .diskCopy42, filesystem: fs,
                        diskName: diskName, dataSize: dataSize,
                        diskType: diskType)
    }

    // MARK: - Raw Data Extraction

    /// Convert any disk image format to raw sector data.
    /// Returns the raw data and filesystem info, or throws if unsupported.
    public static func extractRawData(from url: URL) throws -> (Data, ImageInfo) {
        let data = try Data(contentsOf: url)
        let format = detect(data: data)

        switch format {
        case .diskCopy42:
            guard let info = parseDiskCopy42(data) else {
                throw ContainerError.invalidFormat("Invalid DiskCopy 4.2 image")
            }
            if info.filesystem == .mfs {
                throw ContainerError.unsupportedFormat(
                    "This is an MFS volume (\(info.diskType), \"\(info.diskName ?? "?")\") "
                    + "from the original 128K/512K Macintosh. MFS support is coming in a future version.")
            }
            let end = min(84 + info.dataSize, data.count)
            return (Data(data[84..<end]), info)

        case .udif, .ndif:
            // Use macOS hdiutil to convert to raw
            let rawURL = try convertWithHdiutil(url)
            defer { try? FileManager.default.removeItem(at: rawURL) }
            let rawData = try Data(contentsOf: rawURL)
            let fs = detectFilesystem(rawData: rawData)
            let info = ImageInfo(format: format, filesystem: fs,
                                diskName: nil, dataSize: rawData.count,
                                diskType: "Converted via hdiutil")
            return (rawData, info)

        case .iso9660:
            // ISO 9660 should be handled by unar, not HFS extraction
            throw ContainerError.unsupportedFormat(
                "This is an ISO 9660 disc image. Use the standard archive extraction path (unar) for this format.")

        case .hybridISO_HFS:
            // Hybrid disc: extract the HFS partition
            let fs = detectFilesystem(rawData: data)
            let info = ImageInfo(format: .hybridISO_HFS, filesystem: fs,
                                diskName: nil, dataSize: data.count,
                                diskType: "Hybrid ISO 9660/HFS disc")
            return (data, info)

        case .raw:
            let fs = detectFilesystem(rawData: data)
            if fs == .mfs {
                throw ContainerError.unsupportedFormat(
                    "This is an MFS (Macintosh File System) volume. MFS support is coming in a future version.")
            }
            let info = ImageInfo(format: .raw, filesystem: fs,
                                diskName: nil, dataSize: data.count,
                                diskType: "Raw image")
            return (data, info)

        case .unknown:
            throw ContainerError.unsupportedFormat(
                "Unrecognized disk image format. Supported: DiskCopy 4.2, NDIF, UDIF (.dmg), raw HFS.")
        }
    }

    // MARK: - hdiutil Conversion

    /// Convert NDIF or UDIF images to raw format using macOS hdiutil.
    /// hdiutil is always available on macOS.
    private static func convertWithHdiutil(_ url: URL) throws -> URL {
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-raw-\(UUID().uuidString).raw")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "convert", url.path,
            "-format", "UDRO",  // Uncompressed read-only
            "-o", outputPath.path
        ]
        let errPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()

        // hdiutil appends .dmg to output, check both paths
        let candidates = [
            outputPath,
            outputPath.appendingPathExtension("dmg"),
            URL(fileURLWithPath: outputPath.path + ".dmg")
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                           encoding: .utf8) ?? "unknown error"
        throw ContainerError.unsupportedFormat("hdiutil conversion failed: \(errMsg)")
    }

    /// Write raw data to a temporary file for hfsutils.
    public static func writeRawTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("retrorescue-hfs-\(UUID().uuidString).raw")
        try data.write(to: url)
        return url
    }
}
