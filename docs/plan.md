# RetroRescue — Technical Plan

> Updated April 10, 2026. Organized in 19 sections (A–S).
> For feature status see `docs/TODO.md`. For v2 decisions see `docs/V2-PLANNING.md`.

---

## Architecture

```
retrorescue/
├── Sources/
│   ├── VaultEngine/          # Core vault: SQLite, file storage, metadata
│   ├── ContainerCracker/     # All parsers, readers, decompressors
│   ├── RetroRescue/          # SwiftUI app, UI, integration
│   └── QuickLookExtension/   # Quick Look plugin (.appex)
├── Tests/
│   ├── VaultEngineTests/     # Vault + integration tests
│   └── ContainerCrackerTests/ # Parser + format tests
├── Resources/tools/          # Bundled binaries (unar, hfsutils)
├── scripts/                  # Build + signing scripts
└── docs/                     # Documentation
```

**Build system**: xcodegen → .xcodeproj → xcodebuild
**Frameworks**: VaultEngine.framework + ContainerCracker.framework → embedded in app
**Dependencies**: swift-log (SPM), libsqlite3.tbd (system)
**Bundled tools**: unar, lsar, hmount, hls, hcopy, humount, hformat

---

## A. Vault Core (12 features)

The `.retrovault` bundle format: a directory containing `vault.sqlite`, `files/`, `thumbnails/`, `sources/`, and optional `manifest.json` + `download-history.json`.

**SQLite schema**: entries table with id, name, parent_id, is_dir, type_code, creator_code, finder_flags, label_color, data_size, rsrc_size, encoding, source_archive, original_path, created_at, modified_at, sha256. FTS5 virtual table for full-text search.

**File storage**: `files/{id}/data` (data fork) + `files/{id}/rsrc` (resource fork). Thumbnails in `thumbnails/{id}.png`.

**Key classes**: `Vault` (create/open/add/delete/query), `VaultEntry` (metadata struct), `VaultLibrary` (recent vaults tracking).

## B. Encoding Wrappers (6 features)

Native Swift parsers for all classic Mac encoding formats: MacBinary I/II/III (with CRC-16/XMODEM verification), BinHex 4.0 (6-bit decode + CRC), AppleSingle, AppleDouble (including version/FileDates/LE variants). `ContainerCracker.extract()` auto-detects and unwraps.

## C. Archive Extraction (22 features)

Two-tier approach: native Swift parsers for Binary II (.bny) and AppleLink PE (.acu), plus bundled unar/lsar for everything else (StuffIt, Compact Pro, ZIP, RAR, LHA, ARC, etc.). __MACOSX ZIP folder handling auto-pairs `._` AppleDouble companions.

**Key classes**: `UnarExtractor`, `BinaryIIParser`, `AppleLinkParser`.

## D. Disk Image Formats (16 features, 1 = v2)

DiskCopy 4.2 (header + checksum + tag data + disk description), DART (RLE + LZHUF decompression), NDIF/UDIF (via hdiutil), raw .dsk/.hfv, 2IMG, WOZ, MOOF, sector order detection. `DiskImageParser` auto-detects format via magic bytes and routes to the correct handler.

**v2**: D5 DiskCopy write support.

## E. Filesystems (12 features, 3 = v2)

Seven native Swift filesystem readers: MFS (400K floppies, 12-bit alloc map), ProDOS (seedling/sapling/tree files), DOS 3.2/3.3 (VTOC + T/S lists), CP/M (140K + 800K), Apple Pascal (UCSD, contiguous blocks), Gutenberg WP (doubly-linked sectors), RDOS (SSI games). HFS read via bundled hfsutils.

**v2**: E2 native HFS reader (port CP2 ~5,000 lines), E3 HFS write, E6 HFS+ read.

## F. Partitions (7 features)

Apple Partition Map (DDR + PM entries), Mac TS (pre-APM), Apple II multi-partition: CFFA (32MB boundaries), AmDOS/OzDOS/UniDOS, FocusDrive/MicroDrive, PPM stub, DOS hybrids.

**Key classes**: `APMParser`, `MacTSParser`, `AppleIIMultiPart`.

## G. Compression (5 features)

Native decompressors: PackBits (MacPaint RLE), LZHUF (adaptive Huffman + LZ77, DART), LZW/1 + LZW/2 (NuFX), Squeeze (RLE + semi-adaptive Huffman).

## H. Resource Fork Browser (19 features)

Binary resource fork parser (Mac resource map traversal), type registry (50+ known types), and renderers for: ICON/ICN# (32×32 1-bit), icl4/icl8 (32×32 color), ics#/ics4/ics8 (16×16), cicn, CURS/crsr, PAT/ppat, clut. Parsers for: snd, vers, STR/STR#, MENU, DITL/DLOG, FOND/FONT/NFNT, CODE, BNDL/FREF. Mac 4-bit + 8-bit system palettes.

**Key classes**: `ResourceForkParser`, `ResourceRenderers`.

## I. Preview Engine (12 features)

