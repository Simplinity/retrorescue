# RetroRescue — Complete Feature TODO List

> Master checklist — updated April 10, 2026.
> ✅ = done | ❌ = v1 todo | 🔮 = v2

---

## A. VAULT CORE — ✅ 12/12 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| A1 | Create .retrovault bundles (SQLite + files/ + manifest.json) | ✅ |
| A2 | Open existing .retrovault | ✅ |
| A3 | Add files via drag & drop from Finder | ✅ |
| A4 | Delete files (with recursive descendant cleanup) | ✅ |
| A5 | Vault library — remember + reopen recently used vaults | ✅ |
| A6 | Back button to return to vault library | ✅ |
| A7 | Per-file meta.json for crash recovery | ✅ |
| A8 | Full-text search (FTS5 + .searchable UI) | ✅ |
| A9 | Export file from vault to Finder | ✅ |
| A10 | Reveal in Finder (temp file with rsrc fork xattr) | ✅ |
| A11 | Get Info panel (extended metadata sheet) | ✅ |
| A12 | Copy submenu (name / type-creator / SHA-256) | ✅ |

## B. ENCODING WRAPPERS — ✅ 6/6 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| B1 | MacBinary I/II/III parser (native Swift) | ✅ |
| B2 | BinHex 4.0 parser (native Swift) | ✅ |
| B3 | AppleSingle parser (native Swift) | ✅ |
| B4 | AppleDouble parser (native Swift) | ✅ |
| B5 | MacBinary CRC-16/XMODEM verified vs CiderPress2 | ✅ |
| B6 | AppleDouble version/FileDates/LE variant verified vs CP2 | ✅ |


## C. ARCHIVE EXTRACTION — ✅ 22/22 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| C1–C18 | All unar/lsar formats (StuffIt, Compact Pro, ZIP, RAR, etc.) | ✅ |
| C19 | NuFX (ShrinkIt) via unar | ✅ |
| C20 | __MACOSX ZIP handling (auto-pair ._ files) | ✅ |
| C21 | Binary II (.bny .bqy) native parser | ✅ |
| C22 | AppleLink PE (.acu) native parser | ✅ |

## D. DISK IMAGE FORMATS — ✅ 15/16 (1 = v2)

| # | Feature | Status |
|---|---------|--------|
| D1 | DiskCopy 4.2 — header parsing + raw data extraction | ✅ |
| D2 | DiskCopy 4.2 — checksum validation (rotate-and-add, CP2 parity) | ✅ |
| D3 | DiskCopy 4.2 — tag data preservation | ✅ |
| D4 | DiskCopy 4.2 — disk description string extraction | ✅ |
| D5 | DiskCopy 4.2 — write support (create images) | 🔮 v2 |
| D6 | DART — RLE decompression | ✅ |
| D7 | DART — LZHUF decompression (adaptive Huffman + LZ77) | ✅ |
| D8 | DART — full format detection | ✅ |
| D9 | NDIF (DiskCopy 6.x) via hdiutil | ✅ |
| D10 | UDIF (.dmg) via hdiutil | ✅ |
| D11 | Raw disk images (.dsk, .hfv, .raw) | ✅ |
| D12 | Hybrid ISO 9660/HFS detection | ✅ |
| D13 | 2IMG format (.2mg, .2img) — header + extraction | ✅ |
| D14 | WOZ format (.woz) — detection + info display | ✅ |
| D15 | MOOF format (.moof) — detection + info display | ✅ |
| D16 | Sector order detection (.do/.po/.dsk) | ✅ |

## E. FILESYSTEMS — ✅ 9/12 (3 = v2)

| # | Feature | Status |
|---|---------|--------|
| E1 | HFS read via hfsutils (bundled hmount/hls/hcopy) | ✅ |
| E2 | HFS — native Swift reader (port CP2 ~5,000 lines) | 🔮 v2 |
| E3 | HFS — write support | 🔮 v2 |
| E4 | MFS detection (magic 0xD2D7) | ✅ |
| E5 | MFS — native Swift reader (283 lines, 12-bit alloc map) | ✅ |
| E6 | HFS+ read | 🔮 v2 |
| E7 | ProDOS reader (seedling/sapling/tree, GS/OS extended) | ✅ |
| E8 | DOS 3.2/3.3 reader (VTOC, T/S lists, 7 file types) | ✅ |
| E9 | CP/M reader (140K + 800K, multi-extent, 32-byte entries) | ✅ |
| E10 | Gutenberg WP reader (doubly-linked sectors) | ✅ |
| E11 | Apple Pascal reader (contiguous blocks, UCSD) | ✅ |
| E12 | RDOS reader (SSI games, 3 variants) | ✅ |


