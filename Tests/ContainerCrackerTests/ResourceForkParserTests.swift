import Testing
import Foundation
@testable import ContainerCracker

/// R7: Resource fork parser tests — type registry, format entry, rendering.
struct ResourceForkParserTests {

    @Test func typeRegistryKnownTypes() {
        #expect(ResourceForkParser.typeDescription("ICON") == "32×32 black & white icon")
        #expect(ResourceForkParser.typeDescription("snd ") == "Sound resource")
        #expect(ResourceForkParser.typeDescription("PICT") == "QuickDraw picture")
        #expect(ResourceForkParser.typeDescription("CODE") == "68K code segment")
        #expect(ResourceForkParser.typeDescription("vers") == "Version information")
        #expect(ResourceForkParser.typeDescription("MENU") == "Menu definition")
        #expect(ResourceForkParser.typeDescription("FOND") == "Font family")
    }

    @Test func typeRegistryUnknown() {
        #expect(ResourceForkParser.typeDescription("ZZZZ") == "Unknown resource type")
        #expect(ResourceForkParser.typeDescription("????") == "Unknown resource type")
    }

    @Test func formatEntry() {
        let entry = ResourceForkParser.ResourceEntry(
            typeCode: "ICON", typeRaw: 0x49434F4E,
            resourceID: 128, name: "AppIcon", attributes: 0,
            dataOffset: 0, dataLength: 128)
        let formatted = ResourceForkParser.formatEntry(entry)
        #expect(formatted.contains("ICON"))
        #expect(formatted.contains("#128"))
        #expect(formatted.contains("AppIcon"))
        #expect(formatted.contains("128 bytes"))
    }

    @Test func rejectTooSmall() {
        let parser = ResourceForkParser(data: Data(repeating: 0, count: 10))
        #expect(!parser.isValid)
        #expect(parser.entries.isEmpty)
    }

    @Test func rejectAllZeros() {
        let parser = ResourceForkParser(data: Data(repeating: 0, count: 512))
        #expect(!parser.isValid)
    }

    @Test func iconRendering32x32() {
        // 128 bytes of alternating bits → checkerboard pattern
        var iconData = Data()
        for _ in 0..<32 { iconData.append(contentsOf: [0xAA, 0x55, 0xAA, 0x55]) }
        let image = ResourceRenderers.renderICON(iconData)
        #expect(image != nil)
        #expect(image!.size.width == 32)
        #expect(image!.size.height == 32)
    }

    @Test func iconRenderingTooSmall() {
        let image = ResourceRenderers.renderICON(Data(repeating: 0, count: 10))
        #expect(image == nil)
    }

    @Test func versParser() {
        // vers resource: major=7, minor.fix=5.3, stage=release(0x80)
        var data = Data(repeating: 0, count: 20)
        data[0] = 7       // major
        data[1] = 0x53    // minor=5, fix=3
        data[2] = 0x80    // release
        data[6] = 5       // short version string length
        data[7] = 0x37; data[8] = 0x2E; data[9] = 0x35  // "7.5"
        data[10] = 0x2E; data[11] = 0x33                  // ".3"
        let info = ResourceRenderers.parseVers(data)
        #expect(info != nil)
        #expect(info?.major == 7)
        #expect(info?.minor == 5)
        #expect(info?.revision == 3)
        #expect(info?.stage == "release")
    }

    @Test func strParser() {
        // STR: Pascal string (length byte + chars)
        var data = Data()
        data.append(5)  // length
        data.append(contentsOf: Array("Hello".utf8))
        let result = ResourceRenderers.parseSTR(data)
        #expect(result == "Hello")
    }

    @Test func strListParser() {
        // STR#: count(2) + Pascal strings
        var data = Data()
        data.append(contentsOf: [0x00, 0x02])  // 2 strings
        data.append(3); data.append(contentsOf: Array("abc".utf8))
        data.append(2); data.append(contentsOf: Array("xy".utf8))
        let result = ResourceRenderers.parseSTRList(data)
        #expect(result?.count == 2)
        #expect(result?[0] == "abc")
        #expect(result?[1] == "xy")
    }

    @Test func clutParser() {
        // clut: seed(4) + flags(2) + count-1(2) + entries(index(2)+r(2)+g(2)+b(2))
        var data = Data(repeating: 0, count: 8 + 8)  // header + 1 entry
        data[7] = 0  // count-1 = 0 → 1 entry
        // Entry: index=0, r=0xFFFF, g=0, b=0
        data[8] = 0; data[9] = 0     // index
        data[10] = 0xFF; data[11] = 0xFF  // red
        data[12] = 0; data[13] = 0        // green
        data[14] = 0; data[15] = 0        // blue
        let clut = ResourceRenderers.parseCLUT(data)
        #expect(clut != nil)
        #expect(clut?.entries.count == 1)
        #expect(clut?.entries[0].1 == 0xFFFF)  // red
    }
}
