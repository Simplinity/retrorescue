import Foundation
import AppKit

/// Resource type renderers for classic Macintosh resource forks (H5-H19).
/// Each renderer takes raw resource data and produces a displayable result.
public enum ResourceRenderers {

    // MARK: - H5: ICON / ICN# Renderer (32×32, 1-bit)

    /// Render a 32×32 1-bit ICON resource to NSImage.
    /// ICON: 128 bytes (32×32 / 8 = 128). ICN#: 256 bytes (icon + mask).
    public static func renderICON(_ data: Data) -> NSImage? {
        guard data.count >= 128 else { return nil }
        let width = 32, height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4) // RGBA

        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * 4 + x / 8
                let bitIndex = 7 - (x % 8)
                let isBlack = (data[byteIndex] >> bitIndex) & 1 == 1
                let i = (y * width + x) * 4
                pixels[i] = isBlack ? 0 : 255     // R
                pixels[i+1] = isBlack ? 0 : 255   // G
                pixels[i+2] = isBlack ? 0 : 255   // B
                pixels[i+3] = 255                  // A
            }
        }

        // Apply mask if ICN# (256 bytes: 128 icon + 128 mask)
        if data.count >= 256 {
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = 128 + y * 4 + x / 8
                    let bitIndex = 7 - (x % 8)
                    let visible = (data[byteIndex] >> bitIndex) & 1 == 1
                    let i = (y * width + x) * 4
                    pixels[i+3] = visible ? 255 : 0  // Alpha from mask
                }
            }
        }
        return imageFromRGBA(pixels, width: width, height: height)
    }

    // MARK: - H6: icl4 / icl8 Renderer (32×32 color)

    /// Render 32×32 4-bit color icon (icl4). 512 bytes.
    public static func renderIcl4(_ data: Data) -> NSImage? {
        guard data.count >= 512 else { return nil }
        return renderIndexedIcon(data, width: 32, height: 32, bitsPerPixel: 4)
    }

    /// Render 32×32 8-bit color icon (icl8). 1024 bytes.
    public static func renderIcl8(_ data: Data) -> NSImage? {
        guard data.count >= 1024 else { return nil }
        return renderIndexedIcon(data, width: 32, height: 32, bitsPerPixel: 8)
    }

    // MARK: - H7: ics# / ics4 / ics8 Renderer (16×16)

    /// Render 16×16 1-bit icon (ics#). 64 bytes (32 icon + 32 mask).
    public static func renderIcs(_ data: Data) -> NSImage? {
        guard data.count >= 32 else { return nil }
        return render1BitIcon(data, width: 16, height: 16, maskOffset: data.count >= 64 ? 32 : nil)
    }

    /// Render 16×16 4-bit icon (ics4). 128 bytes.
    public static func renderIcs4(_ data: Data) -> NSImage? {
        guard data.count >= 128 else { return nil }
        return renderIndexedIcon(data, width: 16, height: 16, bitsPerPixel: 4)
    }

    /// Render 16×16 8-bit icon (ics8). 256 bytes.
    public static func renderIcs8(_ data: Data) -> NSImage? {
        guard data.count >= 256 else { return nil }
        return renderIndexedIcon(data, width: 16, height: 16, bitsPerPixel: 8)
    }

    // MARK: - H8: cicn Renderer (color icon with embedded palette)

    /// Render a cicn (color icon). Complex format with embedded pixmap + palette.
    /// Simplified: extract the 1-bit data as fallback.
    public static func renderCicn(_ data: Data) -> NSImage? {
        // cicn header: pixMap(50) + maskBitMap(14) + iconBitMap(14) + iconData(4)
        guard data.count > 82 else { return nil }
        // Get dimensions from maskBitMap (offset 50)
        let top = Int(Int16(bitPattern: UInt16(data[52]) << 8 | UInt16(data[53])))
        let left = Int(Int16(bitPattern: UInt16(data[54]) << 8 | UInt16(data[55])))
        let bottom = Int(Int16(bitPattern: UInt16(data[56]) << 8 | UInt16(data[57])))
        let right = Int(Int16(bitPattern: UInt16(data[58]) << 8 | UInt16(data[59])))
        let w = right - left, h = bottom - top
        guard w > 0 && w <= 256 && h > 0 && h <= 256 else { return nil }
        // Fallback: render the 1-bit icon bitmap (at offset 64+, after mask)
        let maskSize = ((w + 7) / 8) * h
        let iconDataStart = 78 + maskSize  // mask bitmap data follows headers
        guard iconDataStart + maskSize <= data.count else { return nil }
        let iconData = Data(data[iconDataStart..<(iconDataStart + maskSize)])
        return render1BitIcon(iconData, width: w, height: h, maskOffset: nil)
    }

    // MARK: - H9: snd Resource Parser

    /// Parse a 'snd ' resource header and extract PCM audio info.
    public struct SoundInfo {
        public var sampleRate: Double
        public var sampleSize: Int     // bits (8 or 16)
        public var numChannels: Int
        public var numFrames: Int
        public var dataOffset: Int     // offset to raw PCM data within resource
        public var encoding: Int       // 0=none, 3=MACE 3:1, 4=MACE 6:1
    }

    public static func parseSnd(_ data: Data) -> SoundInfo? {
        guard data.count > 20 else { return nil }
        // Format 1 or 2 snd resource
        let format = Int(data[0]) << 8 | Int(data[1])
        guard format == 1 || format == 2 else { return nil }
        // Find the sound data command (bufferCmd = 0x8051)
        var offset = format == 1 ? 6 : 2
        // Skip modifier count and modifiers for format 1
        if format == 1 {
            let numMods = Int(data[2]) << 8 | Int(data[3])
            offset = 4 + numMods * 8 // each modifier is 8 bytes
        }
        // Skip command count (2 bytes)
        guard offset + 2 < data.count else { return nil }
        offset += 2
        // Find bufferCmd or soundCmd
        guard offset + 8 <= data.count else { return nil }
        let dataOff = Int(data[offset + 4]) << 24 | Int(data[offset + 5]) << 16
                    | Int(data[offset + 6]) << 8 | Int(data[offset + 7])
        let headerOffset = offset + dataOff
        guard headerOffset + 22 <= data.count else { return nil }
        // Sound header: dataPointer(4) + numChannels(4) + sampleRate(4.4) + ...
        let numChannels = Int(data[headerOffset + 4]) << 24 | Int(data[headerOffset + 5]) << 16
                        | Int(data[headerOffset + 6]) << 8 | Int(data[headerOffset + 7])
        let sampleRateFixed = UInt32(data[headerOffset + 8]) << 24 | UInt32(data[headerOffset + 9]) << 16
                            | UInt32(data[headerOffset + 10]) << 8 | UInt32(data[headerOffset + 11])
        let sampleRate = Double(sampleRateFixed) / 65536.0
        let numFrames = Int(data[headerOffset + 16]) << 24 | Int(data[headerOffset + 17]) << 16
                      | Int(data[headerOffset + 18]) << 8 | Int(data[headerOffset + 19])
        let encoding = Int(data[headerOffset + 20]) << 8 | Int(data[headerOffset + 21])
        let sampleSize = encoding == 0 ? 8 : (data.count > headerOffset + 22 ? Int(data[headerOffset + 22]) << 8 | Int(data[headerOffset + 23]) : 8)
        return SoundInfo(sampleRate: sampleRate, sampleSize: sampleSize, numChannels: max(1, numChannels),
                        numFrames: numFrames, dataOffset: headerOffset + 22, encoding: encoding)
    }

    // MARK: - H10: vers Resource Parser

    public struct VersionInfo {
        public var major: Int
        public var minor: Int
        public var revision: Int
        public var stage: String       // "development", "alpha", "beta", "release"
        public var shortVersion: String
        public var longVersion: String
    }

    public static func parseVers(_ data: Data) -> VersionInfo? {
        guard data.count >= 7 else { return nil }
        let major = Int(data[0])
        let minor = Int(data[1] >> 4)
        let fix = Int(data[1] & 0x0F)
        let stageVal = data[2]
        let stage: String
        switch stageVal {
        case 0x20: stage = "development"
        case 0x40: stage = "alpha"
        case 0x60: stage = "beta"
        default: stage = "release"
        }
        // Short version string (Pascal string at offset 6)
        let shortLen = Int(data[6])
        let shortVer = shortLen > 0 && 7 + shortLen <= data.count
            ? String(data: data[7..<(7 + shortLen)], encoding: .macOSRoman) ?? "" : ""
        // Long version string follows
        let longStart = 7 + shortLen
        var longVer = ""
        if longStart < data.count {
            let longLen = Int(data[longStart])
            if longLen > 0 && longStart + 1 + longLen <= data.count {
                longVer = String(data: data[(longStart+1)..<(longStart+1+longLen)],
                                encoding: .macOSRoman) ?? ""
            }
        }
        return VersionInfo(major: major, minor: minor, revision: fix,
                          stage: stage, shortVersion: shortVer, longVersion: longVer)
    }

    // MARK: - H11: STR / STR# Display

    /// Parse a STR resource (single Pascal string).
    public static func parseSTR(_ data: Data) -> String? {
        guard data.count >= 1 else { return nil }
        let len = Int(data[0])
        guard 1 + len <= data.count else { return nil }
        return String(data: data[1..<(1 + len)], encoding: .macOSRoman)
    }

    /// Parse a STR# resource (string list: count + Pascal strings).
    public static func parseSTRList(_ data: Data) -> [String]? {
        guard data.count >= 2 else { return nil }
        let count = Int(data[0]) << 8 | Int(data[1])
        var strings: [String] = []
        var offset = 2
        for _ in 0..<count {
            guard offset < data.count else { break }
            let len = Int(data[offset]); offset += 1
            guard offset + len <= data.count else { break }
            let s = String(data: data[offset..<(offset + len)], encoding: .macOSRoman) ?? ""
            strings.append(s); offset += len
        }
        return strings
    }

    // MARK: - H12: MENU Resource Display

    public struct MenuItem {
        public var title: String
        public var keyEquivalent: Character?
        public var isDisabled: Bool
        public var isSeparator: Bool
    }

    public struct MenuInfo {
        public var menuID: Int
        public var title: String
        public var items: [MenuItem]
    }

    public static func parseMENU(_ data: Data) -> MenuInfo? {
        guard data.count >= 14 else { return nil }
        let menuID = Int(Int16(bitPattern: UInt16(data[0]) << 8 | UInt16(data[1])))
        // Skip width(2)+height(2)+procID(2)+filler(2)+enableFlags(4) = 12 bytes
        let titleLen = Int(data[14])
        let title = titleLen > 0 && 15 + titleLen <= data.count
            ? String(data: data[15..<(15 + titleLen)], encoding: .macOSRoman) ?? "" : ""
        var offset = 15 + titleLen
        var items: [MenuItem] = []
        while offset < data.count {
            let itemLen = Int(data[offset]); offset += 1
            if itemLen == 0 { break }  // end of items
            guard offset + itemLen + 4 <= data.count else { break }
            let itemTitle = String(data: data[offset..<(offset + itemLen)],
                                   encoding: .macOSRoman) ?? ""
            offset += itemLen
            let iconNum = data[offset]; _ = iconNum; offset += 1
            let keyEq = data[offset]; offset += 1
            let markChar = data[offset]; _ = markChar; offset += 1
            let style = data[offset]; _ = style; offset += 1
            items.append(MenuItem(title: itemTitle,
                                 keyEquivalent: keyEq > 0 ? Character(UnicodeScalar(keyEq)) : nil,
                                 isDisabled: false,
                                 isSeparator: itemTitle == "-"))
        }
        return MenuInfo(menuID: menuID, title: title, items: items)
    }

    // MARK: - H13: DITL / DLOG Display

    public struct DialogItem {
        public var type: String
        public var rect: (top: Int, left: Int, bottom: Int, right: Int)
        public var text: String
    }

    public static func parseDITL(_ data: Data) -> [DialogItem]? {
        guard data.count >= 2 else { return nil }
        let count = Int(data[0]) << 8 | Int(data[1])
        var items: [DialogItem] = []
        var offset = 2

        for _ in 0...count {
            guard offset + 13 <= data.count else { break }
            offset += 4  // placeholder handle
            let top = Int(Int16(bitPattern: UInt16(data[offset]) << 8 | UInt16(data[offset+1])))
            let left = Int(Int16(bitPattern: UInt16(data[offset+2]) << 8 | UInt16(data[offset+3])))
            let bottom = Int(Int16(bitPattern: UInt16(data[offset+4]) << 8 | UInt16(data[offset+5])))
            let right = Int(Int16(bitPattern: UInt16(data[offset+6]) << 8 | UInt16(data[offset+7])))
            offset += 8
            let itemType = data[offset]; offset += 1
            let typeStr: String
            switch itemType & 0x7F {
            case 0: typeStr = "userItem"
            case 4: typeStr = "button"
            case 5: typeStr = "checkbox"
            case 6: typeStr = "radioButton"
            case 7: typeStr = "control"
            case 8: typeStr = "staticText"
            case 16: typeStr = "editText"
            case 32: typeStr = "icon"
            case 64: typeStr = "picture"
            default: typeStr = "item(\(itemType & 0x7F))"
            }
            let textLen = Int(data[offset]); offset += 1
            let text = textLen > 0 && offset + textLen <= data.count
                ? String(data: data[offset..<(offset+textLen)], encoding: .macOSRoman) ?? "" : ""
            offset += textLen
            if offset & 1 != 0 { offset += 1 } // word-align
            items.append(DialogItem(type: typeStr, rect: (top, left, bottom, right), text: text))
        }
        return items.isEmpty ? nil : items
    }

    // MARK: - H14: FOND / FONT / NFNT Display

    public struct FontInfo {
        public var familyID: Int
        public var familyName: String
        public var firstChar: Int
        public var lastChar: Int
        public var widMax: Int
        public var ascent: Int
        public var descent: Int
        public var leading: Int
        public var rowWords: Int
        public var fRectHeight: Int
    }

    /// Parse a FONT/NFNT resource header (bitmap font).
    public static func parseBitmapFont(_ data: Data) -> FontInfo? {
        guard data.count >= 26 else { return nil }
        let fontType = Int(Int16(bitPattern: UInt16(data[0]) << 8 | UInt16(data[1])))
        let firstChar = Int(Int16(bitPattern: UInt16(data[2]) << 8 | UInt16(data[3])))
        let lastChar = Int(Int16(bitPattern: UInt16(data[4]) << 8 | UInt16(data[5])))
        let widMax = Int(Int16(bitPattern: UInt16(data[6]) << 8 | UInt16(data[7])))
        let ascent = Int(Int16(bitPattern: UInt16(data[10]) << 8 | UInt16(data[11])))
        let descent = Int(Int16(bitPattern: UInt16(data[12]) << 8 | UInt16(data[13])))
        let leading = Int(Int16(bitPattern: UInt16(data[14]) << 8 | UInt16(data[15])))
        let rowWords = Int(UInt16(data[16]) << 8 | UInt16(data[17]))
        let fRectHeight = Int(Int16(bitPattern: UInt16(data[22]) << 8 | UInt16(data[23])))
        return FontInfo(familyID: fontType, familyName: "", firstChar: firstChar, lastChar: lastChar,
                       widMax: widMax, ascent: ascent, descent: descent, leading: leading,
                       rowWords: rowWords, fRectHeight: fRectHeight)
    }

    // MARK: - H15: CODE Resource Info (68K code segments)

    public struct CodeInfo {
        public var segmentNum: Int
        public var jumpTableOffset: Int
        public var jumpTableEntries: Int
        public var size: Int
    }

    public static func parseCODE(_ data: Data) -> CodeInfo? {
        guard data.count >= 4 else { return nil }
        // CODE 0 is the jump table; CODE 1+ are segments
        let field1 = Int(UInt16(data[0]) << 8 | UInt16(data[1]))
        let field2 = Int(UInt16(data[2]) << 8 | UInt16(data[3]))
        return CodeInfo(segmentNum: 0, jumpTableOffset: field1,
                       jumpTableEntries: field2, size: data.count)
    }

    // MARK: - H16: BNDL / FREF Display

    public struct BundleInfo {
        public var signature: String   // 4-char creator
        public var iconMappings: [(fileType: String, localID: Int)]
    }

    public static func parseBNDL(_ data: Data) -> BundleInfo? {
        guard data.count >= 10 else { return nil }
        let sig = String(data: data[0..<4], encoding: .macOSRoman) ?? "????"
        // Skip signature(4) + version(2) = 6
        let numTypes = Int(UInt16(data[6]) << 8 | UInt16(data[7])) + 1
        var mappings: [(String, Int)] = []

        var offset = 8
        for _ in 0..<numTypes {
            guard offset + 6 <= data.count else { break }
            let typeStr = String(data: data[offset..<(offset+4)], encoding: .macOSRoman) ?? "????"
            let count = Int(UInt16(data[offset+4]) << 8 | UInt16(data[offset+5])) + 1
            offset += 6
            for _ in 0..<count {
                guard offset + 4 <= data.count else { break }
                let localID = Int(Int16(bitPattern: UInt16(data[offset]) << 8 | UInt16(data[offset+1])))
                let resID = Int(Int16(bitPattern: UInt16(data[offset+2]) << 8 | UInt16(data[offset+3])))
                _ = resID
                mappings.append((typeStr, localID))
                offset += 4
            }
        }
        return BundleInfo(signature: sig, iconMappings: mappings)
    }

    // MARK: - H17: CURS / crsr Renderer

    /// Render a CURS resource (16×16 B&W cursor). 68 bytes: data(32) + mask(32) + hotspot(4).
    public static func renderCURS(_ data: Data) -> NSImage? {
        guard data.count >= 64 else { return nil }
        return render1BitIcon(data, width: 16, height: 16, maskOffset: 32)
    }

    // MARK: - H18: ppat / PAT Renderer

    /// Render a PAT resource (8×8 B&W pattern). 8 bytes.
    public static func renderPAT(_ data: Data) -> NSImage? {
        guard data.count >= 8 else { return nil }
        return render1BitIcon(data, width: 8, height: 8, maskOffset: nil)
    }

    // MARK: - H19: clut Renderer (Color Lookup Table)

    public struct ColorTable {
        public var seed: UInt32
        public var entries: [(index: Int, r: UInt16, g: UInt16, b: UInt16)]
    }

    public static func parseCLUT(_ data: Data) -> ColorTable? {
        guard data.count >= 8 else { return nil }
        let seed = UInt32(data[0]) << 24 | UInt32(data[1]) << 16
                 | UInt32(data[2]) << 8 | UInt32(data[3])
        let count = Int(UInt16(data[6]) << 8 | UInt16(data[7])) + 1
        var entries: [(Int, UInt16, UInt16, UInt16)] = []
        var offset = 8
        for _ in 0..<count {
            guard offset + 8 <= data.count else { break }
            let idx = Int(UInt16(data[offset]) << 8 | UInt16(data[offset+1]))
            let r = UInt16(data[offset+2]) << 8 | UInt16(data[offset+3])
            let g = UInt16(data[offset+4]) << 8 | UInt16(data[offset+5])
            let b = UInt16(data[offset+6]) << 8 | UInt16(data[offset+7])
            entries.append((idx, r, g, b)); offset += 8
        }
        return ColorTable(seed: seed, entries: entries)
    }

    // MARK: - Image Helpers

    /// Create NSImage from RGBA pixel array.
    static func imageFromRGBA(_ pixels: [UInt8], width: Int, height: Int) -> NSImage? {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8,
                                   bitsPerPixel: 32, bytesPerRow: width * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: bitmapInfo, provider: provider,
                                   decode: nil, shouldInterpolate: false,
                                   intent: .defaultIntent)
        else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    /// Render 1-bit icon data to NSImage.
    static func render1BitIcon(_ data: Data, width: Int, height: Int, maskOffset: Int?) -> NSImage? {
        let rowBytes = (width + 7) / 8
        guard data.count >= rowBytes * height else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * rowBytes + x / 8
                let bitIndex = 7 - (x % 8)
                let isBlack = (data[byteIndex] >> bitIndex) & 1 == 1
                let i = (y * width + x) * 4
                pixels[i] = isBlack ? 0 : 255
                pixels[i+1] = isBlack ? 0 : 255
                pixels[i+2] = isBlack ? 0 : 255
                pixels[i+3] = 255
            }
        }

        if let maskOff = maskOffset, maskOff + rowBytes * height <= data.count {
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = maskOff + y * rowBytes + x / 8
                    let bitIndex = 7 - (x % 8)
                    let visible = (data[byteIndex] >> bitIndex) & 1 == 1
                    pixels[(y * width + x) * 4 + 3] = visible ? 255 : 0
                }
            }
        }
        return imageFromRGBA(pixels, width: width, height: height)
    }

    /// Render an indexed-color icon (4-bit or 8-bit) to NSImage.
    static func renderIndexedIcon(_ data: Data, width: Int, height: Int, bitsPerPixel: Int) -> NSImage? {
        let palette = bitsPerPixel == 4 ? mac4BitPalette : mac8BitPalette
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var bitPos = 0
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = bitPos / 8
                guard byteIndex < data.count else { break }
                let colorIndex: Int
                if bitsPerPixel == 4 {
                    let shift = (bitPos % 8 == 0) ? 4 : 0
                    colorIndex = Int((data[byteIndex] >> shift) & 0x0F)
                } else {
                    colorIndex = Int(data[byteIndex])
                }
                bitPos += bitsPerPixel

                let (r, g, b) = colorIndex < palette.count ? palette[colorIndex] : (0, 0, 0)
                let i = (y * width + x) * 4
                pixels[i] = UInt8(r); pixels[i+1] = UInt8(g)
                pixels[i+2] = UInt8(b); pixels[i+3] = 255
            }
        }
        return imageFromRGBA(pixels, width: width, height: height)
    }

    // MARK: - Mac Standard Color Palettes

    /// Mac 4-bit (16 color) system palette.
    static let mac4BitPalette: [(Int, Int, Int)] = [
        (255,255,255), (252,243,5), (255,100,2), (221,8,6),
        (242,8,132), (70,0,165), (0,0,212), (2,171,234),
        (31,183,20), (0,100,18), (86,44,5), (144,113,58),
        (192,192,192), (128,128,128), (64,64,64), (0,0,0)
    ]

    /// Mac 8-bit (256 color) system palette — standard 6×6×6 cube + grays + pure colors.
    static let mac8BitPalette: [(Int, Int, Int)] = {
        var p = [(Int, Int, Int)]()
        // 6×6×6 color cube (216 colors)
        for r in stride(from: 255, through: 0, by: -51) {
            for g in stride(from: 255, through: 0, by: -51) {
                for b in stride(from: 255, through: 0, by: -51) {
                    p.append((r, g, b))
                }
            }
        }
        // Extra shades of key colors + grays (40 entries to reach 256)
        let extras: [(Int,Int,Int)] = [
            (255,0,0), (255,0,51), (255,0,102), (255,0,153),
            (255,0,204), (204,0,255), (153,0,255), (102,0,255),
            (51,0,255), (0,0,255), (0,51,255), (0,102,255),
            (0,153,255), (0,204,255), (0,255,255), (0,255,204),
            (0,255,153), (0,255,102), (0,255,51), (0,255,0),
            (51,255,0), (102,255,0), (153,255,0), (204,255,0),
            (255,255,0), (255,204,0), (255,153,0), (255,102,0),
            (255,51,0), (238,0,0), (221,0,0), (187,0,0),
            (170,0,0), (136,0,0), (119,0,0), (85,0,0),
            (68,0,0), (34,0,0), (17,0,0), (0,0,0)
        ]
        p.append(contentsOf: extras)
        // Pad to 256 with black
        while p.count < 256 { p.append((0, 0, 0)) }
        return p
    }()

    /// Dispatch: render any known icon-type resource.
    public static func renderIcon(type: String, data: Data) -> NSImage? {
        switch type {
        case "ICON": return renderICON(data)
        case "ICN#": return renderICON(data)
        case "icl4": return renderIcl4(data)
        case "icl8": return renderIcl8(data)
        case "ics#": return renderIcs(data)
        case "ics4": return renderIcs4(data)
        case "ics8": return renderIcs8(data)
        case "cicn": return renderCicn(data)
        case "CURS": return renderCURS(data)
        case "PAT ": return renderPAT(data)
        case "SICN": return render1BitIcon(data, width: 16, height: 16, maskOffset: nil)
        default: return nil
        }
    }
}