Unified preview cascade in `VaultState.previewFile()`. Priority order: **font preview** (FontPreviewRenderer, see below) → text (MacRoman → UTF-8) → MacPaint (PackBits → 576×720) → PICT (sips → PNG) → icon from rsrc fork → resource fork overview → font metrics → hex dump fallback. Waveform visualization for audio. Quick Look via qlmanage. Open in default app.

**FontPreviewRenderer** (Font Book–style, ~180 lines): renders real font samples using CoreText for any font format the vault contains. Detects fonts by extension (.ttf/.otf/.afm/.pfb/.dfont/.suit/.fond) AND Mac type code (sfnt/ttro/LWFN/FFIL/FONT/NFNT/FOND/tfil). For TTF/OTF/sfnt/ttro: writes data fork to a temp file with the right extension, loads via `CTFontManagerCreateFontDescriptorsFromURL`. For FFIL (Mac suitcase) and LWFN (PostScript Type 1): writes the resource fork as a `.dfont` (which is just resource fork content as a regular file) — CoreText reads it natively. For AFM (Adobe Font Metrics): parses `FontName`/`FullName`/`FamilyName`/`Weight`, tries `NSFont(name:)` lookup on the system, falls back to an info card. The sample sheet shows: font name header, uppercase/lowercase/digits at 24pt, and the pangram "The quick brown fox jumps over the lazy dog" at 12/18/24/36/48/64pt — drawn on a 600px-wide variable-height NSImage.

## J. Conversion Engine (14 features, 2 improvements = v2)

`ConversionEngine` with converters: PICT/MacPaint → PNG, icons → PNG, snd → WAV, TEXT → UTF-8, bitmap font → BDF, QuickTime → MP4 (ffmpeg), ClarisWorks/MacWrite → Markdown (text extraction), and **WriteNow + 40 legacy Mac document formats → Markdown** via the libmwaw library (see below). Batch export with metadata.json. Restore mode (AppleDouble for emulators). Charset conversion (MacRoman/Cyrillic/Greek/Latin1 → UTF-8).

**LegacyMacDocConverter** (~382 lines): wraps libmwaw 0.3.22 (LGPL-2.1+ / MPL-2.0, both compatible with our GPLv3 distribution) via shell-out to its `mwaw2text` and `mwaw2html` command-line tools. Handles WriteNow 1.0–4.0, MacWrite/MacWrite II/Pro, Microsoft Word 1–5.1 for Mac, Microsoft Works Mac 1–4, ClarisWorks/AppleWorks (WP/SS/DB/GR/PR/PT), Nisus Writer Classic, FullWrite Professional, WordPerfect Mac, RagTime, BeagleWorks, Ready Set Go!, More, Student Writing Center, MaxWrite, MindWrite, MouseWrite, eDOC, Zwrite, HanMac, LightWay Text, MariNer Write, DOCMaker. Detection cascade: Mac type code (40+ codes registered) → filename extension → magic-byte sniff for WriteNow (data fork starts with ASCII `"WriteNow"`). HTML output is converted to Markdown via a lightweight regex-based pipeline (`htmlToMarkdown` + `finishMarkdown`) that handles headings, bold, italic, underline, lists, paragraphs, common entities. Verified end-to-end with the official `libmwaw-regression` test corpus from SourceForge.

**v2**: J7+ font → TTF, J9+/J10+ ClarisWorks/MacWrite full formatting (now partially handled by libmwaw path).

## K. UI/UX (19 features)

SwiftUI app with: vault library (recent vaults), three-panel browser (archives / files / inspector), list/grid/column views, FTS5 toolbar search, filter popover (type/creator/rsrc), keyboard shortcuts (Space/Enter/Delete), lazy drag to Finder (NSItemProvider), window title with count, preferences panel, progress overlay for long operations. SF Symbols throughout. Apple HIG context menus.

**Extracted-files browser — `OutlineFileBrowserController`** (~370 lines): full AppKit `NSViewController` hosting `NSOutlineView`, wrapped in SwiftUI via `NSViewControllerRepresentable`. Same architecture as CodeEdit, PixleyReader, Xcode, and Finder itself. SwiftUI's `List(children:)` and `OutlineGroup` cannot handle thousands of items (confirmed by Apple Developer Forums and the CodeEdit issue tracker — see `docs/TREE-VIEW-RESEARCH.md` for the 50+ apps surveyed). NSOutlineView uses a pull-based delegate pattern that only queries data for visible rows, so it handles 6000+ files instantly.

Key pieces:
- `FileOutlineItem` — `NSObject` wrapper around `VaultEntry` with lazy child loading from the Vault. Children are only fetched when NSOutlineView asks for them.
- `NSOutlineViewDataSource`: `numberOfChildrenOfItem` / `child:ofItem:` / `isItemExpandable` — all delegate-based, all lazy.
- `NSOutlineViewDelegate`: custom `NSTableCellView` cells with icon (folder/archivebox/doc), name, and ByteCountFormatter size.
- Context menu: Preview, Quick Look, Extract, Export, Get Info, Delete (via `NSMenuDelegate`).
- Double-click: expand/collapse for folders, Quick Look for leaves.
- Auto-expand: when there are ≤5 root items (e.g. a ZIP containing a single ISO), the first level is expanded automatically.
- Selection sync: `outlineViewSelectionDidChange` posts the selected entry ID back to `VaultState` via a callback closure.
- `OutlineFileBrowserView` (SwiftUI wrapper): the Coordinator tracks `lastParentID` to prevent reload thrash when SwiftUI re-renders the parent view.

