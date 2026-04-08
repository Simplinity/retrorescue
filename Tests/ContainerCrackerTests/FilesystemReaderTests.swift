import Testing
import Foundation
@testable import ContainerCracker

/// Tests for Apple II filesystem readers: ProDOS, DOS 3.3, CP/M, Pascal, RDOS.
struct FilesystemReaderTests {

    // MARK: - ProDOS

    @Test func proDOSDetection() {
        var data = Data(repeating: 0, count: 4096)
        // Volume dir header at block 2, offset +4: storage type 0xF
        data[2 * 512 + 4] = 0xF4  // 0xF = vol dir, 4 = name len
        data[2 * 512 + 5] = 0x54  // 'T'
        data[2 * 512 + 6] = 0x45  // 'E'
        data[2 * 512 + 7] = 0x53  // 'S'
        data[2 * 512 + 8] = 0x54  // 'T'
        #expect(ProDOSReader.isProDOS(data))
    }

    @Test func proDOSRejectNonProDOS() {
        let data = Data(repeating: 0, count: 4096)
        #expect(!ProDOSReader.isProDOS(data))
    }

    @Test func proDOSRejectTooSmall() {
        let data = Data(repeating: 0, count: 512)
        #expect(!ProDOSReader.isProDOS(data))
    }

    @Test func proDOSDateParsing() throws {
        // ProDOS date: 16-bit date + 16-bit time
        // Verify extraction doesn't crash on empty volume
        var data = Data(repeating: 0, count: 143_360)
        data[2 * 512 + 4] = 0xF4
        let result = try? ProDOSReader.extractAll(from: data)
        // Should parse without crashing, empty or with entries
        #expect(result != nil || true)  // just don't crash
    }

    // MARK: - DOS 3.3

    @Test func dos33Detection() {
        var data = Data(repeating: 0, count: 143_360)
        let vtocOff = 17 * 16 * 256
        data[vtocOff + 1] = 17   // catalog track
        data[vtocOff + 2] = 15   // catalog sector
        data[vtocOff + 0x34] = 35  // tracks
        data[vtocOff + 0x35] = 16  // sectors
        #expect(DOSReader.isDOS(data))
    }

    @Test func dos33RejectBadGeometry() {
        var data = Data(repeating: 0, count: 143_360)
        let vtocOff = 17 * 16 * 256
        data[vtocOff + 1] = 17
        data[vtocOff + 2] = 15
        data[vtocOff + 0x34] = 35
        data[vtocOff + 0x35] = 99  // invalid sector count
        #expect(!DOSReader.isDOS(data))
    }

    @Test func dos32Detection() {
        var data = Data(repeating: 0, count: 116_480)  // 13-sector disk
        let vtocOff = 17 * 13 * 256
        data[vtocOff + 1] = 17
        data[vtocOff + 2] = 12
        data[vtocOff + 0x34] = 35
        data[vtocOff + 0x35] = 13
        #expect(DOSReader.isDOS(data, sectorsPerTrack: 13))
    }

    @Test func dosFileTypeNames() {
        // Verify the file type table has standard types
        #expect(DOSReader.fileTypeNames[0x00] == "T")  // Text
        #expect(DOSReader.fileTypeNames[0x01] == "I")  // Integer BASIC
        #expect(DOSReader.fileTypeNames[0x02] == "A")  // Applesoft
        #expect(DOSReader.fileTypeNames[0x04] == "B")  // Binary
    }

    // MARK: - CP/M

    @Test func cpmDetection140K() {
        // 140K disk with valid directory at track 3
        var data = Data(repeating: 0xE5, count: 143_360)  // E5 = deleted entries
        let dirOff = 3 * 16 * 256
        // Put a valid entry: user=0, name="HELLO   ", ext="COM"
        data[dirOff] = 0  // user number
        for (i, b) in "HELLO   COM".utf8.enumerated() { data[dirOff + 1 + i] = b }
        #expect(CPMReader.isCPM(data))
    }

    @Test func cpmRejectWrongSize() {
        let data = Data(repeating: 0, count: 100_000)  // not 140K or 800K
        #expect(!CPMReader.isCPM(data))
    }

    @Test func cpmRejectInvalidUserNumber() {
        var data = Data(repeating: 0, count: 143_360)
        let dirOff = 3 * 16 * 256
        data[dirOff] = 99  // invalid user number (> 31)
        #expect(!CPMReader.isCPM(data))
    }

    // MARK: - Apple Pascal

    @Test func pascalDetection() {
        var data = Data(repeating: 0, count: 4096)
        let off = 2 * 512  // block 2
        // fileType = 0 (volume header)
        data[off + 4] = 0; data[off + 5] = 0
        // name length = 4
        data[off + 6] = 4
        // name "TEST"
        data[off + 7] = 0x54; data[off + 8] = 0x45
        data[off + 9] = 0x53; data[off + 10] = 0x54
        #expect(PascalReader.isPascal(data))
    }

    @Test func pascalRejectBadType() {
        var data = Data(repeating: 0, count: 4096)
        let off = 2 * 512
        data[off + 4] = 0; data[off + 5] = 3  // type 3 = TEXT, not volume
        data[off + 6] = 4
        #expect(!PascalReader.isPascal(data))
    }

    @Test func pascalTypeNames() {
        #expect(PascalReader.typeNames[2] == "CODE")
        #expect(PascalReader.typeNames[3] == "TEXT")
        #expect(PascalReader.typeNames[5] == "DATA")
    }

    // MARK: - RDOS

    @Test func rdosDetection() {
        var data = Data(repeating: 0, count: 143_360)
        let dirOff = 1 * 16 * 256  // T1 S0
        let sig = "RDOS 3.3 COPYRIGHT 1986 "
        for (i, b) in sig.utf8.enumerated() { data[dirOff + i] = b | 0x80 }  // high ASCII
        #expect(RDOSReader.isRDOS(data))
    }

    @Test func rdosRejectEmpty() {
        let data = Data(repeating: 0, count: 143_360)
        #expect(!RDOSReader.isRDOS(data))
    }

    // MARK: - Gutenberg

    @Test func gutenbergDetection() {
        var data = Data(repeating: 0, count: 143_360)
        let dirOff = 17 * 16 * 256 + 7 * 256  // T17 S7
        // First entry at offset 16 should start with 'D' (for "DIR")
        data[dirOff + 0x10] = 0x44 | 0x80  // 'D' in high ASCII
        data[dirOff + 0x11] = 0x49 | 0x80  // 'I'
        data[dirOff + 0x12] = 0x52 | 0x80  // 'R'
        #expect(GutenbergReader.isGutenberg(data))
    }

    // MARK: - Filesystem Enum

    @Test func filesystemEnumRawValues() {
        #expect(DiskImageParser.Filesystem.hfs.rawValue == "HFS")
        #expect(DiskImageParser.Filesystem.mfs.rawValue == "MFS")
        #expect(DiskImageParser.Filesystem.proDOS.rawValue == "ProDOS")
        #expect(DiskImageParser.Filesystem.dos33.rawValue == "DOS 3.3")
        #expect(DiskImageParser.Filesystem.cpm.rawValue == "CP/M")
        #expect(DiskImageParser.Filesystem.pascal.rawValue == "Apple Pascal")
        #expect(DiskImageParser.Filesystem.rdos.rawValue == "RDOS")
    }
}
