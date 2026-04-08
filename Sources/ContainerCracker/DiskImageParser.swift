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
        case dart = "DART (Disk Archive/Retrieval Tool)"
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
        public var checksumValid: Bool = true  // DiskCopy 4.2 checksum result
    }

    // MARK: - Format Detection

    /// Detect the format of a disk image file.
    public static func detect(data: Data) -> Format {
        guard data.count > 84 else {
            return data.count > 1026 ? .raw : .unknown
        }

        // DART: first byte is compression type (0=RLE, 1=LZH, 2=none),
        // second byte is disk type, bytes 2-3 are disk size in KB.
        // No magic header — detected by field validation.
        if data.count >= 148 {  // minimum header for HD images
            let srcCmp = data[0]
            let srcType = data[1]
            let srcSize = UInt16(data[2]) << 8 | UInt16(data[3])
            if srcCmp <= 2 && isDARTDiskType(srcType, srcSize) {
                return .dart
            }
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

    /// Validate DART disk type and size combination.
    private static func isDARTDiskType(_ srcType: UInt8, _ srcSize: UInt16) -> Bool {
        switch srcType {
        case 1, 2, 3:   // Mac, Lisa, Apple II
            return srcSize == 400 || srcSize == 800
        case 16, 17, 18: // Mac HD, MS-DOS 720K, MS-DOS 1440K
            return srcSize == 720 || srcSize == 1440
        default:
            return false
        }
    }

    /// Decompress a DART image to raw disk data.
    /// DART format: header + compressed chunks, each chunk = 40 blocks × (512 data + 12 tag) bytes.
    static func decompressDART(_ data: Data) throws -> (Data, String?) {
        guard data.count >= 4 else { throw ContainerError.invalidFormat("DART file too small") }

        let srcCmp = data[0]    // 0=RLE, 1=LZH, 2=none
        let srcType = data[1]
        let srcSize = Int(UInt16(data[2]) << 8 | UInt16(data[3]))
        let chunkCount = srcSize <= 800 ? 40 : 72
        let headerLen = 4 + chunkCount * 2

        guard data.count >= headerLen else { throw ContainerError.invalidFormat("DART header truncated") }

        // Read block lengths
        var blockLengths = [UInt16]()
        for i in 0..<chunkCount {
            let offset = 4 + i * 2
            blockLengths.append(UInt16(data[offset]) << 8 | UInt16(data[offset + 1]))
        }

        // Parse volume name from first decompressed chunk if possible
        let diskName: String? = nil

        let blockDataLen = 512 * 40   // 20480
        let blockTagLen = 12 * 40     // 480
        let blockTotalLen = blockDataLen + blockTagLen  // 20960

        var userData = Data()
        var dataOffset = headerLen

        let activeChunks = srcSize / 20  // number of chunks with data

        for i in 0..<activeChunks {
            guard i < blockLengths.count else { break }
            let bLen = blockLengths[i]
            if bLen == 0 { break }

            var chunk: Data
            if bLen == 0xFFFF || srcCmp == 2 {
                // Uncompressed
                let end = min(dataOffset + blockTotalLen, data.count)
                guard end > dataOffset else { throw ContainerError.corruptedData("DART: unexpected EOF") }
                chunk = Data(data[dataOffset..<end])
                dataOffset = end
            } else if srcCmp == 0 {
                // RLE (fast) — bLen is in 16-bit words
                let byteLen = Int(bLen) * 2
                let end = min(dataOffset + byteLen, data.count)
                guard end > dataOffset else { throw ContainerError.corruptedData("DART: RLE data truncated") }
                let compressed = Data(data[dataOffset..<end])
                chunk = try decompressDARTRLE(compressed, expectedSize: blockTotalLen)
                dataOffset = end
            } else if srcCmp == 1 {
                // LZH (best) — bLen is in bytes
                throw ContainerError.unsupportedFormat(
                    "This DART image uses LZH compression which is not yet supported. "
                    + "RLE-compressed and uncompressed DART images work fine.")
            } else {
                throw ContainerError.invalidFormat("Unknown DART compression type: \(srcCmp)")
            }

            // Extract only the user data (first 20480 bytes), skip tag data
            if chunk.count >= blockDataLen {
                userData.append(chunk[chunk.startIndex..<chunk.startIndex + blockDataLen])
            }
        }

        return (userData, diskName)
    }

    /// Decompress DART RLE (word-oriented run-length encoding).
    private static func decompressDARTRLE(_ input: Data, expectedSize: Int) throws -> Data {
        var output = Data(capacity: expectedSize)
        var offset = input.startIndex

        while offset < input.endIndex - 1 {
            let hi = Int16(bitPattern: UInt16(input[offset]) << 8 | UInt16(input[offset + 1]))
            offset += 2

            if hi > 0 {
                // Copy N words literally
                let byteCount = Int(hi) * 2
                let end = min(offset + byteCount, input.endIndex)
                output.append(contentsOf: input[offset..<end])
                offset = end
            } else if hi < 0 {
                // Repeat pattern -N times
                guard offset + 1 < input.endIndex else { break }
                let patHi = input[offset]
                let patLo = input[offset + 1]
                offset += 2
                for _ in 0..<(-hi) {
                    output.append(patHi)
                    output.append(patLo)
                }
            } else {
                throw ContainerError.corruptedData("DART RLE: zero count")
            }
        }

        return output
    }

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

        // Tag size (big-endian uint32 at offset 68)
        let tagSize = Int(data[68]) << 24 | Int(data[69]) << 16
                     | Int(data[70]) << 8  | Int(data[71])

        // Stored checksums (big-endian uint32)
        let storedDataCksum = readBE32(data, at: 72)
        let storedTagCksum  = readBE32(data, at: 76)

        // Validate data checksum (rotate-and-add, CP2 algorithm)
        let dataEnd = min(84 + dataSize, data.count)
        let computedDataCksum = diskCopyChecksum(data: data, offset: 84, length: dataEnd - 84)
        let dataChecksumOK = (computedDataCksum == storedDataCksum)

        // Validate tag checksum — first 12 bytes excluded (backward compat)
        var tagChecksumOK = true
        if tagSize > 12 {
            let tagStart = 84 + dataSize
            let tagEnd = min(tagStart + tagSize, data.count)
            if tagEnd > tagStart + 12 {
                let computedTagCksum = diskCopyChecksum(data: data, offset: tagStart + 12, length: tagEnd - tagStart - 12)
                tagChecksumOK = (computedTagCksum == storedTagCksum)
            }
        }

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
        let rawData = data[84..<dataEnd]
        let fs = detectFilesystem(rawData: Data(rawData))

        var info = ImageInfo(format: .diskCopy42, filesystem: fs,
                        diskName: diskName, dataSize: dataSize,
                        diskType: diskType)
        info.checksumValid = dataChecksumOK && tagChecksumOK
        return info
    }

    /// DiskCopy 4.2 checksum: add big-endian 16-bit values, rotate right after each.
    /// Identical to CiderPress2 DiskCopy.ComputeChecksum().
    private static func diskCopyChecksum(data: Data, offset: Int, length: Int) -> UInt32 {
        var checksum: UInt32 = 0
        var i = 0
        while i + 1 < length {
            let val = UInt32(data[offset + i]) << 8 | UInt32(data[offset + i + 1])
            checksum = checksum &+ val
            // Rotate right by 1
            checksum = (checksum >> 1) | ((checksum & 1) << 31)
            i += 2
        }
        return checksum
    }

    private static func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 |
        UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
    }

    // MARK: - Raw Data Extraction

    /// Convert any disk image format to raw sector data.
    /// Returns the raw data and filesystem info, or throws if unsupported.
    public static func extractRawData(from url: URL) throws -> (Data, ImageInfo) {
        let data = try Data(contentsOf: url)
        let format = detect(data: data)

        switch format {
        case .dart:
            let (rawData, diskName) = try decompressDART(data)
            let fs = detectFilesystem(rawData: rawData)
            if fs == .mfs {
                throw ContainerError.unsupportedFormat(
                    "This DART image contains an MFS volume. MFS support is coming in a future version.")
            }
            let info = ImageInfo(format: .dart, filesystem: fs,
                                diskName: diskName, dataSize: rawData.count,
                                diskType: "DART compressed")
            return (rawData, info)

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
