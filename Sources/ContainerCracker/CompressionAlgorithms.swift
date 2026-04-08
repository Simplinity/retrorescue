import Foundation

// MARK: - G3: PackBits (MacPaint compression)

/// PackBits decompressor — Apple's simple run-length encoding.
/// Used by MacPaint, PICT, TIFF, and other classic Mac image formats.
///
/// Flag-counter byte N:
/// - N < 0: repeat next byte (1 - N) times (max 128)
/// - N >= 0: copy next (1 + N) bytes verbatim (max 128)
/// - N = -128: no-op (skip)
///
/// Reference: TN1023 "Understanding PackBits", CiderPress2 MacPaint.cs
public enum PackBitsDecompressor {

    /// Decompress PackBits data.
    /// - Parameters:
    ///   - data: Compressed input.
    ///   - expectedSize: Expected output size (0 = decompress all).
    /// - Returns: Decompressed data.
    public static func decompress(_ data: Data, expectedSize: Int = 0) -> Data {
        var output = Data()
        var pos = 0
        let limit = expectedSize > 0 ? expectedSize : Int.max

        while pos < data.count && output.count < limit {
            let n = Int8(bitPattern: data[pos])
            pos += 1

            if n == -128 {
                continue  // no-op
            } else if n < 0 {
                // Repeat next byte (1 - n) times
                guard pos < data.count else { break }
                let repeatCount = 1 - Int(n)
                let byte = data[pos]; pos += 1
                for _ in 0..<repeatCount {
                    guard output.count < limit else { break }
                    output.append(byte)
                }
            } else {
                // Copy next (1 + n) bytes verbatim
                let copyCount = 1 + Int(n)
                for _ in 0..<copyCount {
                    guard pos < data.count && output.count < limit else { break }
                    output.append(data[pos]); pos += 1
                }
            }
        }
        return output
    }
}

// MARK: - G4: LZW/1 and LZW/2 (NuFX / ShrinkIt)

/// NuFX LZW decompressor — used by ShrinkIt archives (.shk, .sdk, .bxy).
/// LZW/1: 12-bit codes, 4K dictionary, clear code.
/// LZW/2: dynamic code size (9-12 bits), larger dictionary, table clear.
///
/// unar handles NuFX natively; this is for direct archive reading.
/// Based on CiderPress2 NuLZWStream.cs (Apache 2.0).
public enum NuLZWDecompressor {

    static let MAX_BITS = 12
    static let CLEAR_CODE = 256
    static let FIRST_CODE = 257
    static let MAX_TABLE = 4096  // 2^12

    /// Decompress NuFX LZW/1 data.
    public static func decompressLZW1(_ data: Data, expectedSize: Int) throws -> Data {
        return try decompress(data, expectedSize: expectedSize, version: 1)
    }

    /// Decompress NuFX LZW/2 data.
    public static func decompressLZW2(_ data: Data, expectedSize: Int) throws -> Data {
        return try decompress(data, expectedSize: expectedSize, version: 2)
    }

    private static func decompress(_ data: Data, expectedSize: Int, version: Int) throws -> Data {
        var output = Data()
        var pos = 0

        // NuFX LZW processes data in 4096-byte chunks (RLE then LZW)
        // Each chunk starts with a volume byte (LZW/2) or directly with LZW data
        while output.count < expectedSize && pos < data.count {
            let remaining = expectedSize - output.count
            let chunkSize = min(4096, remaining)

            // For LZW/2: first byte of each chunk indicates if LZW was used
            if version == 2 && pos < data.count {
                let lzwFlag = data[pos]; pos += 1
                if lzwFlag == 0 {
                    // Not compressed — copy raw (preceded by 2-byte length)
                    guard pos + 1 < data.count else { break }
                    let rawLen = Int(data[pos]) | Int(data[pos+1]) << 8; pos += 2
                    let end = min(pos + rawLen, data.count)
                    output.append(data[pos..<end])
                    pos = end
                    continue
                }
            }
            // LZW/1: always 12-bit. LZW/2: starts at 9 bits, grows to 12.
            let chunk = try decompressLZWChunk(data, pos: &pos, maxOutput: chunkSize, version: version)
            output.append(chunk)
        }
        return Data(output.prefix(expectedSize))
    }

    private static func decompressLZWChunk(_ data: Data, pos: inout Int, maxOutput: Int, version: Int) throws -> Data {
        // LZW dictionary: each entry is (prefix code, append byte)
        var table = [(prefix: Int, ch: UInt8)](repeating: (0, 0), count: MAX_TABLE)
        // Init entries 0-255
        for i in 0..<256 { table[i] = (-1, UInt8(i)) }
        var nextCode = FIRST_CODE
        var codeSize = version == 1 ? 12 : 9

        var output = Data()
        var bitBuf: UInt32 = 0
        var bitsAvail = 0
        var prevCode = -1

        func readCode() -> Int? {
            while bitsAvail < codeSize {
                guard pos < data.count else { return nil }
                bitBuf |= UInt32(data[pos]) << bitsAvail
                pos += 1; bitsAvail += 8
            }
            let code = Int(bitBuf) & ((1 << codeSize) - 1)
            bitBuf >>= codeSize; bitsAvail -= codeSize
            return code
        }

        func stringForCode(_ code: Int) -> [UInt8] {
            var result = [UInt8]()
            var c = code
            while c >= 0 && c < MAX_TABLE && result.count < MAX_TABLE {
                result.append(table[c].ch)
                c = table[c].prefix
            }
            result.reverse()
            return result
        }

        while output.count < maxOutput {
            guard let code = readCode() else { break }

            if code == CLEAR_CODE {
                // Reset dictionary
                nextCode = FIRST_CODE
                codeSize = version == 1 ? 12 : 9
                prevCode = -1
                continue
            }

            let entry: [UInt8]
            if code < nextCode {
                entry = stringForCode(code)
            } else if code == nextCode && prevCode >= 0 {
                // Special case: code not yet in table
                var prev = stringForCode(prevCode)
                prev.append(prev[0])
                entry = prev
            } else {
                break // invalid code
            }

            output.append(contentsOf: entry)

            // Add new table entry
            if prevCode >= 0 && nextCode < MAX_TABLE {
                table[nextCode] = (prefix: prevCode, ch: entry[0])
                nextCode += 1
                // LZW/2: grow code size
                if version == 2 && nextCode >= (1 << codeSize) && codeSize < MAX_BITS {
                    codeSize += 1
                }
            }
            prevCode = code
        }
        return Data(output.prefix(maxOutput))
    }
}

