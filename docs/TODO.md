# RetroRescue — Complete Feature TODO List

> Master checklist. Every item from the original plan + CiderPress II parity.
> ✅ = done, 🔧 = partial, ❌ = not started, 🔮 = v2

---

## A. VAULT CORE

| # | Feature | Status |
|---|---------|--------|
| A1 | Create .retrovault bundles (SQLite + files/ + manifest.json) | ✅ |
| A2 | Open existing .retrovault | ✅ |
| A3 | Add files via drag & drop from Finder | ✅ |
| A4 | Delete files (with recursive descendant cleanup) | ✅ |
| A5 | Vault library — remember + reopen recently used vaults | ✅ |
| A6 | Back button to return to vault library | ✅ |
| A7 | Per-file meta.json for crash recovery | ✅ |
| A8 | Full-text search (FTS5 in SQLite) | 🔧 scaffold in DB, not wired to UI |
| A9 | Export file from vault to Finder | ❌ |
| A10 | "Reveal in Finder" for exported files | ❌ |
| A11 | "Get Info" panel (extended metadata) | ❌ |
| A12 | Copy file path / metadata to clipboard | ❌ |


## B. ENCODING WRAPPERS (auto-unwrap on import)

| # | Feature | Status |
|---|---------|--------|
| B1 | MacBinary I/II/III parser (native Swift) | ✅ 34 tests |
| B2 | BinHex 4.0 parser (native Swift) | ✅ 34 tests |
| B3 | AppleSingle parser (native Swift) | ✅ |
| B4 | AppleDouble parser (native Swift) | ✅ |
| B5 | Verify MacBinary CRC against CiderPress2 impl | ❌ |
| B6 | Verify AppleSingle/Double edge cases vs CP2 | ❌ |


## C. ARCHIVE EXTRACTION

| # | Feature | Status |
|---|---------|--------|
| C1 | StuffIt (.sit, .sitx) via unar | ✅ |
| C2 | Compact Pro (.cpt) via unar | ✅ |
| C3 | DiskDoubler (.dd) via unar | ✅ |
| C4 | PackIt (.pit) via unar | ✅ |
| C5 | Self-extracting archives (.sea) via unar | ✅ |
| C6 | ZIP via unar | ✅ |
| C7 | RAR via unar | ✅ |
| C8 | 7-Zip via unar | ✅ |
| C9 | LHA/LZH via unar | ✅ |
| C10 | ARC, Zoo, ARJ via unar | ✅ |
| C11 | gzip, bzip2, XZ, Zstandard via unar | ✅ |
| C12 | tar, tar.gz, tar.bz2 etc via unar | ✅ |
| C13 | ISO 9660 disc images via unar | ✅ |
| C14 | NRG (Nero), BIN/CUE via unar | ✅ |
| C15 | Compound extensions (.mar.xz, .tar.gz) | ✅ |
| C16 | Recursive nested extraction (unlimited depth) | ✅ |
| C17 | Selective import — "Extract Selected…" for ALL archives | ✅ (via lsar -j) |
| C18 | Selective import — "Extract Selected…" for HFS images | ✅ (via hls) |
| C19 | NuFX (ShrinkIt) (.shk .sdk .bxy) via unar | ✅ via unar |
| C20 | __MACOSX handling in ZIP archives | ❌ CP2 has this |
| C21 | Binary II (.bny .bqy) | ❌ CP2 has this |
| C22 | AppleLink PE (.acu) | ❌ CP2 has this |


## D. DISK IMAGE FORMATS

| # | Feature | Status |
|---|---------|--------|
| D1 | DiskCopy 4.2 — header parsing + raw data extraction | ✅ |
| D2 | DiskCopy 4.2 — checksum validation (CP2 algorithm) | ❌ |
| D3 | DiskCopy 4.2 — tag data preservation | ❌ |
| D4 | DiskCopy 4.2 — disk description string extraction | ❌ |
| D5 | DiskCopy 4.2 — write support (create images) | 🔮 v2 |
| D6 | DART — RLE decompression | ✅ |
| D7 | DART — LZHUF decompression (port CP2 LZHufStream.cs) | ❌ CRITICAL |
| D8 | DART — full format detection (srcCmp + srcType + srcSize) | ✅ |
| D9 | NDIF (DiskCopy 6.x) via hdiutil | ✅ |
| D10 | UDIF (.dmg) via hdiutil | ✅ |
| D11 | Raw disk images (.dsk, .hfv, .raw) | ✅ |
| D12 | Hybrid ISO 9660/HFS detection | ✅ |
| D13 | 2IMG format (.2mg, .2img) — CP2 has full support | ❌ |
| D14 | WOZ format (.woz) — CP2 has full support | ❌ Apple II focus |
| D15 | MOOF format (.moof) — CP2 has full support | ❌ Apple II focus |
| D16 | Unadorned block files (.do .po) sector order detection | ❌ |