## F. PARTITIONS — ✅ 7/7 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| F1 | Apple Partition Map (APM) — DDR + partition entries | ✅ |
| F2 | Mac TS (pre-APM) — 'TS' signature, 12-byte entries | ✅ |
| F3 | CFFA partitions (32MB boundaries) | ✅ |
| F4 | AmDOS/OzDOS/UniDOS (dual 400K volumes) | ✅ |
| F5 | FocusDrive/MicroDrive (HD partitions) | ✅ |
| F6 | PPM (Pascal ProFile Manager) — stub | ✅ |
| F7 | DOS hybrids (multi-filesystem disks) | ✅ |

## G. COMPRESSION — ✅ 5/5 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| G1 | DART RLE (word-oriented run-length encoding) | ✅ |
| G2 | LZHUF (adaptive Huffman + LZ77, ~250 lines) | ✅ |
| G3 | PackBits (MacPaint RLE, ~55 lines) | ✅ |
| G4 | LZW/1 + LZW/2 (NuFX ShrinkIt) | ✅ |
| G5 | Squeeze (RLE + semi-adaptive Huffman) | ✅ |


## H. RESOURCE FORK BROWSER — ✅ 19/19 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| H1 | Resource fork binary parser (Mac map traversal) | ✅ |
| H2 | Type list display (grouped by 4-char code) | ✅ |
| H3 | Resource listing (ID, name, size, attributes) | ✅ |
| H4 | Known resource type registry (50+ types) | ✅ |
| H5 | ICON / ICN# renderer (32×32, 1-bit with mask) | ✅ |
| H6 | icl4 / icl8 renderer (32×32, 4/8-bit color) | ✅ |
| H7 | ics# / ics4 / ics8 renderer (16×16 small icons) | ✅ |
| H8 | cicn renderer (color icon, 1-bit fallback) | ✅ |
| H9 | snd resource parser (sample rate, channels, encoding) | ✅ |
| H10 | vers resource parser (major.minor.fix, stage, strings) | ✅ |
| H11 | STR / STR# display (Pascal strings, string lists) | ✅ |
| H12 | MENU resource display (items, key equivalents) | ✅ |
| H13 | DITL / DLOG display (dialog items with rects) | ✅ |
| H14 | FOND / FONT / NFNT display (bitmap font metrics) | ✅ |
| H15 | CODE resource info (68K segments) | ✅ |
| H16 | BNDL / FREF display (file type associations) | ✅ |
| H17 | CURS / crsr renderer (cursors) | ✅ |
| H18 | ppat / PAT renderer (patterns) | ✅ |
| H19 | clut renderer (color lookup tables) | ✅ |

## I. PREVIEW ENGINE — ✅ 12/12 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| I1 | Text preview — MacRoman → UTF-8, 150+ extensions | ✅ |
| I2 | Text preview — classic Mac type codes (TEXT, ttro) | ✅ |
| I3 | Quick Look via qlmanage | ✅ |
| I4 | Open in default macOS app | ✅ |
| I5 | PICT inline preview (sips → PNG) | ✅ |
| I6 | Hex dump fallback (every file shows something) | ✅ |
| I7 | MacPaint preview (PackBits → 576×720 PNG) | ✅ |
| I8 | Icon preview from resource fork (best-quality cascade) | ✅ |
| I9 | Sound preview (snd → WAV converter) | ✅ |
| I10 | Font preview (bitmap font metrics display) | ✅ |
| I11 | Waveform visualization for audio | ✅ |
| I12 | Resource fork overview (type count + summary) | ✅ |


## J. CONVERSION ENGINE — ✅ 10/13 (3 = v2)