// MARK: - G5: Squeeze (RLE + Huffman)

/// Squeeze decompressor — RLE + semi-adaptive Huffman coding.
/// Used by Binary II (.bqy) and some AppleLink PE (.acu) files.
/// File header: magic 0x76FF, 16-bit checksum, null-terminated filename.
/// Then: 16-bit node count + Huffman tree + RLE-encoded bitstream.
///
/// Based on original unsqueeze by Richard Greenlaw, CiderPress2 SqueezeStream.cs.
public enum SqueezeDecompressor {

    static let MAGIC: UInt16 = 0xFF76  // little-endian: 0x76, 0xFF
    static let RLE_DELIM: UInt8 = 0x90
    static let EOF_TOKEN = 256

    /// Decompress a Squeeze-compressed file.
    /// - Parameter data: Compressed input (with or without file header).
    /// - Returns: (decompressed data, original filename if header present).
    public static func decompress(_ data: Data) throws -> (Data, String?) {
        var pos = 0
        var fileName: String? = nil

        // Check for file header (magic 0x76 0xFF)
        if data.count >= 5 && data[0] == 0x76 && data[1] == 0xFF {
            // Skip magic (2) + checksum (2)
            pos = 4
            // Read null-terminated filename
            var nameBytes = [UInt8]()
            while pos < data.count && data[pos] != 0 {
                nameBytes.append(data[pos]); pos += 1
            }
            if pos < data.count { pos += 1 }  // skip null
            fileName = String(bytes: nameBytes, encoding: .ascii)
        }

        // Read Huffman tree: node count (16-bit LE), then nodes (each: left 16-bit + right 16-bit)
        guard pos + 2 <= data.count else {
            throw ContainerError.corruptedData("Squeeze: missing node count")
        }
        let nodeCount = Int(data[pos]) | Int(data[pos+1]) << 8; pos += 2
        guard nodeCount >= 0 && nodeCount < 512 else {
            throw ContainerError.corruptedData("Squeeze: invalid node count \(nodeCount)")
        }

        // Tree nodes: left[i] and right[i]. Negative = literal (-1 = byte 0, -257 = EOF)
        var left = [Int16](repeating: 0, count: nodeCount)
        var right = [Int16](repeating: 0, count: nodeCount)
        for i in 0..<nodeCount {
            guard pos + 4 <= data.count else {
                throw ContainerError.corruptedData("Squeeze: truncated tree")
            }
            left[i] = Int16(bitPattern: UInt16(data[pos]) | UInt16(data[pos+1]) << 8); pos += 2
            right[i] = Int16(bitPattern: UInt16(data[pos]) | UInt16(data[pos+1]) << 8); pos += 2
        }

        if nodeCount == 0 { return (Data(), fileName) }  // empty file

        // Decode bitstream: Huffman → RLE → output
        var output = Data()
        var bitBuf: UInt32 = 0
        var bitsAvail = 0
        var rleSawDelim = false
        var rleLastByte: UInt8 = 0

        func readBit() -> Int? {
            if bitsAvail == 0 {
                guard pos < data.count else { return nil }
                bitBuf = UInt32(data[pos]); pos += 1; bitsAvail = 8
            }
            let bit = Int(bitBuf & 1)
            bitBuf >>= 1; bitsAvail -= 1
            return bit
        }

        while true {
            // Decode one Huffman symbol
            var node = 0
            while node >= 0 && node < nodeCount {
                guard let bit = readBit() else { return (output, fileName) }
                let child = bit == 0 ? left[node] : right[node]
                if child < 0 {
                    // Leaf: literal = -(child + 1)
                    let symbol = Int(-(child + 1))
                    if symbol == EOF_TOKEN { return (output, fileName) }
                    let byte = UInt8(symbol & 0xFF)

                    // RLE decoder
                    if rleSawDelim {
                        rleSawDelim = false
                        if byte == 0 {
                            // Escaped delimiter — output the delimiter itself
                            output.append(RLE_DELIM)
                            rleLastByte = RLE_DELIM
                        } else {
                            // Repeat rleLastByte (byte - 1) more times (we already output it once)
                            let count = Int(byte) - 1
                            for _ in 0..<count { output.append(rleLastByte) }
                        }
                    } else if byte == RLE_DELIM {
                        rleSawDelim = true
                    } else {
                        output.append(byte)
                        rleLastByte = byte
                    }
                    break
                } else {
                    node = Int(child)
                }
            }
        }
    }
}
