# RetroRescue — CiderPress II Integration Plan

> CiderPress II (by Andy McFadden, Apache 2.0) is the gold standard for vintage Apple file
> handling. This plan maps CP2's features against RetroRescue, identifies gaps, and plans
> the work to bring RetroRescue to parity for Macintosh-relevant formats.

## Source: https://github.com/fadden/CiderPress2
## Docs: https://ciderpress2.com/doc-index.html
## License: Apache 2.0 (compatible with our GPLv3)

---

## 1. Feature Comparison: CiderPress II vs RetroRescue

### 1.1 Disk Image Formats

| Format | CP2 Status | RetroRescue Status | Gap | Priority |
|--------|-----------|-------------------|-----|----------|
| DiskCopy 4.2 | Full (read/write, checksum) | Read-only (strip header) | Missing: checksum validation, write support, tag data | HIGH |
| DART | Read (RLE + LZHUF) | RLE only | Missing: LZHUF decompression (~949 lines in CP2) | HIGH |
| Unadorned Block (.dsk .img .po .do) | Full | Partial (raw HFS only) | Missing: sector order detection (DOS vs ProDOS) | MED |
| 2IMG | Full | Not supported | Need parser (629 lines in CP2) | LOW |
| WOZ | Full | Not supported | Apple II-specific, low priority | LOW |
| MOOF | Full | Not supported | Apple II-specific, low priority | LOW |
| Trackstar | Full | Not supported | Apple II-specific, not needed | SKIP |
| NDIF (DiskCopy 6.x) | Not supported | Via hdiutil | We're ahead here | OK |
| UDIF (.dmg) | Not supported | Via hdiutil | We're ahead here | OK |

### 1.2 Filesystems

| Format | CP2 Status | RetroRescue Status | Gap | Priority |
|--------|-----------|-------------------|-----|----------|
| HFS | Full (read/write, 4GB) | Via hfsutils (read-only) | Missing: native Swift HFS reader | HIGH |
| MFS | Read-only | Detected, not extracted | Need native Swift MFS reader | MED |
| HFS+ | Not supported | Not supported | Both lack this | FUTURE |
| ProDOS | Full | Not needed (Mac focus) | N/A | SKIP |
| DOS 3.2/3.3 | Full | Not needed | N/A | SKIP |
| CP/M | Full | Not needed | N/A | SKIP |

### 1.3 Multi-Part / Partition Formats

| Format | CP2 Status | RetroRescue Status | Gap | Priority |
|--------|-----------|-------------------|-----|----------|
| Apple Partition Map (APM) | Read/write | Not implemented | CRITICAL gap — needed for CD-ROMs | HIGH |
| Mac 'TS' format | Read/write | Not implemented | Needed for early Mac hard drives | MED |
| ISO 9660 / Hybrid | Via unar | Via unar + HFS detection | Similar coverage | OK |

### 1.4 File Archives & Wrappers

| Format | CP2 Status | RetroRescue Status | Gap | Priority |
|--------|-----------|-------------------|-----|----------|
| MacBinary I/II/III | Read | Read (native Swift parser) | Comparable — compare implementations | VERIFY |
| AppleSingle | Read/extract | Read (native Swift parser) | Comparable — compare implementations | VERIFY |
| AppleDouble | Read/extract | Read (native Swift parser) | Comparable — compare implementations | VERIFY |
| ZIP (__MACOSX) | Full + __MACOSX | Via unar | CP2 has better Mac ZIP handling | MED |
| StuffIt | Not supported | Via unar | We're ahead | OK |
| Compact Pro | Not supported | Via unar | We're ahead | OK |
| NuFX (ShrinkIt) | Full | Via unar | CP2 is native, we shell out | LOW |
| gzip | Read/extract | Via unar | Similar | OK |

### 1.5 Compression Algorithms

| Algorithm | CP2 Status | RetroRescue Status | Gap | Priority |
|-----------|-----------|-------------------|-----|----------|
| LZHUF | Full (949 lines) | Not implemented | Needed for DART "best" mode | HIGH |
| LZW/1, LZW/2 | Full | N/A (NuFX-specific) | Not needed | SKIP |
| Squeeze (RLE+Huffman) | Full | N/A | Not needed | SKIP |
| PackBits | Not separate | Not implemented | Needed for MacPaint | MED |

### 1.6 File Conversion / Preview