| # | Feature | Status |
|---|---------|--------|
| J1 | PICT → PNG via sips | ✅ |
| J2 | PICT → JPEG via sips | ✅ |
| J3 | MacPaint → PNG (PackBits + NSImage) | ✅ |
| J4 | ICON/ICN#/icl4/icl8 → PNG | ✅ |
| J5 | snd → WAV (RIFF builder) | ✅ |
| J6 | TEXT MacRoman → UTF-8 .txt | ✅ |
| J7 | Bitmap font → BDF export | ✅ (v2: → TTF) |
| J8 | QuickTime → MP4 via ffmpeg | ✅ |
| J9 | ClarisWorks → Markdown (text extraction) | ✅ (v2: full formatting) |
| J10 | MacWrite → Markdown (text extraction) | ✅ (v2: full formatting) |
| J11 | Batch export (vault → dir + metadata.json + xattr) | ✅ |
| J12 | Restore mode (vault → AppleDouble for emulators) | ✅ |
| J13 | Plain text charset conversion (MacRoman/Cyrillic/Greek) | ✅ |

## K. UI/UX — ✅ 19/19 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| K1 | Left panel — vault archive list | ✅ |
| K2 | Right panel — archive info + file browser + inspector | ✅ |
| K3 | Columns in file browser (name/type-creator/size) | ✅ |
| K4 | Mini-inspector (icon, name, type, metadata, history) | ✅ |
| K5 | Historical file type context (40+ types) | ✅ |
| K6 | Apple HIG context menus with SF Symbols | ✅ |
| K7 | Dashboard-style extract prompt | ✅ |
| K8 | Archive icons orange, green checkmark for extracted | ✅ |
| K9 | File type descriptions (100+ types) | ✅ |
| K10 | Selective import sheet (checkboxes, grouped by folder) | ✅ |
| K11 | Toolbar search bar (wired to FTS5) | ✅ |
| K12 | Filter popover (type code / creator / has-rsrc) | ✅ |
| K13 | Grid view (LazyVGrid + thumbnails + SF Symbols) | ✅ |
| K14 | Column view (breadcrumbs + folders/files split) | ✅ |
| K15 | Keyboard navigation (Space/Enter/Delete) | ✅ |
| K16 | Drag from vault to Finder (lazy NSItemProvider) | ✅ |
| K17 | Window title shows vault name + item count | ✅ |
| K18 | Preferences panel (view mode, hex size, export settings) | ✅ |
| K19 | Progress sheet during long operations | ✅ |

## L. THUMBNAILS & SEARCH — ✅ 8/8 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| L1 | Thumbnail for PICT files (128×128 PNG via sips) | ✅ |
| L2 | Thumbnail for icons (largest variant from rsrc fork) | ✅ |
| L3 | Thumbnail for TEXT files (first 4 lines as image) | ✅ |
| L4 | Thumbnail for sounds (waveform mini-viz) | ✅ |
| L5 | Thumbnail storage in vault thumbnails/{id}.png | ✅ |
| L6 | Rebuild Thumbnails command (async + progress) | ✅ |
| L7 | Quick Look plugin (.retrovault preview in Finder) | ✅ |
| L8 | Spotlight importer (Core Spotlight indexing) | ✅ |


## M. WEB INTEGRATION — ✅ 4/4 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| M1 | Drag URL from browser → download + extract + store | ✅ |
| M2 | Content-Disposition header parsing for filenames | ✅ |
| M3 | Macintosh Garden / Repository page scraper | ✅ |
| M4 | Download history tracking (download-history.json) | ✅ |


## N. EMULATOR BRIDGE — ✅ 3/3 COMPLETE

| # | Feature | Status |
|---|---------|--------|
| N1 | Create HFS disk images (hformat + hcopy pipeline) | ✅ |
| N2 | SheepShaver/Basilisk II shared folder (AppleDouble) | ✅ |
| N3 | Send to Emulator action (shared folder or .dsk image) | ✅ |

## O. DISTRIBUTION — 1/6 (4 = v1 todo, 1 = v2)

