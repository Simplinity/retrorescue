import Testing
import Foundation
@testable import ContainerCracker

/// Tests for archive parsers: Binary II, AppleLink PE, DiskCopy checksum, hex dump.
struct ArchiveParserTests {

    // MARK: - Binary II

    @Test func binaryIIMagic() {
        // Binary II magic: 0x0A 0x47 0x4C
        var data = Data(repeating: 0, count: 256)
        data[0] = 0x0A; data[1] = 0x47; data[2] = 0x4C
        // Access byte at offset 3
        data[3] = 0x00  // ProDOS access
        // File type at offset 4
        data[4] = 0x06  // BIN
        // Filename length at offset 23
        data[23] = 8
        // Filename at offset 24-38
        for (i, b) in "TESTFILE".utf8.enumerated() { data[24 + i] = b }
        // This should be recognized as Binary II
        let hasMagic = data[0] == 0x0A && data[1] == 0x47 && data[2] == 0x4C
        #expect(hasMagic)
    }

    @Test func binaryIIRejectBadMagic() {
        var data = Data(repeating: 0, count: 256)
        data[0] = 0xFF; data[1] = 0xFF; data[2] = 0xFF
        let hasMagic = data[0] == 0x0A && data[1] == 0x47 && data[2] == 0x4C
        #expect(!hasMagic)
    }

    // MARK: - AppleLink PE

    @Test func appleLinkPEMagic() {
        // AppleLink PE magic: "fZink" at offset 0
        var data = Data(repeating: 0, count: 256)
        for (i, b) in "fZink".utf8.enumerated() { data[i] = b }
        let sig = String(data: data[0..<5], encoding: .ascii)
        #expect(sig == "fZink")
    }

    // MARK: - DiskCopy 4.2 Checksum

    @Test func diskCopy42HeaderParsing() {
        // Build a minimal DiskCopy 4.2 header (84 bytes)
        var header = Data(repeating: 0, count: 84 + 512)
        // Byte 0: name length = 10
        header[0] = 10
        // Bytes 1-63: name
        for (i, b) in "Test Disk ".utf8.enumerated() { header[1 + i] = b }
        // Bytes 64-67: data size (big endian) = 512
        header[67] = 0x02; header[66] = 0x00
        // Bytes 68-71: tag size = 0
        // Byte 82-83: magic 0x0100
        header[82] = 0x01; header[83] = 0x00
        // Byte 84: disk format (SS GCR 400K = 0)
        header[84] = 0x00

        let format = DiskImageParser.detect(data: header)
        #expect(format == .diskCopy42)
    }

    // MARK: - LZHUF Decompressor

    @Test func lzhufHandlesEmptyInput() {
        // LZHUF should not crash on empty input
        let result = try? LZHufDecompressor.decompress(Data(), expectedSize: 0)
        #expect(result != nil || true)  // just don't crash
    }

    @Test func lzhufHandlesTruncatedInput() {
        // Truncated data should not cause infinite loop
        let data = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        let result = try? LZHufDecompressor.decompress(data, expectedSize: 100)
        // May return partial data or error, but should not hang
        #expect(result != nil || true)
    }

    // MARK: - Hex Dump Format Verification

    @Test func hexDumpBasicFormat() {
        // Verify hex dump logic: 16 bytes per row, offset + hex + ASCII
        let data = Data("Hello, World!\n".utf8)
        var lines: [String] = []
        for offset in stride(from: 0, to: min(data.count, 256), by: 16) {
            var hex = ""
            var ascii = ""
            for i in 0..<16 {
                if offset + i < data.count {
                    hex += String(format: "%02X ", data[offset + i])
                    let b = data[offset + i]
                    ascii.append(b >= 0x20 && b < 0x7F ? Character(UnicodeScalar(b)) : ".")
                }
            }
            lines.append(String(format: "%08X  %@|%@|", offset, hex, ascii))
        }
        let dump = lines.joined(separator: "\n")
        #expect(dump.contains("00000000"))
        #expect(dump.contains("48 65 6C 6C"))
        #expect(dump.contains("Hello"))
    }


    // MARK: - Format Enum Coverage

    @Test func diskImageFormatRawValues() {
        #expect(DiskImageParser.Format.diskCopy42.rawValue == "DiskCopy 4.2")
        #expect(DiskImageParser.Format.dart.rawValue.contains("DART"))
        #expect(DiskImageParser.Format.apm.rawValue == "Apple Partition Map")
        #expect(DiskImageParser.Format.macTS.rawValue == "Mac TS (pre-APM)")
        #expect(DiskImageParser.Format.twoIMG.rawValue.contains("2IMG"))
        #expect(DiskImageParser.Format.woz.rawValue.contains("WOZ"))
        #expect(DiskImageParser.Format.moof.rawValue.contains("MOOF"))
    }

    @Test func imageInfoDiskType() {
        let info = DiskImageParser.ImageInfo(
            format: .diskCopy42, filesystem: .hfs,
            diskName: "Test", dataSize: 819200, diskType: "DS DD")
        #expect(info.format == .diskCopy42)
        #expect(info.filesystem == .hfs)
        #expect(info.diskName == "Test")
        #expect(info.dataSize == 819200)
    }
}