| Format | CP2 Status | RetroRescue Status | Gap | Priority |
|--------|-----------|-------------------|-----|----------|
| Resource Fork browser | Full (type listing, hex dump) | Not implemented | CRITICAL gap | HIGH |
| Hex dump | Full (charset-aware) | Not implemented | Needed as fallback preview | HIGH |
| MacPaint (.PNTG) | Full (PackBits → PNG) | Not implemented | 189 lines in CP2 | MED |
| PICT | Not in CP2 | Via sips → PNG | We're ahead | OK |
| Plain text (MacRoman) | Full | Full (native) | Comparable | OK |
| Resource listing | Plain text output | Not implemented | Part of resource fork browser | HIGH |

---

## 2. Code Comparison: Our Implementations vs CiderPress II

### 2.1 DiskCopy 4.2 Parser

**CiderPress2** (629 lines, DiskCopy.cs):
- Full header parsing with all fields
- Checksum validation AND computation
- Tag data preservation (12 bytes/sector)
- Read/write support
- Handles first 12 bytes of tag excluded from checksum (backward compat)
- Metadata editing (disk description string)

**RetroRescue** (DiskImageParser.swift, ~50 lines for DC42):
- Header parsing: name, data size, tag size, disk format, magic check
- Strips 84-byte header → raw data
- ❌ No checksum validation
- ❌ No tag data preservation
- ❌ No write support
- ❌ No disk description extraction

**Action**: Port CP2's checksum algorithm. Add tag data preservation. Extract disk name.

### 2.2 MacBinary Parser

**CiderPress2** (234 lines, MacBinary.cs):
- Detects MacBinary I, II, III
- CRC-16/XMODEM validation for MB II+
- Handles 128-byte padding
- Extracts all Finder info fields

**RetroRescue** (MacBinaryParser.swift):
- Detects MacBinary I, II, III
- CRC validation
- Extracts type/creator, forks, dates
- 34 tests passing

**Action**: Compare CRC algorithm. Our implementation is likely adequate. Verify edge cases.

### 2.3 AppleSingle/AppleDouble Parser

**CiderPress2** (436 lines, AppleSingle.cs):
- Full entry type parsing (data fork, rsrc fork, real name, finder info, dates)
- Handles both AppleSingle (0x00051600) and AppleDouble (0x00051607)
- Version 1 and 2 support

**RetroRescue** (ContainerCracker):
- Basic parsing
- Handles both formats
- Used for unwrapping unar output

**Action**: Verify against CP2. Our implementation handles the critical path.

### 2.4 HFS Filesystem

**CiderPress2** (6,442 lines total across 10 files):
- HFS.cs (1,154): Main filesystem driver, format/scan/mount
- HFS_BTree.cs (1,126): Full B*-tree implementation (insert, delete, split, merge)
- HFS_MDB.cs (486): Master Directory Block parsing
- HFS_Record.cs (602): Catalog records (file, directory, thread)
- HFS_Struct.cs (658): All data structures from Inside Macintosh
- HFS_FileEntry.cs (1,010): File operations (read, write, rename, delete)
- HFS_FileDesc.cs (474): File descriptors for open files
- HFS_FileStorage.cs (463): Extent management
- HFS_Node.cs (689): B-tree node operations
- HFS_VolBitmap.cs (382): Volume bitmap (free/used blocks)

**RetroRescue** (HFSExtractor.swift, ~200 lines):
- Shells out to hfsutils (hmount/hls/hcopy/humount)
- No native HFS understanding
- Read-only, depends on external GPL tools

**Action**: This is the biggest gap. Options:
1. **Port CP2's HFS code to Swift** (~6,400 lines C# → ~5,000 lines Swift). Big effort.
2. **Keep hfsutils** for v1, plan native reader for v2.
3. **Use libhfs source** (C, GPL) as reference for a Swift port.

**Recommendation**: Keep hfsutils for v1.x. Begin native Swift HFS reader for v2 using
CP2's documentation and structure as reference. The B*-tree implementation is the hard part.

### 2.5 MFS Filesystem

**CiderPress2** (1,233 lines across 3 files):
- Full MFS parser: volume info, block map, directory traversal
- Read-only (appropriate — MFS volumes are historical artifacts)
- 12-bit allocation block map parsing

**RetroRescue**: Only detects MFS magic (0xD2D7). Cannot extract files.

**Action**: Port CP2's MFS reader. ~1,200 lines C# → ~900 lines Swift. Moderate effort.
This unlocks extraction of original 1984 Mac floppy disk images.

