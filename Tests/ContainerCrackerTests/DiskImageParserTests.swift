import Testing
import Foundation
@testable import ContainerCracker

/// R4: DiskImageParser tests — format detection, header parsing, routing.
struct DiskImageParserTests {

    // MARK: - Format Detection

    @Test func detectDiskCopy42() {
        // DiskCopy 4.2: magic 0x0100 at offset 82-83, name length at byte 0
        var data = Data(repeating: 0, count: 1024)
        data[0] = 10  // name length
        data[82] = 0x01; data[83] = 0x00  // magic
        #expect(DiskImageParser.detect(data: data) == .diskCopy42)
    }

    @Test func detectRawNotDiskCopy() {
        // All zeros should not be detected as DiskCopy
        let data = Data(repeating: 0, count: 1024)
        let format = DiskImageParser.detect(data: data)
        #expect(format != .diskCopy42)
    }

    @Test func detectAPM() {
        // APM: 'ER' at offset 0, 'PM' at offset 512
        var data = Data(repeating: 0, count: 2048)
        data[0] = 0x45; data[1] = 0x52  // 'ER'
        data[512] = 0x50; data[513] = 0x4D  // 'PM'
        #expect(DiskImageParser.detect(data: data) == .apm)
    }

    @Test func detectMacTS() {
        // MacTS: 'ER' at offset 0, 'TS' at offset 512
        var data = Data(repeating: 0, count: 2048)
        data[0] = 0x45; data[1] = 0x52  // 'ER'
        data[512] = 0x54; data[513] = 0x53  // 'TS'
        #expect(DiskImageParser.detect(data: data) == .macTS)
    }

    // MARK: - Filesystem Detection

    @Test func detectHFSFilesystem() {
        // HFS signature 'BD' at offset 1024-1025
        var data = Data(repeating: 0, count: 2048)
        data[1024] = 0x42; data[1025] = 0x44  // 'BD'
        #expect(DiskImageParser.detectFilesystem(rawData: data) == .hfs)
    }

    @Test func detectMFSFilesystem() {
        // MFS signature 0xD2D7 at offset 1024-1025
        var data = Data(repeating: 0, count: 2048)
        data[1024] = 0xD2; data[1025] = 0xD7
        #expect(DiskImageParser.detectFilesystem(rawData: data) == .mfs)
    }

    @Test func detectProDOSFilesystem() {
        // ProDOS: volume dir header 0xFx at block 2 offset +4
        var data = Data(repeating: 0, count: 4096)
        data[2 * 512 + 4] = 0xF4  // storage type 0xF (vol dir header), name len 4
        #expect(DiskImageParser.detectFilesystem(rawData: data) == .proDOS)
    }

    @Test func detectDOS33Filesystem() {
        // DOS 3.3: VTOC at T17/S0, valid track/sector counts
        var data = Data(repeating: 0, count: 143_360)
        let vtocOff = 17 * 16 * 256  // T17 S0
        data[vtocOff + 1] = 17   // catalog track
        data[vtocOff + 2] = 15   // catalog sector
        data[vtocOff + 0x34] = 35  // num tracks
        data[vtocOff + 0x35] = 16  // num sectors
        #expect(DiskImageParser.detectFilesystem(rawData: data) == .dos33)
    }
}
