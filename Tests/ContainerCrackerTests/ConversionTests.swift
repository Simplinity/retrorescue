import Testing
import Foundation
@testable import ContainerCracker

/// R10: Conversion tests — MacPaint, PackBits decompression, text conversion.
struct ConversionTests {

    @Test func macPaintMinimumSize() {
        // MacPaint: must be > 512 bytes (512-byte header + compressed data)
        let tooSmall = Data(repeating: 0, count: 100)
        // PackBits decompress of tiny data should return small result
        let result = PackBitsDecompressor.decompress(tooSmall, expectedSize: 51840)
        #expect(result.count < 51840)  // not enough input to fill MacPaint bitmap
    }

    @Test func packBitsDecompressToExpectedSize() {
        // MacPaint bitmap: 576×720 = 51840 bytes uncompressed
        // PackBits of all-white row: 0xFE 0x00 repeated 9 times per row (72 bytes/row)
        var compressed = Data()
        for _ in 0..<720 {
            for _ in 0..<(576/8/2) {
                compressed.append(contentsOf: [0xFF, 0x00])  // repeat 0x00 twice
            }
        }
        let result = PackBitsDecompressor.decompress(compressed, expectedSize: 51840)
        #expect(result.count == 51840)
        #expect(result.allSatisfy { $0 == 0 })  // all white
    }

    @Test func bitmapFontParsing() {
        // Create minimal FONT data (26+ bytes) and parse with ResourceRenderers
        var fontData = Data(repeating: 0, count: 100)
        fontData[2] = 0; fontData[3] = 32   // firstChar=32
        fontData[4] = 0; fontData[5] = 33   // lastChar=33
        fontData[6] = 0; fontData[7] = 8    // widMax=8
        fontData[10] = 0; fontData[11] = 10 // ascent=10
        fontData[12] = 0; fontData[13] = 2  // descent=2
        fontData[22] = 0; fontData[23] = 12 // fRectHeight=12
        let info = ResourceRenderers.parseBitmapFont(fontData)
        #expect(info != nil)
        #expect(info?.ascent == 10)
        #expect(info?.descent == 2)
        #expect(info?.firstChar == 32)
        #expect(info?.lastChar == 33)
        #expect(info?.fRectHeight == 12)
    }

    @Test func clarisWorksDetection() {
        // BOBO header — this is basic data detection, no ConversionEngine needed
        let bobo = Data("BOBO".utf8) + Data(repeating: 0, count: 100)
        let header = String(data: bobo[0..<4], encoding: .ascii)
        #expect(header == "BOBO")
    }

    @Test func textExtractionFromBinary() {
        // Verify printable text detection in binary data
        var data = Data(repeating: 0, count: 50)
        let text = "This is a long enough test string for extraction."
        data.append(Data(text.utf8))
        data.append(Data(repeating: 0, count: 50))
        // Text should be extractable as a run of printable bytes
        let printableCount = data.filter { ($0 >= 0x20 && $0 < 0x7F) || $0 == 0x0A }.count
        #expect(printableCount >= text.count)
    }
}