### 2.6 Apple Partition Map (APM)

**CiderPress2** (536 lines across 2 files):
- DDR parsing (block 0)
- Partition map traversal
- Finds Apple_HFS, Apple_MFS, Apple_Free, Apple_Driver partitions
- Handles malformed partition maps (tolerant parsing)

**RetroRescue**: Not implemented.

**Action**: Port CP2's APM parser. ~500 lines C# → ~350 lines Swift. This is CRITICAL for
handling CD-ROM images and multi-partition hard drive dumps.

### 2.7 LZHUF Compression

**CiderPress2** (949 lines, LZHufStream.cs):
- Port of classic LZHUF.C (Yoshizaki/Okumura)
- Streaming decompression
- Modified for DART: no leading length word, 0x00 window init

**RetroRescue**: Not implemented. DART "best" mode fails.

**Action**: Port LZHufStream to Swift. ~949 lines C# → ~700 lines Swift. Unlocks all DART images.

### 2.8 Resource Fork Parser

**CiderPress2** (457 lines, ResourceMgr.cs + 78 lines ResourceFork.cs):
- Full Macintosh resource fork parsing
- Type list, reference list, name list
- Resource extraction by type/ID
- Both Apple IIgs and Macintosh formats

**RetroRescue**: Not implemented.

**Action**: Port CP2's ResourceMgr to Swift. ~500 lines → ~400 lines Swift. CRITICAL for
Stage 5 (Resource Fork Browser) in our plan.

---

## 3. Implementation Roadmap

### Phase A: Critical Gaps (next sprint)

These block real-world usage and should be done first.

| Task | Source | Effort | Lines (est.) |
|------|--------|--------|-------------|
| A1: Apple Partition Map parser | CP2 APM.cs | 2 days | ~350 Swift |
| A2: LZHUF decompressor | CP2 LZHufStream.cs | 2 days | ~700 Swift |
| A3: Resource Fork parser | CP2 ResourceMgr.cs + IM:MTB | 2 days | ~400 Swift |
| A4: Hex dump preview (fallback) | CP2 HexDump.cs | 0.5 day | ~150 Swift |
| A5: DiskCopy checksum validation | CP2 DiskCopy.cs | 0.5 day | ~50 Swift |

**Total Phase A**: ~7 days, ~1,650 lines

After Phase A:
- CD-ROMs with APM → extract HFS partition → list files ✅
- All DART images (RLE + LZH) → extract ✅
- Resource fork browsing (type/ID/name listing) ✅
- Every file gets at least a hex dump preview ✅
- DiskCopy images verified by checksum ✅

### Phase B: Format Support Expansion

| Task | Source | Effort | Lines (est.) |
|------|--------|--------|-------------|
| B1: MFS filesystem reader | CP2 MFS*.cs | 3 days | ~900 Swift |
| B2: MacPaint decoder (PackBits) | CP2 MacPaint.cs | 1 day | ~200 Swift |
| B3: Resource type renderers | Custom | 3 days | ~600 Swift |
|     → ICON/ICN#/icl4/icl8 → PNG | | | |
|     → snd → WAV playback | | | |
|     → vers → formatted text | | | |
|     → STR/STR# → text display | | | |
| B4: MacTS partition format | CP2 MacTS.cs | 0.5 day | ~100 Swift |
| B5: __MACOSX ZIP handling | Custom | 1 day | ~200 Swift |

**Total Phase B**: ~8.5 days, ~2,000 lines

After Phase B:
- Original 1984 Mac floppies (MFS) → extract files ✅
- MacPaint images → PNG preview ✅
- Resource fork icons/sounds/strings → visual preview ✅
- Early Mac hard drive dumps (TS partitions) ✅
- Mac-style ZIP archives with resource forks ✅

### Phase C: Native HFS (v2.0)

| Task | Source | Effort | Lines (est.) |
|------|--------|--------|-------------|
| C1: HFS MDB parser | CP2 HFS_MDB.cs | 1 day | ~400 Swift |
| C2: HFS B*-tree engine | CP2 HFS_BTree.cs + HFS_Node.cs | 5 days | ~1,500 Swift |
| C3: HFS catalog traversal | CP2 HFS_Record.cs + HFS.cs | 3 days | ~1,000 Swift |
| C4: HFS file extraction | CP2 HFS_FileEntry/Desc/Storage | 3 days | ~1,200 Swift |
| C5: HFS volume bitmap | CP2 HFS_VolBitmap.cs | 1 day | ~300 Swift |
| C6: HFS write support | CP2 (full) | 5 days | ~1,500 Swift |