## E. FILESYSTEMS

| # | Feature | Status |
|---|---------|--------|
| E1 | HFS read via hfsutils (bundled hmount/hls/hcopy) | ✅ |
| E2 | HFS — native Swift reader (port CP2: ~5,000 lines) | 🔮 v2 |
| E3 | HFS — write support (create volumes for emulators) | 🔮 v2 |
| E4 | MFS detection (magic 0xD2D7) | ✅ |
| E5 | MFS — native Swift reader (port CP2 MFS*.cs: ~900 lines) | ❌ |
| E6 | HFS+ read (macOS can mount natively) | 🔮 v2 |
| E7 | ProDOS — CP2 has full support | ❌ Apple II focus |
| E8 | DOS 3.2/3.3 — CP2 has full support | ❌ Apple II focus |
| E9 | CP/M for Apple II — CP2 has full support | ❌ Apple II focus |
| E10 | Gutenberg WP filesystem — CP2 has read | ❌ Apple II focus |
| E11 | Apple Pascal filesystem — CP2 has full | ❌ Apple II focus |
| E12 | RDOS — CP2 has read | ❌ Apple II focus |


## F. MULTI-PART / PARTITION FORMATS

| # | Feature | Status |
|---|---------|--------|
| F1 | Apple Partition Map (APM) — port CP2 APM.cs (~350 lines) | ❌ CRITICAL |
| F2 | Mac 'TS' early partition format — port CP2 MacTS.cs (~100 lines) | ❌ |
| F3 | CFFA partitions — CP2 has full | ❌ Apple II focus |
| F4 | AmDOS/OzDOS/UniDOS 800K — CP2 has full | ❌ Apple II focus |
| F5 | FocusDrive / MicroDrive — CP2 has full | ❌ Apple II focus |
| F6 | PPM (Pascal ProFile Manager) — CP2 has full | ❌ Apple II focus |
| F7 | DOS hybrids (DOS+ProDOS/Pascal/CP/M) — CP2 has full | ❌ Apple II focus |


## G. COMPRESSION ALGORITHMS (native)

| # | Feature | Status |
|---|---------|--------|
| G1 | DART RLE (word-oriented run-length encoding) | ✅ |
| G2 | LZHUF (port CP2 LZHufStream.cs, ~700 lines Swift) | ❌ CRITICAL |
| G3 | PackBits (for MacPaint, ~50 lines) | ❌ |
| G4 | LZW/1, LZW/2 (NuFX-specific) — CP2 has full | ❌ Apple II focus |
| G5 | Squeeze (RLE+Huffman, Binary II) — CP2 has full | ❌ Apple II focus |


## H. RESOURCE FORK BROWSER

| # | Feature | Status |
|---|---------|--------|
| H1 | Resource fork binary parser (port CP2 ResourceMgr.cs, ~400 lines) | ❌ CRITICAL |
| H2 | Type list display (grouped by 4-char type code) | ❌ |
| H3 | Resource listing: ID, name, size, attributes per resource | ❌ |
| H4 | Known resource type registry (40+ types with descriptions) | ❌ |
| H5 | ICON / ICN# renderer (32×32, 1-bit → PNG) | ❌ |
| H6 | icl4 / icl8 renderer (32×32, 4-bit/8-bit color → PNG) | ❌ |
| H7 | ics# / ics4 / ics8 renderer (16×16 small icons) | ❌ |
| H8 | cicn renderer (color icon with palette) | ❌ |
| H9 | snd resource parser + playback (8-bit PCM → WAV) | ❌ |
| H10 | vers resource parser (version string display) | ❌ |
| H11 | STR / STR# resource display (MacRoman → UTF-8) | ❌ |
| H12 | MENU resource display | ❌ |
| H13 | DITL / DLOG resource display (dialog layouts) | ❌ |
| H14 | FOND / FONT / NFNT resource display (bitmap fonts) | ❌ |
| H15 | CODE resource info (68K code segments) | ❌ |
| H16 | BNDL / FREF display (file type associations) | ❌ |
| H17 | CURS / crsr renderer (cursors) | ❌ |
| H18 | ppat / PAT renderer (patterns) | ❌ |
| H19 | clut renderer (color lookup tables) | ❌ |


