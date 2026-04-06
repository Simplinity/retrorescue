import Foundation

/// Parses BinHex 4.0 (.hqx) encoded files.
///
/// BinHex wraps a classic Mac file into a text-safe encoding (like Base64 but Mac-specific).
/// Structure: text header → 6-bit encoded data → decoded stream contains forks + metadata.
public enum BinHexParser {

    private static let marker = "(This file must be converted with BinHex"

    /// 6-bit decoding table. Maps ASCII chars to 0-63 values.
    private static let decodeTable: [UInt8] = {
        let chars = "!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr"
        var table = [UInt8](repeating: 0xFF, count: 256)
        for (i, ch) in chars.utf8.enumerated() {
            table[Int(ch)] = UInt8(i)
        }
        return table
    }()

    public static func canParse(_ data: Data) -> Bool {
        guard let text = String(data: data.prefix(256), encoding: .ascii) else { return false }
        return text.contains(marker)
    }

    public static func parse(_ data: Data) throws -> ExtractedFile {
        guard let text = String(data: data, encoding: .ascii) else {
            throw ContainerError.invalidFormat("Not valid ASCII text")
        }
        guard text.contains(marker) else {
            throw ContainerError.invalidFormat("Missing BinHex header")
        }

        // Extract encoded data between ':' delimiters
        let encoded = try extractEncodedData(from: text)

        // 6-bit decode
        let decoded = try sixBitDecode(encoded)

        // Run-length decode
        let expanded = try rleDecode(decoded)

        // Parse the binary stream
        return try parseStream(expanded)
    }

    // MARK: - Extract encoded data

    private static func extractEncodedData(from text: String) throws -> String {
        // Find first ':' after the marker line
        let lines = text.components(separatedBy: .newlines)
        var foundMarker = false
        var encoded = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(marker) {
                foundMarker = true
                continue
            }
            if !foundMarker { continue }

            if trimmed.hasPrefix(":") {
                // First colon starts the data, last colon ends it
                let content = trimmed.dropFirst() // remove leading ':'
                if content.hasSuffix(":") {
                    encoded += content.dropLast()
                    break
                }
                encoded += content
            } else if !encoded.isEmpty {
                // Continuation line
                if trimmed.hasSuffix(":") {
                    encoded += trimmed.dropLast()
                    break
                }
                encoded += trimmed
            }
        }

        guard !encoded.isEmpty else {
            throw ContainerError.invalidFormat("No encoded data found")
        }
        return encoded
    }

    // MARK: - 6-bit decode

    private static func sixBitDecode(_ encoded: String) throws -> Data {
        var output = Data()
        var accumulator: UInt32 = 0
        var bits: Int = 0

        for byte in encoded.utf8 {
            let val = decodeTable[Int(byte)]
            guard val != 0xFF else { continue } // skip unknown chars (whitespace etc)
            accumulator = (accumulator << 6) | UInt32(val)
            bits += 6
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> bits) & 0xFF))
            }
        }
        return output
    }

    // MARK: - Run-length decode

    private static func rleDecode(_ data: Data) throws -> Data {
        var output = Data()
        var i = 0
        while i < data.count {
            let byte = data[i]
            i += 1
            if byte == 0x90 {
                guard i < data.count else { break }
                let count = data[i]
                i += 1
                if count == 0 {
                    // Literal 0x90
                    output.append(0x90)
                } else {
                    // Repeat previous byte (count - 1) more times
                    guard let last = output.last else {
                        throw ContainerError.corruptedData("RLE repeat with no previous byte")
                    }
                    for _ in 0..<(Int(count) - 1) {
                        output.append(last)
                    }
                }
            } else {
                output.append(byte)
            }
        }
        return output
    }

    // MARK: - Parse binary stream

    private static func parseStream(_ data: Data) throws -> ExtractedFile {
        var offset = 0

        // Filename (Pascal string)
        guard offset < data.count else {
            throw ContainerError.corruptedData("Stream too short")
        }
        let nameLen = Int(data[offset])
        offset += 1
        guard offset + nameLen <= data.count else {
            throw ContainerError.corruptedData("Filename extends past data")
        }
        let name = String(data: data[offset..<(offset + nameLen)], encoding: .macOSRoman) ?? "Untitled"
        offset += nameLen

        // Version (1 byte, skip)
        offset += 1

        // Type code (4 bytes)
        guard offset + 4 <= data.count else { throw ContainerError.corruptedData("No type code") }
        let typeCode = String(data: data[offset..<(offset + 4)], encoding: .macOSRoman)
        offset += 4

        // Creator code (4 bytes)
        guard offset + 4 <= data.count else { throw ContainerError.corruptedData("No creator code") }
        let creatorCode = String(data: data[offset..<(offset + 4)], encoding: .macOSRoman)
        offset += 4

        // Finder flags (2 bytes, big-endian)
        guard offset + 2 <= data.count else { throw ContainerError.corruptedData("No Finder flags") }
        let finderFlags = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2

        // Data fork length (4 bytes, big-endian)
        guard offset + 4 <= data.count else { throw ContainerError.corruptedData("No data size") }
        let dataSize = Int(readBE32(data, at: offset))
        offset += 4

        // Resource fork length (4 bytes, big-endian)
        guard offset + 4 <= data.count else { throw ContainerError.corruptedData("No rsrc size") }
        let rsrcSize = Int(readBE32(data, at: offset))
        offset += 4

        // Header CRC (2 bytes, skip)
        offset += 2

        // Data fork
        guard offset + dataSize <= data.count else {
            throw ContainerError.corruptedData("Data fork truncated")
        }
        let dataFork = Data(data[offset..<(offset + dataSize)])
        offset += dataSize

        // Data fork CRC (2 bytes, skip)
        offset += 2

        // Resource fork
        let rsrcFork: Data
        if rsrcSize > 0, offset + rsrcSize <= data.count {
            rsrcFork = Data(data[offset..<(offset + rsrcSize)])
        } else {
            rsrcFork = Data()
        }

        return ExtractedFile(
            name: name,
            dataFork: dataFork,
            rsrcFork: rsrcFork,
            typeCode: typeCode,
            creatorCode: creatorCode,
            finderFlags: finderFlags
        )
    }

    private static func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 |
        UInt32(data[offset + 1]) << 16 |
        UInt32(data[offset + 2]) << 8 |
        UInt32(data[offset + 3])
    }
}