**Total Phase C**: ~18 days, ~5,900 lines

After Phase C:
- No dependency on hfsutils (bundled GPL binaries removed)
- Read AND write HFS volumes (create disk images for emulators)
- Direct block-level access for recovery/repair

---

## 4. Detailed Specifications to Add to file-formats.md

Based on CiderPress2's format documentation, the following specs should be added:

### 4.1 DiskCopy 4.2 (update existing)
- Exact header layout (from CP2 DiskCopy-notes.md)
- Checksum algorithm (custom, not CRC)
- Tag data format (12 bytes/sector, first 12 excluded from checksum)
- diskFormat values: 0=400K, 1=800K, 2=720K, 3=1440K
- formatByte values: $12=400K, $22=800K Mac, $24=800K IIgs

### 4.2 DART (update existing with CP2 details)
- Complete header structure from CP2 DART-notes.md
- RLE algorithm: word-oriented, positive=copy, negative=repeat
- LZHUF algorithm: modified Yoshizaki/Okumura, no length word, 0x00 init
- Block structure: 20960 bytes = 40×512 data + 40×12 tags
- Disk type identifiers (1=Mac, 2=Lisa, 3=Apple II, 16-18=HD)
- Type/Creator codes (DMd1-DMd7/DART)

### 4.3 Apple Partition Map (NEW)
- DDR structure (block 0): signature 'ER', block size, block count
- Partition entry structure (block 1+): signature 'PM', start/count, name/type
- Partition types: Apple_HFS, Apple_MFS, Apple_Driver, Apple_Free, etc.
- Real-world tolerance requirements (zero counts, oversized partitions)

### 4.4 HFS Filesystem (expand existing)
- MDB structure (162 bytes) at block 2
- B*-tree structure: header node, index nodes, leaf nodes
- Catalog file: keys (parentCNID + filename), 4 record types
- Extents overflow: keys (fork + fileCNID + startBlock)
- CNID system: reserved 0-15, root=2, parent-of-root=1
- Volume bitmap: one bit per allocation block
- Filename sorting: case-insensitive with custom table
- Timestamps: unsigned 32-bit, seconds since Jan 1, 1904

### 4.5 MFS Filesystem (expand existing)
- Volume Info structure at block 2 (signature 0xD2D7)
- 12-bit allocation block map
- Flat directory structure (no real folders)
- File directory entries: 51 bytes + filename
- Max 255-char filenames (64K ROM), 31 chars recommended (128K+)

### 4.6 Resource Fork Format (NEW)
- Macintosh format: header (16 bytes) → data area → map → name list
- Resource map: type list (4-byte type, count, ref list offset)
- Reference list: ID (16-bit), name offset, attributes, data offset (3 bytes)
- Resource attributes: sysHeap, purgeable, locked, protected, preload, changed
- Max fork size: 16MB (3-byte offset limitation)
- Known resource types table (40+ types with descriptions)

### 4.7 MacBinary (verify existing)
- CRC-16/XMODEM calculation for MacBinary II+
- 128-byte alignment requirement
- Finder flags: high byte in FInfo, low byte at +$65 (MB II)
- Secondary header at +$78 (never used in practice)

### 4.8 MacPaint (NEW)
- File structure: version (4 bytes) + patterns (304 bytes) + reserved + bitmap
- PackBits decompression: flag-counter byte + data
- 720 rows, each compressed independently
- 576×720 pixels, 1-bit, leftmost pixel = high bit

---

## 5. CiderPress II Source Files Reference

All source at: https://github.com/fadden/CiderPress2 (Apache 2.0)
Clone cached at: /tmp/CiderPress2/

### Mac-Relevant Source Files