| # | Feature | Status |
|---|---------|--------|
| O1 | Code signing + notarization script | ✅ |
| O2 | DMG installer with background + drag-to-Applications | ❌ v1 |
| O3 | Sparkle auto-update framework | ❌ v1 |
| O4 | Homebrew cask formula | ❌ v1 |
| O5 | retrorescue.app website | ❌ v1 |
| O6 | App Store (sandbox version) | 🔮 v2 |


## P. ADVANCED — 0/8 (all v2)

| # | Feature | Status |
|---|---------|--------|
| P1 | Vault merge (deduplicate by SHA-256) | 🔮 v2 |
| P2 | Vault diff (compare two vaults) | 🔮 v2 |
| P3 | Collection statistics dashboard | 🔮 v2 |
| P4 | Catalog export (static HTML browsable site) | 🔮 v2 |
| P5 | Cross-vault duplicate detection | 🔮 v2 |
| P6 | Provenance graph (archive → files → exports) | 🔮 v2 |
| P7 | Batch import from folder (recursive auto-detect) | 🔮 v2 |
| P8 | RetroGate URL scheme integration | 🔮 v2 |

## Q. TOOLCHAIN — ✅ 9/11 (2 = v2)

| # | Feature | Status |
|---|---------|--------|
| Q1 | ToolChain: bundled > system > homebrew priority | ✅ |
| Q2 | unar bundled (2.2 MB, LGPL 2.1) | ✅ |
| Q3 | lsar bundled (2.3 MB, LGPL 2.1) | ✅ |
| Q4 | hfsutils bundled (hmount/hls/hcopy/humount, GPL 2.0) | ✅ |
| Q5 | hformat bundled (create HFS images) | ✅ |
| Q6 | sips (macOS built-in) | ✅ |
| Q7 | qlmanage (macOS built-in) | ✅ |
| Q8 | hdiutil (macOS built-in) | ✅ |
| Q9 | lsar override path from ToolChain | ✅ |
| Q10 | Remove hfsutils → native Swift HFS | 🔮 v2 |
| Q11 | ffmpeg optional download (~80MB) | 🔮 v2 |


## R. TESTS — ✅ 11/11 COMPLETE (152 tests)

| # | Feature | Tests |
|---|---------|-------|
| R1 | MacBinary parser tests | 18 |
| R2 | BinHex parser tests | 7 |
| R3 | VaultEngine tests | 7 |
| R4 | DiskImageParser tests | 7 |
| R5 | DART + PackBits tests | 5 |
| R6 | APM parser tests | 6 |
| R7 | Resource fork parser tests | 9 |
| R8 | MFS reader tests | 4 |
| R9 | Compression tests (LZW, Squeeze, charset) | 8 |
| R10 | Conversion tests | 4 |
| R11 | Integration tests (full pipeline) | 6 |
| R+ | Filesystem reader tests | 17 |
| R+ | Archive parser tests | 10 |
| R+ | AppleDouble parser tests | 9 |
| R+ | Edge case tests | 32 |
| | **TOTAL** | **152** |



## S. DOCUMENTATION — 6/7 (1 = v1 todo)

| # | Feature | Status |
|---|---------|--------|
| S1 | README.md with feature overview | ✅ |
| S2 | ARCHITECTURE.md (module structure) | ✅ |
| S3 | FORMATS.md (supported file formats reference) | ✅ |
| S4 | RELEASE-CHECKLIST.md (signing + notarization setup) | ✅ |
| S5 | V2-PLANNING.md (all deferred decisions) | ✅ |
| S6 | Update plan.md to match 19-section reality | ✅ |
| S7 | User manual for retrorescue.app website | ❌ v1 |


---

## SUMMARY

| Metric | Count |
|--------|-------|
| **Total features** | 201 |
| **✅ Complete** | **178 (89%)** |
| **❌ v1 todo** | **6** |
| **🔮 v2 deferred** | **17** |
| **Test suites** | 17 |
| **Total tests** | 152 |
| **Test stability** | 5/5 runs, ~170-290ms |

### v1 Remaining (6 items)
- O2: DMG installer
- O3: Sparkle auto-update
- O4: Homebrew cask
- O5: Website
- S7: User manual

### v2 Deferred (17 items)
- D5, E2, E3, E6, J7+, J9+, J10+, O6, P1–P8, Q10, Q11

See `docs/V2-PLANNING.md` for detailed v2 decisions.
