import Foundation

// MARK: - H1: Resource Fork Binary Parser

/// Parses classic Macintosh resource fork binary format.
///
/// Layout: 16-byte header → data area → map area
/// Header: offsetToData(4) + offsetToMap(4) + dataLength(4) + mapLength(4)
/// Data: each resource prefixed with 4-byte length
/// Map: copy of header(16) + reserved(4) + attrs(2) + typeListOffset(2) + nameListOffset(2)
///       → type list: count-1(2) + entries(type(4) + count-1(2) + refOffset(2))
///       → ref list: id(2) + nameOffset(2) + attrs(1) + dataOffset(3) + handle(4)
///
/// Based on Inside Macintosh Vol I ch.5, CiderPress2 ResourceMgr.cs (Apache 2.0).
public class ResourceForkParser {

    // MARK: - Data Structures

    /// A single parsed resource entry.
    public struct ResourceEntry: Identifiable {
        public var id: String { "\(typeCode)_\(resourceID)" }
        public var typeCode: String      // 4-char type (e.g. "ICON", "snd ")
        public var typeRaw: UInt32       // raw 32-bit type value
        public var resourceID: Int16     // signed 16-bit ID
        public var name: String          // from name list, may be empty
        public var attributes: UInt8
        public var dataOffset: Int       // absolute offset in resource fork
        public var dataLength: Int
    }

    /// Grouped resources by type.
    public struct ResourceType {
        public var typeCode: String
        public var typeRaw: UInt32
        public var resources: [ResourceEntry]
        public var description: String  // from H4 registry
    }

    // MARK: - Properties

    public private(set) var entries: [ResourceEntry] = []
    public private(set) var isValid = false
    private let data: Data

    // MARK: - Init

    public init(data: Data) {
        self.data = data
        self.isValid = parse()
    }

    /// Convenience: parse resource fork data and return entries.
    public static func parse(_ data: Data) -> [ResourceEntry]? {
        let parser = ResourceForkParser(data: data)
        return parser.isValid ? parser.entries : nil
    }

    // MARK: - H1: Core Parser

    private func parse() -> Bool {
        guard data.count >= 16 else { return false }

        let offsetToData = Int(readBE32(at: 0))
        let offsetToMap = Int(readBE32(at: 4))
        let dataLength = Int(readBE32(at: 8))
        let mapLength = Int(readBE32(at: 12))

        guard offsetToMap > 0, mapLength >= 0x1C else { return false }
        guard offsetToMap + mapLength <= data.count else { return false }
        guard offsetToData + dataLength <= data.count else { return false }

        // Map header: skip 16 bytes (copy of header) + 4 reserved + 2 attrs
        let mapBase = offsetToMap
        let typeListOffset = Int(readBE16(at: mapBase + 24)) // relative to map start
        let nameListOffset = Int(readBE16(at: mapBase + 26))

        // Type list: first 2 bytes = count - 1 (0xFFFF = empty)
        let typeListBase = mapBase + typeListOffset
        guard typeListBase + 2 <= data.count else { return false }
        let typeCount = Int(readBE16(at: typeListBase)) + 1
        guard typeCount > 0 && typeCount < 10000 else { return false }

        var offset = typeListBase + 2
        for _ in 0..<typeCount {
            guard offset + 8 <= data.count else { break }
            let resTypeRaw = readBE32(at: offset)
            let resCount = Int(readBE16(at: offset + 4)) + 1  // count - 1
            let refListOff = Int(readBE16(at: offset + 6))    // relative to type list
            let typeStr = fourCharCode(resTypeRaw)

            // Walk reference list for this type
            let refBase = typeListBase + refListOff
            for ri in 0..<resCount {
                let rOff = refBase + ri * 12
                guard rOff + 12 <= data.count else { break }

                let resID = Int16(bitPattern: readBE16(at: rOff))
                let nameOff = Int16(bitPattern: readBE16(at: rOff + 2))
                let attrs = data[rOff + 4]
                // Data offset is 3 bytes (24-bit) at rOff + 5
                let dataOff = Int(data[rOff + 5]) << 16
                           | Int(data[rOff + 6]) << 8
                           | Int(data[rOff + 7])

                // Resolve resource name
                var name = ""
                if nameOff >= 0 {
                    let nameBase = mapBase + nameListOffset + Int(nameOff)
                    if nameBase < data.count {
                        let nameLen = Int(data[nameBase])
                        if nameBase + 1 + nameLen <= data.count {
                            name = String(data: data[(nameBase+1)..<(nameBase+1+nameLen)],
                                         encoding: .macOSRoman) ?? ""
                        }
                    }
                }

                // Absolute data offset = offsetToData + dataOff
                // First 4 bytes at that offset = length
                let absDataOff = offsetToData + dataOff
                var resLength = 0
                if absDataOff + 4 <= data.count {
                    resLength = Int(readBE32(at: absDataOff))
                }

                entries.append(ResourceEntry(
                    typeCode: typeStr, typeRaw: resTypeRaw,
                    resourceID: resID, name: name, attributes: attrs,
                    dataOffset: absDataOff + 4, dataLength: resLength
                ))
            }
            offset += 8
        }
        return !entries.isEmpty
    }