```
DiskArc/Disk/
├── DART.cs                (431 lines)  — DART disk image parser + RLE decompressor
├── DART-notes.md          (94 lines)   — Format specification
├── DiskCopy.cs            (629 lines)  — DiskCopy 4.2 full implementation
├── DiskCopy-notes.md      (68 lines)   — Format specification
└── UnadornedSector.cs     (varies)     — Raw .dsk/.img/.po/.do handler

DiskArc/FS/
├── HFS.cs                 (1,154)  — Main HFS filesystem driver
├── HFS_BTree.cs           (1,126)  — B*-tree insert/delete/search/split
├── HFS_MDB.cs             (486)    — Master Directory Block parser
├── HFS_Record.cs          (602)    — Catalog record types (file/dir/thread)
├── HFS_Struct.cs          (658)    — All IM:Files data structures
├── HFS_FileEntry.cs       (1,010)  — File CRUD operations
├── HFS_FileDesc.cs        (474)    — Open file descriptor
├── HFS_FileStorage.cs     (463)    — Extent chain management
├── HFS_Node.cs            (689)    — B-tree node operations
├── HFS_VolBitmap.cs       (382)    — Free/used block tracking
├── HFS-notes.md           (700+)   — Comprehensive HFS specification
├── MFS.cs                 (462)    — MFS filesystem driver
├── MFS_MDB.cs             (252)    — MFS volume info parser
├── MFS_FileEntry.cs       (423)    — MFS file entry + block map
├── MFS_FileDesc.cs        (348)    — MFS file descriptor
└── MFS-notes.md           (200+)   — MFS specification

DiskArc/Multi/
├── APM.cs                 (478)    — Apple Partition Map parser
├── APM_Partition.cs       (58)     — Partition descriptor
├── APM-notes.md           (200+)   — APM specification
└── MacTS.cs               (187)    — Early Mac 'TS' partition format

DiskArc/Comp/
└── LZHufStream.cs         (949)    — LZHUF streaming decompressor

DiskArc/Arc/
├── AppleSingle.cs         (436)    — AppleSingle/Double parser
├── AppleSingle-notes.md   — Format specification
├── MacBinary.cs           (234)    — MacBinary I/II/III parser
└── MacBinary-notes.md     — Format specification

FileConv/
├── ResourceMgr.cs         (457)    — Macintosh resource fork parser
├── Generic/ResourceFork.cs (78)    — Resource fork formatter
├── Generic/HexDump.cs     (199)    — Hex dump with charset support
├── Gfx/MacPaint.cs        (189)    — MacPaint PackBits → bitmap
└── Generic/PlainText.cs   (varies) — Text encoding conversion
```

### Total Mac-Relevant Code in CP2: ~12,800 lines C#

Estimated Swift port: ~9,500 lines (Swift is more concise)

---

## 6. Where RetroRescue Is AHEAD of CiderPress II

Not everything needs to come from CP2. RetroRescue has strengths CP2 lacks:

| Feature | RetroRescue | CiderPress II |
|---------|------------|---------------|
| NDIF (.img) support | Via hdiutil | Not supported |
| UDIF (.dmg) support | Via hdiutil | Not supported |
| StuffIt (.sit, .sitx) | Via unar (40+ formats) | Not supported |
| Compact Pro (.cpt) | Via unar | Not supported |
| DiskDoubler (.dd) | Via unar | Not supported |
| PICT → PNG conversion | Via sips | Not supported |
| .retrovault preservation format | Full | Not applicable |
| Historical file type info | 40+ types with context | Not applicable |
| Selective import UI | Full (checkboxes per file) | CLI only |
| macOS-native SwiftUI app | Full | Windows WPF (Wine on Mac) |
| Vault library / recent vaults | Full | Not applicable |
| Inline text preview (150+ ext) | Full | Different approach |

---

## 7. Updated Implementation Priority

Combining all information, the recommended order is:

### Sprint 1: Foundation (Phase A) — ~7 days
1. **A1: APM parser** → unlocks CD-ROMs
2. **A3: Resource Fork parser** → unlocks Stage 5
3. **A4: Hex dump fallback** → every file previewable
4. **A5: DiskCopy checksum** → data integrity
5. **A2: LZHUF decompressor** → all DART images

### Sprint 2: Format Expansion (Phase B) — ~8.5 days
6. **B1: MFS reader** → 1984 floppies
7. **B2: MacPaint decoder** → .PNTG preview
8. **B3: Resource renderers** → icons, sounds, strings
9. **B4: MacTS partitions** → early hard drives
10. **B5: __MACOSX ZIP** → better Mac ZIP handling

### Sprint 3: Native HFS (Phase C) — ~18 days
11. **C1-C5: Native HFS reader** → remove hfsutils dependency
12. **C6: HFS write** → create disk images for emulators

### Total estimated effort: ~33.5 days, ~9,500 lines of new Swift code

---

*Document created: April 2026*
*Based on CiderPress II v1.1.1 source code analysis*
*License: CiderPress II source is Apache 2.0, compatible with RetroRescue's GPLv3*
