import Foundation

/// LZHUF decompressor — port of CiderPress2's LZHufStream.cs (decompression only).
///
/// LZHUF combines LZ77 sliding window compression with adaptive Huffman coding.
/// Used by DART disk images in "best" compression mode.
///
/// Original algorithm by Haruyasu Yoshizaki (1988). This implementation is based on
/// CiderPress2 by Andy McFadden (Apache 2.0), which is itself a corrected port of LZHUF.C.
///
/// For DART: no leading length word, window init value 0x00.
public enum LZHufDecompressor {

    // MARK: - Constants

    private static let N = 4096              // sliding window size
    private static let F = 60                // lookahead / max match length
    private static let THRESHOLD = 2         // minimum match length
    private static let N_CHAR = 256 - THRESHOLD + F  // 314: literals + match lengths
    private static let T = N_CHAR * 2 - 1    // 627: Huffman table size
    private static let R = T - 1             // 626: root position
    private static let MAX_FREQ: UInt16 = 0x8000

    // Position decoding tables (from LZHUF.C)
    private static let D_CODE: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09,
        0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
        0x0C, 0x0C, 0x0C, 0x0C, 0x0D, 0x0D, 0x0D, 0x0D, 0x0E, 0x0E, 0x0E, 0x0E, 0x0F, 0x0F, 0x0F, 0x0F,
        0x10, 0x10, 0x10, 0x10, 0x11, 0x11, 0x11, 0x11, 0x12, 0x12, 0x12, 0x12, 0x13, 0x13, 0x13, 0x13,
        0x14, 0x14, 0x14, 0x14, 0x15, 0x15, 0x15, 0x15, 0x16, 0x16, 0x16, 0x16, 0x17, 0x17, 0x17, 0x17,
        0x18, 0x18, 0x19, 0x19, 0x1A, 0x1A, 0x1B, 0x1B, 0x1C, 0x1C, 0x1D, 0x1D, 0x1E, 0x1E, 0x1F, 0x1F,
        0x20, 0x20, 0x21, 0x21, 0x22, 0x22, 0x23, 0x23, 0x24, 0x24, 0x25, 0x25, 0x26, 0x26, 0x27, 0x27,
        0x28, 0x28, 0x29, 0x29, 0x2A, 0x2A, 0x2B, 0x2B, 0x2C, 0x2C, 0x2D, 0x2D, 0x2E, 0x2E, 0x2F, 0x2F,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
    ]

    private static let D_LEN: [UInt8] = [
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
    ]

    // MARK: - Public API

    /// Decompress LZHUF data.
    /// - Parameters:
    ///   - compressedData: The compressed input bytes.
    ///   - expectedSize: The expected uncompressed size.
    ///   - initValue: Window initialization byte (0x00 for DART, 0x20 for standard LZHUF).
    /// - Returns: The decompressed data.
    public static func decompress(_ compressedData: Data, expectedSize: Int, initValue: UInt8 = 0x00) throws -> Data {
        let state = DecompState(data: compressedData, expectedSize: expectedSize, initValue: initValue)
        return try state.run()
    }

    // MARK: - Decompression State

    private final class DecompState {
        let input: Data
        let expectedSize: Int
        var pos: Int = 0         // read position in input

        // Bit buffer
        var getBuf: UInt16 = 0
        var getLen: Int = 0

        // Sliding window
        var textBuf: [UInt8]
        var r: Int

        // Adaptive Huffman tree
        var freq: [UInt16]
        var prnt: [UInt16]
        var son: [UInt16]

        init(data: Data, expectedSize: Int, initValue: UInt8) {
            self.input = data
            self.expectedSize = expectedSize
            self.textBuf = [UInt8](repeating: initValue, count: N + F - 1)
            self.r = N - F
            self.freq = [UInt16](repeating: 0, count: T + 1)
            self.prnt = [UInt16](repeating: 0, count: T + N_CHAR)
            self.son = [UInt16](repeating: 0, count: T)
            startHuff()
        }

        private func startHuff() {
            var i: UInt16 = 0
            while i < UInt16(N_CHAR) {
                freq[Int(i)] = 1
                son[Int(i)] = i + UInt16(T)
                prnt[Int(i) + T] = i
                i += 1
            }
            i = 0
            var j = N_CHAR
            while j <= R {
                freq[j] = freq[Int(i)] + freq[Int(i) + 1]
                son[j] = i
                prnt[Int(i)] = UInt16(j)
                prnt[Int(i) + 1] = UInt16(j)
                i += 2
                j += 1
            }
            freq[T] = 0xFFFF
            prnt[R] = 0
        }

        private func reconst() {
            var j = 0
            for i in 0..<T {
                if son[i] >= UInt16(T) {
                    freq[j] = (freq[i] + 1) / 2
                    son[j] = son[i]
                    j += 1
                }
            }
            var i = 0
            j = N_CHAR
            while j < T {
                let k0 = i + 1
                let f = freq[i] + freq[k0]
                freq[j] = f
                var k = j - 1
                while f < freq[k] { k -= 1 }
                k += 1
                let moveLen = j - k
                if moveLen > 0 {
                    freq[k+1..<k+1+moveLen] = freq[k..<k+moveLen]
                    son[k+1..<k+1+moveLen] = son[k..<k+moveLen]
                }
                freq[k] = f
                son[k] = UInt16(i)
                i += 2
                j += 1
            }
            for i in 0..<T {
                let k = Int(son[i])
                if k >= T {
                    prnt[k] = UInt16(i)
                } else {
                    prnt[k] = UInt16(i)
                    prnt[k + 1] = UInt16(i)
                }
            }
        }

        private func update(_ c0: UInt16) {
            if freq[R] == MAX_FREQ { reconst() }
            var c = prnt[Int(c0) + T]
            repeat {
                freq[Int(c)] += 1
                let k = freq[Int(c)]
                var l = c + 1
                if k > freq[Int(l)] {
                    while k > freq[Int(l) + 1] { l += 1 }
                    freq[Int(c)] = freq[Int(l)]
                    freq[Int(l)] = k
                    let i = son[Int(c)]
                    prnt[Int(i)] = l
                    if i < UInt16(T) { prnt[Int(i) + 1] = l }
                    let j = son[Int(l)]
                    son[Int(l)] = i
                    prnt[Int(j)] = c
                    if j < UInt16(T) { prnt[Int(j) + 1] = c }
                    son[Int(c)] = j
                    c = l
                }
                c = prnt[Int(c)]
            } while c != 0
        }

        private func readByte() -> Int {
            if pos < input.count { let b = Int(input[pos]); pos += 1; return b }
            return 0
        }

        private func getBit() -> Int {
            while getLen <= 8 {
                getBuf |= UInt16(readByte()) << (8 - getLen)
                getLen += 8
            }
            let result = getBuf
            getBuf <<= 1
            getLen -= 1
            return Int(result >> 15)
        }

        private func getByte() -> UInt16 {
            while getLen <= 8 {
                getBuf |= UInt16(readByte()) << (8 - getLen)
                getLen += 8
            }
            let result = getBuf
            getBuf <<= 8
            getLen -= 8
            return result >> 8
        }

        private func decodeChar() -> UInt16 {
            var c = son[R]
            while c < UInt16(T) {
                c = UInt16(Int(c) + getBit())
                c = son[Int(c)]
            }
            c -= UInt16(T)
            update(c)
            return c
        }

        private func decodePosition() -> Int {
            var i = getByte()
            var c = Int(D_CODE[Int(i)]) << 6
            var j = Int(D_LEN[Int(i)]) - 2
            while j > 0 {
                i = (i << 1) | UInt16(getBit())
                j -= 1
            }
            return c | (Int(i) & 0x3F)
        }

        func run() throws -> Data {
            var output = Data(capacity: expectedSize)
            var dataOut = 0

            while dataOut < expectedSize {
                let c = decodeChar()
                if c < 256 {
                    // Literal byte
                    let byte = UInt8(c)
                    output.append(byte)
                    textBuf[r] = byte
                    r = (r + 1) & (N - 1)
                    dataOut += 1
                } else {
                    // Match: length + position
                    let matchPos = (r - decodePosition() - 1) & (N - 1)
                    let matchLen = Int(c) - 255 + THRESHOLD
                    for k in 0..<matchLen {
                        let ch = textBuf[(matchPos + k) & (N - 1)]
                        output.append(ch)
                        textBuf[r] = ch
                        r = (r + 1) & (N - 1)
                        dataOut += 1
                    }
                }
            }

            guard output.count >= expectedSize else {
                throw ContainerError.corruptedData("LZHUF decompression produced \(output.count) bytes, expected \(expectedSize)")
            }
            return Data(output.prefix(expectedSize))
        }
    }
}