    // MARK: - Data Access

    /// Read raw data for a resource entry.
    public func readData(for entry: ResourceEntry) -> Data? {
        let start = entry.dataOffset
        let end = start + entry.dataLength
        guard start >= 0, end <= data.count, end > start else { return nil }
        return Data(data[start..<end])
    }

    /// Find a resource by type and ID.
    public func find(type: String, id: Int16) -> ResourceEntry? {
        entries.first { $0.typeCode == type && $0.resourceID == id }
    }

    /// Find all resources of a given type.
    public func findAll(type: String) -> [ResourceEntry] {
        entries.filter { $0.typeCode == type }
    }

    // MARK: - H2: Type List (grouped by 4-char type)

    /// Return resources grouped by type code, with descriptions.
    public func groupedByType() -> [ResourceType] {
        let grouped = Dictionary(grouping: entries) { $0.typeCode }
        return grouped.map { (key, entries) in
            ResourceType(typeCode: key, typeRaw: entries[0].typeRaw,
                        resources: entries.sorted { $0.resourceID < $1.resourceID },
                        description: Self.typeDescription(key))
        }.sorted { $0.typeCode < $1.typeCode }
    }

    // MARK: - H3: Resource Listing

    /// Format a resource entry for display: "ICON #128 'AppIcon' (128 bytes)"
    public static func formatEntry(_ e: ResourceEntry) -> String {
        var s = "\(e.typeCode) #\(e.resourceID)"
        if !e.name.isEmpty { s += " '\(e.name)'" }
        s += " (\(e.dataLength) bytes)"
        if e.attributes != 0 { s += " [attrs: 0x\(String(e.attributes, radix: 16))]" }
        return s
    }

    // MARK: - H4: Known Resource Type Registry (40+ types)

    public static func typeDescription(_ code: String) -> String {
        return knownTypes[code] ?? "Unknown resource type"
    }

    static let knownTypes: [String: String] = [
        // Icons
        "ICON": "32×32 black & white icon",
        "ICN#": "32×32 icon with mask",
        "icl4": "32×32 4-bit color icon",
        "icl8": "32×32 8-bit color icon",
        "ics#": "16×16 icon with mask",
        "ics4": "16×16 4-bit color icon",
        "ics8": "16×16 8-bit color icon",
        "cicn": "Color icon with palette",
        // Sound
        "snd ": "Sound resource",
        "SND ": "Sound resource (System 6)",
        // Text and Strings
        "STR ": "String resource",
        "STR#": "String list resource",
        "TEXT": "Plain text",
        "styl": "Styled text formatting",
        // Menus and Dialogs
        "MENU": "Menu definition",
        "MBAR": "Menu bar",
        "MDEF": "Menu definition procedure",
        "DLOG": "Dialog template",
        "DITL": "Dialog item list",
        "ALRT": "Alert template",
        "CNTL": "Control template",
        "WIND": "Window template",
        // Fonts
        "FOND": "Font family",
        "FONT": "Bitmap font",
        "NFNT": "New bitmap font",
        "sfnt": "TrueType/OpenType font",
        "FREF": "File reference (bundle)",
        "BNDL": "Bundle (file type associations)",
        // Code
        "CODE": "68K code segment",
        "CDEF": "Control definition function",
        "WDEF": "Window definition function",
        "LDEF": "List definition function",
        "PACK": "Package code",
        "DRVR": "Desk accessory / driver",
        "cfrg": "Code Fragment (PowerPC)",
        // Graphics
        "PICT": "QuickDraw picture",
        "PNTG": "MacPaint image",
        "CURS": "Cursor (16×16 B&W)",
        "crsr": "Color cursor",
        "PAT ": "Pattern (8×8 B&W)",
        "PAT#": "Pattern list",
        "ppat": "Pixel pattern (color)",
        "clut": "Color lookup table",
        "pltt": "Palette",
        "SICN": "Small icon list (16×16 B&W)",
        // Version and Info
        "vers": "Version information",
        "SIZE": "Application size/flags",
        "kind": "Finder kind string",
        // System
        "TMPL": "Resource template",
        "actb": "Alert color table",
        "cctb": "Control color table",
        "dctb": "Dialog color table",
        "wctb": "Window color table",
        "ictb": "Item color table",
        "mctb": "Menu color table",
        "PREF": "Preferences",
        "KCHR": "Keyboard mapping",
        "KMAP": "Key mapping",
        "INTL": "International resource",
        "itl0": "Script formatting",
        "itl1": "Script sorting",
    ]

    // MARK: - Helpers

    private func readBE16(at offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private func readBE32(at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 |
        UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
    }

    private func fourCharCode(_ raw: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((raw >> 24) & 0xFF), UInt8((raw >> 16) & 0xFF),
            UInt8((raw >> 8) & 0xFF), UInt8(raw & 0xFF)
        ]
        return String(data: Data(bytes), encoding: .macOSRoman) ?? "????"
    }
}