This was the result of an extended debugging session that proved every SwiftUI tree approach (List(children:), OutlineGroup, custom FileTreeNode classes, struct-based TreeEntry) hangs or crashes with 6000+ items. The full research is in `docs/TREE-VIEW-RESEARCH.md`.

## L. Thumbnails & Search (8 features)

`ThumbnailGenerator`: cascade PICT → MacPaint → icon rsrc → text → waveform, 128×128 PNG, stored in vault `thumbnails/{id}.png`. Auto-generate after extraction, rebuild all command. Quick Look plugin (`RetroRescueQuickLook.appex`) — HTML preview via WKWebView with vault stats. Spotlight indexer (`SpotlightIndexer`) — Core Spotlight API, indexes file names/types/creators/sizes/thumbnails, auto-indexes on vault open + after extraction.

## M. Web Integration (4 features)

`WebDownloader`: drag URL from browser → async download → Content-Disposition filename parsing → vault import → auto-extract. Macintosh Garden + Macintosh Repository HTML scrapers (title, description, download links). Download history in `download-history.json` with duplicate detection.

## N. Emulator Bridge (3 features)

`EmulatorBridge`: create HFS disk images (hformat → hmount → hcopy pipeline, 6 standard sizes + auto-size), send to emulator (SheepShaver/Basilisk II via AppleDouble shared folder, Mini vMac via disk image). `ConversionEngine.restoreForEmulator()` for AppleDouble export.

## O. Distribution (6 features, 4 = v1 todo, 1 = v2)

`scripts/sign-and-notarize.sh`: release build → codesign all binaries (tools, frameworks, extension) inside-out → notarytool submit → staple → verify. Entitlements: hardened runtime + allow-unsigned-executable-memory for bundled tools.

**v1 todo**: O2 DMG installer, O3 Sparkle auto-update, O4 Homebrew cask, O5 website.
**v2**: O6 App Store (requires sandbox compliance).

## P. Advanced (8 features, all v2)

Vault merge (SHA-256 dedup), vault diff, statistics dashboard, catalog export (static HTML), cross-vault duplicates, provenance graph, batch folder import, RetroGate URL scheme.

## Q. Toolchain (11 features, 2 = v2)

`ToolChain` singleton: priority bundled > system > homebrew. Bundled: unar (2.2MB), lsar (2.3MB), hfsutils (hmount/hls/hcopy/humount/hformat). System: sips, qlmanage, hdiutil.

**v2**: Q10 native Swift HFS (replace hfsutils), Q11 ffmpeg optional download (~80MB to Application Support).

## R. Tests (152 tests in 17 suites)

Swift Testing framework. 152 tests covering: MacBinary (18), BinHex (7), AppleDouble (9), VaultEngine (7), DiskImage (7), DART (5), APM (6), ResourceFork (9), MFS (4), Compression (8), Conversion (4), FilesystemReader (17), ArchiveParser (10), Integration (6), EdgeCases (32). 5/5 stability runs, ~170-290ms average.

## S. Documentation (7 features, 1 = v1 todo)

README, ARCHITECTURE, FORMATS, RELEASE-CHECKLIST, V2-PLANNING, plan.md (this file), and TREE-VIEW-RESEARCH (50+ apps surveyed for the file browser implementation choice) complete. **v1 todo**: S7 user manual for retrorescue.app website.

---

## Score

| Section | Total | Done | v1 todo | v2 |
|---------|-------|------|---------|-----|
| A. Vault Core | 12 | 12 | 0 | 0 |
| B. Encoding Wrappers | 6 | 6 | 0 | 0 |
| C. Archive Extraction | 22 | 22 | 0 | 0 |
| D. Disk Image Formats | 16 | 15 | 0 | 1 |
| E. Filesystems | 12 | 9 | 0 | 3 |
| F. Partitions | 7 | 7 | 0 | 0 |
| G. Compression | 5 | 5 | 0 | 0 |
| H. Resource Fork Browser | 19 | 19 | 0 | 0 |
| I. Preview Engine | 12 | 12 | 0 | 0 |
| J. Conversion Engine | 14 | 11 | 0 | 2 |
| K. UI/UX | 19 | 19 | 0 | 0 |
| L. Thumbnails & Search | 8 | 8 | 0 | 0 |
| M. Web Integration | 4 | 4 | 0 | 0 |
| N. Emulator Bridge | 3 | 3 | 0 | 0 |
| O. Distribution | 6 | 1 | 4 | 1 |
| P. Advanced | 8 | 0 | 0 | 8 |
| Q. Toolchain | 11 | 9 | 0 | 2 |
| R. Tests | 11 | 11 | 0 | 0 |
| S. Documentation | 7 | 6 | 1 | 0 |
| **TOTAL** | **202** | **179** | **6** | **17** |

**179 of 202 features complete (89%). 6 items for v1 release. 17 items for v2.**