## I. PREVIEW ENGINE

| # | Feature | Status |
|---|---------|--------|
| I1 | Text preview — MacRoman → UTF-8, 150+ extensions | ✅ |
| I2 | Text preview — classic Mac type codes (TEXT, ttro) | ✅ |
| I3 | Quick Look via qlmanage | ✅ |
| I4 | Open in default macOS app (PDF → Preview.app) | ✅ |
| I5 | PICT inline preview (sips → PNG in inspector) | ✅ |
| I6 | Hex dump fallback (every unknown file) — port CP2 HexDump.cs | ❌ CRITICAL |
| I7 | MacPaint preview (.PNTG, PackBits → PNG) — port CP2 MacPaint.cs | ❌ |
| I8 | Icon preview from resource fork (ICON/ICN#/icl4/icl8) | ❌ |
| I9 | Sound preview from resource fork (snd → WAV playback) | ❌ |
| I10 | Font preview from resource fork (FONT/NFNT bitmap rendering) | ❌ |
| I11 | Waveform visualization for audio | ❌ |
| I12 | Resource fork overview (type count + summary) | ❌ |


## J. CONVERSION ENGINE

| # | Feature | Status |
|---|---------|--------|
| J1 | PICT → PNG via sips (context menu) | ✅ |
| J2 | PICT → JPEG via sips | ❌ |
| J3 | MacPaint (.PNTG) → PNG (PackBits decoder) | ❌ |
| J4 | ICON/ICN#/icl4/icl8 → PNG | ❌ |
| J5 | snd resources → WAV | ❌ |
| J6 | TEXT (MacRoman) → UTF-8 .txt | ✅ (preview, not export) |
| J7 | Bitmap fonts (FONT/NFNT) → BDF / TTF | 🔮 v2 |
| J8 | QuickTime (legacy codecs) → H.264 MP4 via ffmpeg | 🔮 v2 |
| J9 | ClarisWorks → Markdown / DOCX | 🔮 v2 |
| J10 | MacWrite → Markdown / RTF | 🔮 v2 |
| J11 | Batch export (whole vault → modern formats + metadata.json) | 🔮 v2 |
| J12 | Restore mode (vault → emulator-ready files with resource forks) | 🔮 v2 |
| J13 | Plain text import/export with charset conversion (CP2 parity) | ❌ |


## K. UI / UX

| # | Feature | Status |
|---|---------|--------|
| K1 | Left panel — vault archive list | ✅ |
| K2 | Right panel — archive info + extracted file browser + inspector | ✅ |
| K3 | Columns in file browser (name / type-creator / size / indicators) | ✅ |
| K4 | Mini-inspector panel (icon, name, type, metadata grid, history) | ✅ |
| K5 | Historical file type context (40+ types) | ✅ |
| K6 | Apple HIG context menus with SF Symbols | ✅ |
| K7 | Dashboard-style extract prompt for unextracted archives | ✅ |
| K8 | Archive icons always orange, green checkmark for extracted | ✅ |
| K9 | File type descriptions (100+ via type code + extension) | ✅ |
| K10 | Selective import sheet (checkboxes per file, grouped by folder) | ✅ |
| K11 | Toolbar search bar (wired to FTS5) | ❌ |
| K12 | Filter by type code / creator / has-rsrc / date / size | ❌ |
| K13 | Icon view (grid of thumbnails) | ❌ |
| K14 | Column view (Finder-style) | ❌ |
| K15 | Keyboard navigation (arrows, Enter, Space for Quick Look) | ❌ |
| K16 | Drag from vault to Finder (export on drag) | ❌ |
| K17 | Window title shows vault name + file count | ❌ |
| K18 | Preferences panel (defaults, theme, vault location) | ❌ |
| K19 | Progress sheet during long extraction/import | ❌ |


## L. THUMBNAILS, SEARCH & POLISH

| # | Feature | Status |
|---|---------|--------|
| L1 | Thumbnail generation for PICT files (128×128 PNG) | ❌ |
| L2 | Thumbnail for icons (largest variant) | ❌ |
| L3 | Thumbnail for TEXT files (first 4 lines) | ❌ |
| L4 | Thumbnail for sounds (waveform mini-viz) | ❌ |
| L5 | Thumbnail storage in thumbnails/{id}.png | ❌ |
| L6 | "Rebuild Thumbnails" command | ❌ |
| L7 | Quick Look plugin (.retrovault → summary preview in Finder) | ❌ |
| L8 | Spotlight importer (index vault contents for macOS search) | ❌ |

## M. WEB INTEGRATION

| # | Feature | Status |
|---|---------|--------|
| M1 | Drag URL from browser → download + extract + store in vault | ❌ |
| M2 | Content-Disposition header parsing for real filenames | ❌ |
| M3 | Macintosh Garden / Macintosh Repository page scraper | ❌ |
| M4 | Download history tracking in vault | ❌ |


## N. VAULT → EMULATOR BRIDGE (v2)

| # | Feature | Status |
|---|---------|--------|
| N1 | Create HFS disk images from vault contents | 🔮 v2 |
| N2 | SheepShaver/Basilisk II shared folder export (AppleDouble) | 🔮 v2 |
| N3 | "Send to Emulator" action (create .dsk/.img) | 🔮 v2 |

## O. APP DISTRIBUTION

| # | Feature | Status |
|---|---------|--------|
| O1 | Code signing + notarization | ❌ |
| O2 | DMG installer with background image | ❌ |
| O3 | Sparkle auto-update framework | ❌ |
| O4 | Homebrew cask: `brew install --cask retrorescue` | ❌ |
| O5 | retrorescue.app website | ❌ |
| O6 | App Store consideration (reduced feature set, sandbox) | 🔮 v2 |

## P. ADVANCED FEATURES (v2+)

| # | Feature | Status |
|---|---------|--------|
| P1 | Vault merge (deduplicate by checksum) | 🔮 v2 |
| P2 | Vault diff (compare two vaults) | 🔮 v2 |
| P3 | Collection statistics dashboard | 🔮 v2 |
| P4 | Catalog export (static HTML browsable site) | 🔮 v2 |
| P5 | Duplicate detection across vaults | 🔮 v2 |
| P6 | Provenance graph (archive → files → exports) | 🔮 v2 |
| P7 | Batch import from folder (recursive auto-detect) | 🔮 v2 |
| P8 | RetroGate integration (URL scheme) | 🔮 v2 |


## Q. TOOLCHAIN & DEPENDENCIES

| # | Feature | Status |
|---|---------|--------|
| Q1 | ToolChain: bundled > system > homebrew priority | ✅ |
| Q2 | unar bundled in .app (2.2 MB, LGPL 2.1) | ✅ |
| Q3 | lsar bundled in .app (2.3 MB, LGPL 2.1) | ✅ |
| Q4 | hfsutils bundled in .app (hmount/hls/hcopy/humount, GPL 2.0) | ✅ |
| Q5 | sips (macOS built-in) | ✅ |
| Q6 | textutil (macOS built-in) | ✅ |
| Q7 | qlmanage (macOS built-in) | ✅ |
| Q8 | hdiutil (macOS built-in) | ✅ |
| Q9 | lsar override path from ToolChain | ✅ |
| Q10 | Remove hfsutils dependency (native Swift HFS) | 🔮 v2 |
| Q11 | ffmpeg optional dependency (video transcoding) | 🔮 v2 |

## R. TESTS

| # | Feature | Status |
|---|---------|--------|
| R1 | MacBinary parser tests | ✅ 34 tests |
| R2 | BinHex parser tests | ✅ |
| R3 | VaultEngine tests | ✅ |
| R4 | DiskImageParser tests | ❌ |
| R5 | DART decompression tests | ❌ |
| R6 | APM parser tests | ❌ |
| R7 | Resource fork parser tests | ❌ |
| R8 | MFS reader tests | ❌ |
| R9 | LZHUF decompression tests | ❌ |
| R10 | Conversion tests (PICT → PNG) | ❌ |
| R11 | Integration tests (full pipeline) | ❌ |


## S. DOCUMENTATION

| # | Feature | Status |
|---|---------|--------|
| S1 | docs/plan.md — 13-stage technical plan | ✅ (needs update) |
| S2 | docs/file-formats.md — format reference (771 lines) | ✅ |
| S3 | docs/ciderpress2-integration.md — CP2 comparison (454 lines) | ✅ |
| S4 | CLAUDE.md — development guide | ✅ (needs update) |
| S5 | docs/TODO.md — this file | ✅ |
| S6 | Update plan.md to reflect v2 decisions | ❌ |
| S7 | User manual (for retrorescue.app website) | ❌ |

---

## SUMMARY

| Category | Total | ✅ Done | ❌ Todo | 🔮 v2 |
|----------|-------|--------|--------|-------|
| A. Vault Core | 12 | 7 | 5 | 0 |
| B. Encoding Wrappers | 6 | 4 | 2 | 0 |
| C. Archive Extraction | 22 | 19 | 3 | 0 |
| D. Disk Image Formats | 16 | 8 | 7 | 1 |
| E. Filesystems | 12 | 2 | 4 | 2+4 Apple II |
| F. Partitions | 7 | 0 | 2 | 0+5 Apple II |
| G. Compression | 5 | 1 | 2 | 0+2 Apple II |
| H. Resource Fork Browser | 19 | 0 | 19 | 0 |
| I. Preview Engine | 12 | 5 | 7 | 0 |
| J. Conversion Engine | 13 | 1 | 3 | 9 |
| K. UI/UX | 19 | 10 | 9 | 0 |
| L. Thumbnails/Search | 8 | 0 | 8 | 0 |
| M. Web Integration | 4 | 0 | 4 | 0 |
| N. Emulator Bridge | 3 | 0 | 0 | 3 |
| O. Distribution | 6 | 0 | 5 | 1 |
| P. Advanced | 8 | 0 | 0 | 8 |
| Q. Toolchain | 11 | 9 | 0 | 2 |
| R. Tests | 11 | 3 | 8 | 0 |
| S. Documentation | 7 | 5 | 2 | 0 |


**TOTALS: 201 features | 73 done | 90 todo | 26 v2 | 12 Apple II (low priority)**

---

## PRIORITY ORDER (next up)

### 🔴 CRITICAL (blocks basic functionality)
1. **F1** — Apple Partition Map parser (CD-ROMs don't work without this)
2. **H1** — Resource Fork parser (blocks all of section H)
3. **G2** — LZHUF decompressor (DART "best" images fail)
4. **I6** — Hex dump fallback (files without preview show nothing)
5. **D2** — DiskCopy checksum validation (data integrity)

### 🟠 HIGH (major feature gaps vs CiderPress II)
6. **E5** — MFS filesystem reader (original 1984 Mac floppies)
7. **I7** — MacPaint preview (.PNTG files)
8. **G3** — PackBits decompression (needed for MacPaint)
9. **H5-H11** — Resource type renderers (icons, sounds, strings, versions)
10. **F2** — MacTS early partition format
11. **C20** — __MACOSX ZIP handling

### 🟡 MEDIUM (completeness + polish)
12. **A8** — Wire search to UI
13. **A9** — Export to Finder
14. **K11** — Toolbar search bar
15. **D13** — 2IMG format support
16. **B5-B6** — Verify parsers against CP2
17. **K13-K14** — Icon view, column view
18. **L1-L6** — Thumbnail generation
19. **J2-J5** — Additional converters (JPEG, icons, sounds)
20. **R4-R11** — Comprehensive test suite

### 🟢 LOW / APPLE II FOCUS
21. **D14-D15** — WOZ, MOOF (Apple II disk formats)
22. **E7-E12** — Apple II filesystems (ProDOS, DOS, CP/M, etc.)
23. **F3-F7** — Apple II partition formats
24. **G4-G5** — Apple II compression (LZW, Squeeze)
25. **C21-C22** — Binary II, AppleLink PE archives

---

*Last updated: April 2026*
*Source: Original 13-stage plan + CiderPress II v1.1.1 feature comparison*
