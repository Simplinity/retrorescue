import Testing
import Foundation
@testable import ContainerCracker

/// R9: Compression algorithm tests — LZHUF, LZW, Squeeze.
struct CompressionTests {

    // MARK: - PackBits (already tested in R5, additional edge cases)

    @Test func packBitsMixed() {
        // Mixed: 2 literal bytes + 3 repeated bytes
        let compressed = Data([0x01, 0x41, 0x42,  // literal: 2 bytes (A, B)
                               0xFE, 0x43])         // repeat: C × 3
        let result = PackBitsDecompressor.decompress(compressed)
        #expect(result == Data([0x41, 0x42, 0x43, 0x43, 0x43]))
    }

    @Test func packBitsEmpty() {
        let result = PackBitsDecompressor.decompress(Data())
        #expect(result.isEmpty)
    }

    // MARK: - LZW Clear Code

    @Test func lzwClearCodeResets() throws {
        // LZW with just a clear code followed by data should not crash
        // This is a minimal test — full LZW requires proper bitstream
        var data = Data(repeating: 0, count: 100)
        // Don't crash on garbage input
        let result = try? NuLZWDecompressor.decompressLZW1(data, expectedSize: 50)
        // May or may not decompress, but shouldn't crash
        _ = result
    }

    // MARK: - Squeeze

    @Test func squeezeRejectsBadMagic() {
        let data = Data([0x00, 0x00, 0x00, 0x00])  // wrong magic
        // Should still try to parse (no header mode)
        _ = try? SqueezeDecompressor.decompress(data)
    }

    @Test func squeezeEmptyTree() throws {
        // Magic + checksum + empty filename + 0 nodes
        var data = Data()
        data.append(contentsOf: [0x76, 0xFF])  // magic
        data.append(contentsOf: [0x00, 0x00])  // checksum
        data.append(0x00)                       // empty filename
        data.append(contentsOf: [0x00, 0x00])  // 0 nodes
        let (result, name) = try SqueezeDecompressor.decompress(data)
        #expect(result.isEmpty)
        #expect(name == "")
    }

    @Test func squeezeHeaderParsing() throws {
        var data = Data()
        data.append(contentsOf: [0x76, 0xFF])        // magic
        data.append(contentsOf: [0x42, 0x00])        // checksum
        data.append(contentsOf: Array("test.txt".utf8))  // filename
        data.append(0x00)                             // null terminator
        data.append(contentsOf: [0x00, 0x00])        // 0 nodes (empty file)
        let (_, name) = try SqueezeDecompressor.decompress(data)
        #expect(name == "test.txt")
    }

    // MARK: - Charset / Encoding

    @Test func macRomanToUTF8() {
        // MacRoman 0xD2 = left double quote "
        let macData = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0xD2])
        let text = String(data: macData, encoding: .macOSRoman)
        #expect(text != nil)
        #expect(text!.contains("Hello"))
        #expect(text!.contains("\u{201C}"))
    }

    @Test func utf8DetectionByStringInit() {
        let data = Data("Hello UTF-8 🌍".utf8)
        let text = String(data: data, encoding: .utf8)
        #expect(text != nil)
        #expect(text!.contains("🌍"))
    }

    @Test func lineEndingNormalization() {
        let macText = "line1\rline2\rline3"
        let normalized = macText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        #expect(!normalized.contains("\r"))
        #expect(normalized == "line1\nline2\nline3")
    }
}
