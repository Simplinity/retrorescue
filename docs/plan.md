# RetroRescue — Technical Plan

> Every stage delivers a working, usable app. Each builds on the previous.

---

## Stage 1: The Vault Core

### What it delivers
A macOS app where you can create a `.retrovault`, manually add files (drag & drop from Finder), and browse them. The vault preserves whatever metadata macOS still provides (resource forks via extended attributes, if present). Not yet useful for *classic* Mac files specifically — but it proves the vault format, the SQLite schema, the file browser, and the bundle structure.

### Technical work

**1.1 — SPM project scaffold**
- `Package.swift` with targets: `RetroRescue` (executable, SwiftUI app), `VaultEngine` (library)
- Xcode-compatible: `RetroRescue.xcconfig` for signing, bundle ID (`com.simplinity.retrorescue`)
- `Info.plist`: register `.retrovault` as document type (`com.simplinity.retrorescue.vault`), UTType export
- Entitlements: `com.apple.security.files.user-selected.read-write`

**1.2 — VaultEngine library**

Core data model:

```swift
// A single file stored in the vault
struct VaultEntry: Identifiable, Codable {
    let id: String                    // "0001", "0002", etc. (zero-padded)
    var originalName: String          // "ReadMe"
    var originalPath: String          // "Macintosh HD:Applications:ReadMe"
    var typeCode: String?             // "TEXT" (4 chars, space-padded)
    var creatorCode: String?          // "ttxt"
    var finderFlags: UInt16           // Finder flags bitmask
    var labelColor: Int               // 0-7
    var created: Date?                // Original creation date
    var modified: Date?               // Original modification date
    var dataForkSize: Int64           // bytes
    var rsrcForkSize: Int64           // bytes
    var dataChecksum: String?         // "sha256:abc123..."
    var rsrcChecksum: String?         // "sha256:def456..."
    var encoding: String              // "MacRoman", "UTF-8", etc.
    var sourceArchive: String?        // "MyStuff.sit" — which container this came from
    var parentID: String?             // parent folder's vault ID, nil = root
    var isDirectory: Bool             // folder or file
}
```

Vault operations:
- `Vault.create(at: URL) throws -> Vault` — create new `.retrovault` bundle
- `Vault.open(at: URL) throws -> Vault` — open existing vault
- `vault.addFile(data: Data, rsrc: Data?, metadata: VaultEntry) throws`
- `vault.addDirectory(name: String, parentID: String?) throws -> String`
- `vault.entries(parentID: String?) -> [VaultEntry]` — list children
- `vault.search(query: String) -> [VaultEntry]` — full-text search on names
- `vault.dataFork(for: String) throws -> Data` — read data fork by ID
- `vault.rsrcFork(for: String) throws -> Data` — read resource fork by ID
- `vault.delete(id: String) throws`
- `vault.export(id: String, to: URL, restoreResourceFork: Bool) throws`

SQLite schema (`vault.sqlite`):

```sql
CREATE TABLE entries (
    id          TEXT PRIMARY KEY,     -- "0001"
    parent_id   TEXT,                 -- NULL = root
    is_dir      INTEGER NOT NULL DEFAULT 0,
    name        TEXT NOT NULL,        -- original filename
    path        TEXT NOT NULL,        -- full original path (colon-separated Mac path)
    type_code   TEXT,                 -- "TEXT", "PICT", etc.
    creator_code TEXT,                -- "ttxt", "8BIM", etc.
    finder_flags INTEGER DEFAULT 0,
    label_color INTEGER DEFAULT 0,
    created_at  TEXT,                 -- ISO 8601
    modified_at TEXT,                 -- ISO 8601
    data_size   INTEGER DEFAULT 0,
    rsrc_size   INTEGER DEFAULT 0,
    data_sha256 TEXT,
    rsrc_sha256 TEXT,
    encoding    TEXT DEFAULT 'MacRoman',
    source      TEXT,                 -- source archive/image filename
    added_at    TEXT NOT NULL,        -- when added to vault
    FOREIGN KEY (parent_id) REFERENCES entries(id)
);

CREATE INDEX idx_parent ON entries(parent_id);
CREATE INDEX idx_name ON entries(name);
CREATE INDEX idx_type ON entries(type_code);
CREATE VIRTUAL TABLE entries_fts USING fts5(name, path, source);
```

Bundle structure on disk:

```
MyArchive.retrovault/           (NSFileWrapper bundle)
├── vault.sqlite
├── manifest.json               {"version": 1, "created": "...", "app_version": "1.0.0"}
├── files/
│   ├── 0001/
│   │   ├── data                (raw data fork bytes)
│   │   ├── rsrc                (raw resource fork bytes, may be 0 bytes)
│   │   └── meta.json           (duplicate of DB row, for portability)
│   └── 0002/
│       └── ...
├── thumbnails/                 (generated later, in Stage 4)
└── sources/                    (original archives, optional, added in Stage 2)
```

The `meta.json` per file is a safety net: even if the SQLite DB gets corrupted, every file's metadata is self-contained. On vault open, if the DB is missing, it can be rebuilt from the `meta.json` files.

SQLite dependency: use `swift-sqlite` (or raw C `sqlite3` via system library — it ships with macOS). No external packages needed.

**1.3 — SwiftUI app shell**

- Document-based app (`DocumentGroup`) with `.retrovault` file type
- Main window: sidebar (vault file tree) + content (detail/preview placeholder)
- Toolbar: "New Vault", "Add Files" button
- Drag & drop on sidebar: accepts files from Finder, stores them in vault
- For now: captures data fork, resource fork (via `URL.resourceValues` extended attributes if available), file dates
- No classic Mac awareness yet — just modern macOS files going into the vault
- Status bar: file count, total vault size

### What you can demo after Stage 1
"Look, I drag files into this vault, they're stored safely, I can browse them, and the vault is a single file I can put on iCloud." The vault format works. The app opens and saves `.retrovault` documents.

---

## Stage 2: MacBinary & BinHex — Understanding Classic Mac Files

### What it delivers
The vault can now import files that are wrapped in MacBinary or BinHex encoding — the most common way classic Mac files survive on the modern internet. When you drag a `.bin` or `.hqx` file onto RetroRescue, it unwraps it, extracts the data fork, resource fork, type/creator codes, and stores everything properly in the vault. The file browser now shows type/creator codes and resource fork sizes.

### Technical work

**2.1 — MacBinary parser (built-in, pure Swift)**

MacBinary is a simple 128-byte header + data fork + resource fork:

```
Offset  Size  Field
0       1     Always 0x00
1       1     Filename length (1-63)
2       63    Filename (Pascal string)
65      4     File type (e.g. "TEXT")
69      4     File creator (e.g. "ttxt")
73      1     Finder flags (high byte)
74      1     Always 0x00
75      2     Vertical position
77      2     Horizontal position
79      2     Window/folder ID
81      1     Protected flag
82      1     Always 0x00
83      4     Data fork length
87      4     Resource fork length
91      4     Creation date (Mac epoch: 1904-01-01)
95      4     Modification date (Mac epoch)
...
122     1     MacBinary version (0x81=II, 0x82=III)
123     1     Minimum version to read
124     2     CRC-16 of header (MacBinary II+)
126     2     Padding (0x00)
--- 128 bytes header ---
128     N     Data fork (padded to 128-byte boundary)
128+N'  M     Resource fork (padded to 128-byte boundary)
```

Detection: byte 0 == 0x00, byte 74 == 0x00, byte 82 == 0x00, data+rsrc lengths are plausible vs file size. CRC check for MacBinary II/III.

Implementation: `MacBinaryParser.parse(data: Data) throws -> MacBinaryFile` where `MacBinaryFile` contains `.dataFork`, `.rsrcFork`, `.fileName`, `.typeCode`, `.creatorCode`, `.created`, `.modified`, `.finderFlags`.

**2.2 — BinHex 4.0 parser (built-in, pure Swift)**

BinHex is a text encoding (like Base64 but for classic Mac). Structure:
1. Lines start with `(This file must be converted with BinHex 4.0)` marker
2. Data between `:` delimiters is encoded with a 6-bit encoding table
3. Decoded stream contains: filename (Pascal string), type, creator, Finder flags, data fork length, resource fork length, data fork CRC, data fork bytes, resource fork CRC, resource fork bytes
4. Run-length encoding: `0x90` is escape byte for RLE

Implementation: `BinHexParser.parse(data: Data) throws -> BinHexFile` — same output shape as MacBinary.

**2.3 — AppleSingle/AppleDouble parser (built-in)**

AppleSingle (magic: `0x00051600`) and AppleDouble (magic: `0x00051607`) are simple: a header with entry count, then entry descriptors (type ID + offset + length). Entry types: data fork (1), resource fork (2), real name (3), finder info (9), dates (8).

**2.4 — Format detection & ContainerCracker module**

```swift
protocol ContainerFormat {
    static func canHandle(data: Data, fileExtension: String) -> Bool
    func extract(from data: Data) throws -> [ExtractedFile]
}

struct ExtractedFile {
    var name: String
    var dataFork: Data
    var rsrcFork: Data
    var typeCode: String?
    var creatorCode: String?
    var finderFlags: UInt16
    var created: Date?
    var modified: Date?
    var isDirectory: Bool
    var children: [ExtractedFile]?    // for containers with folder structure
}
```

Detection order (in `ContainerCracker.identify()`):
1. Check magic bytes: MacBinary (0x00 at 0, 0x00 at 74, 0x00 at 82), AppleSingle (0x00051600), AppleDouble (0x00051607)
2. Check text prefix: BinHex (`(This file must be converted`)
3. Fall back to extension: `.bin` → try MacBinary, `.hqx` → try BinHex

**2.5 — UI updates**

- File browser now shows columns: Name, Type, Creator, Data Size, Rsrc Size, Date
- Type/creator codes displayed in monospace font (like "TEXT/ttxt")
- Files with resource forks get a small indicator icon
- Drag & drop now auto-detects MacBinary/BinHex and unwraps before storing
- "Import" panel: shows what was detected ("MacBinary II file: ReadMe, type TEXT, 4.5 KB data, 0 B rsrc")

### What you can demo after Stage 2
"I downloaded a .bin file from Macintosh Garden. I dropped it on RetroRescue, it detected MacBinary II, unwrapped it, and now I can see the file with its type/creator codes and resource fork preserved in my vault." This is already more than any modern macOS tool does out of the box.

---

## Stage 3: Archive Extraction — StuffIt, Compact Pro, DiskDoubler

### What it delivers
Drop a `.sit`, `.cpt`, or `.dd` archive on RetroRescue and it extracts everything, preserving the full classic Mac metadata, storing all files in the vault. Handles nested archives (archive inside an archive).

### Technical work

**3.1 — unar integration**

Shell out to `unar` (The Unarchiver CLI). Strategy:

```swift
func extractWithUnar(archiveURL: URL, to tempDir: URL) throws -> [URL] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/unar")
    // -k visible: extract resource forks as AppleDouble ._ files
    // -d: extract to specified directory
    // -f: force overwrite
    process.arguments = ["-k", "visible", "-d", tempDir.path, "-f", archiveURL.path]
    // ... run, collect output, parse file list from stdout
}
```

After unar extraction, the temp directory contains:
- Regular files (data fork)
- `._filename` files (AppleDouble resource fork + Finder info)

Post-processing: for each extracted file, check for a matching `._` file. If found, parse it as AppleDouble (Stage 2's parser) to get resource fork, type/creator, dates. Then store the combined result in the vault.

**3.2 — unar availability check**

On first launch (or when unar is needed), check if `/opt/homebrew/bin/unar` or `/usr/local/bin/unar` exists. If not, show a friendly dialog:

> "RetroRescue needs The Unarchiver to open StuffIt and Compact Pro archives.
> Install it with: `brew install unar`
> [Copy Command] [Open Terminal]"

Store the unar path in UserDefaults once found. Also allow manual path selection in Settings.

**3.3 — Archive detection**

Extend `ContainerCracker.identify()`:
- `.sit` → StuffIt (magic: `SIT!` at offset 0, or `StuffIt` at offset 0)
- `.sea` → StuffIt self-extracting (various magic bytes)
- `.cpt` → Compact Pro (magic: `0x01` at offset 0 with specific structure)
- `.dd` → DiskDoubler
- `.hqx` → BinHex (handled in Stage 2, but unar also handles it)
- `.arc`, `.zoo`, `.lzh`, `.pit` → various old formats, all handled by unar

For any format unar supports: delegate to unar. For MacBinary/BinHex/AppleDouble: use built-in parser (faster, no subprocess).

**3.4 — Nested archive handling**

After extraction, scan the results for files that are themselves archives (by extension and magic bytes). Offer to recursively extract:

- Automatic: if an archive contains exactly one .sit or .bin file, auto-extract it
- Manual: if multiple nested archives, show them in the import panel with checkboxes

**3.5 — Source preservation**

When importing an archive, optionally copy the original archive file into `sources/` inside the vault. This provides provenance: you can always see which `.sit` file a particular file came from.

**3.6 — UI updates**

- Import progress: show a progress sheet during extraction ("Extracting MyStuff.sit... 47 files found")
- Source column in file browser: shows which archive a file came from
- "Re-extract from source" option: if the source is preserved, re-extract with different settings

### What you can demo after Stage 3
"Here's a StuffIt archive from 1997. I dropped it on RetroRescue, it extracted 47 files with their resource forks and type/creator codes intact, and stored them all in my vault. The original .sit file is preserved as provenance."

---

## Stage 4: HFS Disk Images

### What it delivers
Open `.dsk`, `.img` (DiskCopy 4.2), `.toast`, and `.iso` disk images containing HFS or HFS+ volumes. Browse the full directory tree with original folder structure, extract files with complete metadata into the vault.

### Technical work

**4.1 — Disk image format detection**

| Format | Detection | Handler |
|--------|-----------|---------|
| Raw HFS | Bytes 1024-1025 == `0x4244` ("BD", HFS signature) | libhfs |
| DiskCopy 4.2 | 84-byte header, name at offset 0 (Pascal string), tag/data sizes, checksum | strip header → raw HFS |
| DiskCopy 6.x | Different header structure | strip header → raw HFS |
| Toast | Roxio Toast format | hdiutil (macOS built-in) |
| ISO 9660 | Magic `CD001` at offset 32769 | hdiutil |
| Apple Partition Map | Magic `PM` at block 1 | parse APM, find HFS partition |

**4.2 — DiskCopy 4.2 parser (built-in)**

Simple header format:
```
Offset  Size  Field
0       1     Filename length
1       63    Filename (Pascal string)
64      4     Data size
68      4     Tag size
72      4     Data checksum
76      4     Tag checksum
80      1     Disk format (0=400K, 1=800K, 2=720K, 3=1440K)
81      1     Format byte (0x24 = valid)
82      2     Private
```

Strip the 84-byte header → raw disk data → feed to HFS parser.

**4.3 — HFS volume reading**

Two approaches, pick based on complexity:

**Option A: Shell out to hfsutils (simpler, good enough for v1)**
```bash
hmount image.dsk          # mount the HFS volume
hls -alR                  # recursive listing with metadata
hcopy -m ':path:to:file' /tmp/output.bin   # extract as MacBinary
humount                   # unmount
```
Then parse the MacBinary output with Stage 2's parser.

**Option B: Python bridge via machfs (more complete)**
```bash
python3 -c "
from machfs import Volume
import json, sys, base64

with open(sys.argv[1], 'rb') as f:
    v = Volume()
    v.read(f.read())

def walk(obj, path=''):
    for name, item in obj.items():
        full = path + ':' + name if path else name
        if hasattr(item, 'items'):  # Folder
            print(json.dumps({'type':'dir','path':full}))
            walk(item, full)
        else:  # File
            print(json.dumps({
                'type':'file','path':full,
                'file_type': item.type.decode('mac_roman','replace'),
                'creator': item.creator.decode('mac_roman','replace'),
                'data_len': len(item.data),
                'rsrc_len': len(item.rsrc),
                'data_b64': base64.b64encode(item.data).decode(),
                'rsrc_b64': base64.b64encode(item.rsrc).decode(),
            }))
walk(v)
" image.dsk
```

Recommendation: start with Option A (hfsutils) because it's a single `brew install`. Upgrade to Option B later if hfsutils doesn't handle edge cases.

**4.4 — Apple Partition Map parsing (built-in)**

Some disk images have multiple partitions (especially CD-ROMs). The APM starts at block 1 (512 bytes in):
- Magic `0x504D` ("PM") per partition entry
- Entry contains: partition name, type (`Apple_HFS`, `Apple_Driver`, etc.), offset, size
- Scan for the `Apple_HFS` partition, extract that byte range, feed to HFS parser

**4.5 — UI updates**

- When a disk image is dropped, show a "Disk Image Contents" view first (before importing to vault)
- Tree view with folders, file counts per folder
- Selective import: checkboxes to pick which files/folders to vault
- "Import All" button for full disk import
- Disk image metadata in sidebar: volume name, size, format, file count

### What you can demo after Stage 4
"Here's a System 7.5 disk image. RetroRescue opens it, shows me the full directory tree, and I can selectively import files into my vault — all with resource forks and metadata preserved."

---

## Stage 5: Resource Fork Browser

### What it delivers
Click on any file in the vault that has a resource fork, and see its individual resources listed: type, ID, name, size. This is the "ResEdit Reborn" functionality. Not yet converting to modern formats — just browsing and understanding what's inside.

### Technical work

**5.1 — Resource fork parser (built-in, pure Swift)**

The resource fork format is well-documented (Inside Macintosh, Vol I, Ch 5):

```
Resource fork layout:
├── Resource data area     (starts at dataOffset from header)
│   └── Each resource: [4-byte length][raw data bytes]
├── Resource map           (starts at mapOffset from header)
│   ├── Header copy (16 bytes, reserved)
│   ├── Next resource map handle (4 bytes, reserved)
│   ├── File reference number (2 bytes, reserved)
│   ├── Resource fork attributes (2 bytes)
│   ├── Offset to type list (2 bytes, from start of map)
│   ├── Offset to name list (2 bytes, from start of map)
│   ├── Type list:
│   │   ├── Count - 1 (2 bytes)
│   │   └── Per type: [4-char type][count-1 (2b)][offset to ref list (2b)]
│   └── Reference list per type:
│       └── Per resource: [ID (2b)][name offset (2b)][attributes (1b)]
│                         [data offset (3b, from start of data area)]
└── Header (first 16 bytes of fork):
    ├── Data offset (4 bytes)
    ├── Map offset (4 bytes)
    ├── Data length (4 bytes)
    └── Map length (4 bytes)
```

Implementation:

```swift
struct ResourceFork {
    var resources: [ResourceType: [Resource]]
}

struct ResourceType: Hashable {
    let code: String   // "ICON", "snd ", "PICT", etc.
}

struct Resource: Identifiable {
    let type: ResourceType
    let id: Int16
    let name: String?
    let attributes: UInt8
    let data: Data
}

// Parser
struct ResourceForkParser {
    static func parse(data: Data) throws -> ResourceFork
}
```

**5.2 — Known resource type registry**

A lookup table mapping type codes to human-readable descriptions:

```swift
let knownResourceTypes: [String: String] = [
    "ICON": "Icon (32×32, 1-bit)",
    "ICN#": "Icon with mask (32×32)",
    "icl4": "Large icon (32×32, 4-bit)",
    "icl8": "Large icon (32×32, 8-bit)",
    "ics#": "Small icon with mask (16×16)",
    "ics4": "Small icon (16×16, 4-bit)",
    "ics8": "Small icon (16×16, 8-bit)",
    "PICT": "QuickDraw picture",
    "snd ": "Sound resource",
    "STR ": "String",
    "STR#": "String list",
    "TEXT": "Text",
    "styl": "Text style",
    "MENU": "Menu definition",
    "DITL": "Dialog item list",
    "DLOG": "Dialog template",
    "WIND": "Window template",
    "FONT": "Bitmap font",
    "NFNT": "New bitmap font",
    "FOND": "Font family",
    "CODE": "68K code segment",
    "DRVR": "Desk accessory driver",
    "INIT": "System extension code",
    "cdev": "Control panel code",
    "vers": "Version info",
    "BNDL": "Bundle (file type associations)",
    "FREF": "File reference",
    "cicn": "Color icon",
    "ppat": "Pixel pattern",
    "crsr": "Color cursor",
    "CURS": "Cursor (1-bit)",
    "clut": "Color lookup table",
    "pltt": "Palette",
    // ... extensible
]
```

**5.3 — UI: Resource browser panel**

When you select a file in the vault that has a resource fork:
- Detail panel shows a table: Type | ID | Name | Size | Description
- Grouped by type (collapsible sections)
- Click a resource → hex dump view (basic, using monospace font)
- Status: "23 resources in 8 types (ICON, ICN#, snd , STR#, MENU, vers, BNDL, FREF)"

### What you can demo after Stage 5
"I clicked on SimpleText in my vault, and I can see all 23 of its resources: icons, sounds, menus, version info. It's like ResEdit on my modern Mac."

---

## Stage 6: Preview Engine — See What's Inside

### What it delivers
Click a resource or a file in the vault, and see a visual preview. PICT files render as images. Icons show as pixel art grids. Sounds play inline. Text files render in MacRoman with correct encoding. This is where the app goes from "useful" to "delightful."

### Technical work

**6.1 — PICT preview**

Two approaches:
- **macOS `sips`**: `sips -s format png input.pict --out output.png` — fast, reliable for most PICTs, ships with macOS
- **Built-in PICT1 decoder**: PICT version 1 is trivial (1-bit QuickDraw opcodes). Useful for early Mac files where sips might not work.

Implementation: write the PICT data to a temp file, call `sips`, read back the PNG. Display in an `Image` view. Fall back to hex dump if sips fails.

**6.2 — Icon preview (built-in)**

Icon resources are simple bitmaps:
- `ICON`: 128 bytes = 32×32 pixels, 1-bit (+ 128 bytes mask for `ICN#`)
- `ics#`: 64 bytes = 16×16 pixels, 1-bit (+ mask)
- `icl4`: 512 bytes = 32×32 pixels, 4-bit indexed color
- `icl8`: 1024 bytes = 32×32 pixels, 8-bit indexed color
- `cicn`: variable, has its own header with color table

Render to `NSImage`/`CGImage`: create a bitmap context, set pixels, render. Show at 1x, 2x, 4x, 8x zoom for pixel art appreciation.

**6.3 — Sound preview (built-in)**

`snd ` resources have a documented header:
- Format 1: sound data header + commands + buffer header + sample data
- Most common: 8-bit unsigned mono/stereo, various sample rates (11025, 22050, 44100)

Parse the `snd ` header to extract: sample rate, sample size, channel count, compression type, and raw sample data. Convert to a WAV/AIFF in memory, play with `AVAudioPlayer`.

Display: a waveform visualization + play/pause button + duration.

**6.4 — Text preview**

For files with type `TEXT` (or `ttro` for read-only text):
- Read the data fork as MacRoman bytes
- Convert to UTF-8: `String(data: dataFork, encoding: .macOSRoman)`
- Convert line endings: `\r` → `\n`
- If a matching `styl` resource exists (same ID), apply basic styling (font, size, bold/italic)
- Display in a scrollable `TextEditor` view

**6.5 — vers (version info) preview**

`vers` resources are common and simple:
- 1 byte major version, 1 byte minor (BCD), 1 byte dev stage, 1 byte pre-release
- Pascal string: short version (e.g. "2.0.1")
- Pascal string: long version (e.g. "2.0.1, © 1997 Apple Computer")

Display as formatted text.

**6.6 — Hex dump view (fallback)**

For any resource or file without a specific previewer:
- Classic hex dump: offset | hex bytes (16 per row) | ASCII representation
- Monospace font, selectable, copyable
- Color-code printable vs non-printable bytes

**6.7 — Preview routing**

```swift
protocol PreviewProvider {
    static func canPreview(typeCode: String?, resourceType: String?) -> Bool
    func preview(data: Data, metadata: VaultEntry) -> AnyView
}

// Registry
let previewProviders: [PreviewProvider.Type] = [
    PICTPreview.self,       // type "PICT" or resource type "PICT"
    IconPreview.self,       // resource types ICON, ICN#, icl4, icl8, ics#, ics4, ics8, cicn
    SoundPreview.self,      // resource type "snd "
    TextPreview.self,       // type "TEXT" or "ttro"
    VersionPreview.self,    // resource type "vers"
    HexDumpPreview.self,    // fallback for everything else
]
```

### What you can demo after Stage 6
"I opened a System 7 disk image, imported it into my vault, clicked on the Finder, and I can see its icons rendered pixel-perfect, hear its alert sounds, read its version info, and browse every resource it contains — all on my Apple Silicon Mac."

---

## Stage 7: Conversion Engine — Export to Modern Formats

### What it delivers
Select files in the vault and export them as modern formats. PICT → PNG. Icons → PNG/ICO. Sounds → WAV. Text → UTF-8. Batch export entire folders or whole vaults. This is the "Rescue" in RetroRescue.

### Technical work

**7.1 — Converter protocol**

```swift
protocol FormatConverter {
    /// What this converter handles
    static var supportedTypes: [String] { get }          // type codes or resource types
    static var outputFormats: [ExportFormat] { get }

    /// Convert a single file/resource
    func convert(data: Data, rsrc: Data?, metadata: VaultEntry,
                 format: ExportFormat) throws -> ConversionResult
}

enum ExportFormat: String, CaseIterable {
    case png, jpeg, svg, ico
    case wav, aiff, mp3
    case utf8Text, markdown, rtf, html, docx
    case csv, xlsx
    case ttf, otf
    case mp4
    case json                // structured export of metadata
}

struct ConversionResult {
    var outputData: Data
    var suggestedFilename: String      // "ReadMe.txt", "icon_128.png"
    var format: ExportFormat
    var warnings: [String]             // e.g. "Some styling was lost"
}
```

**7.2 — Individual converters**

| Converter | Input | Output | Method |
|-----------|-------|--------|--------|
| PICTConverter | PICT data | PNG, JPEG | `sips` CLI |
| IconConverter | ICON, ICN#, icl4, icl8, ics#, cicn | PNG, ICO | Built-in bitmap renderer (from Stage 6) |
| SoundConverter | snd resources | WAV, AIFF | Built-in: write WAV header + PCM data |
| TextConverter | TEXT data fork | UTF-8 .txt | MacRoman → UTF-8 + line ending conversion |
| MacPaintConverter | MacPaint files (.PNTG) | PNG | Built-in: 576×720, 1-bit, PackBits decompression |
| CursorConverter | CURS, crsr resources | PNG | Built-in: 16×16 1-bit or color bitmap |
| PatternConverter | PAT, PAT#, ppat resources | PNG | Built-in: 8×8 or larger tiled pattern |
| VersionConverter | vers resources | JSON | Built-in: parse to structured JSON |
| StringConverter | STR, STR# resources | JSON/TXT | MacRoman → UTF-8, JSON array for STR# |

**7.3 — Batch export**

- Select files/folders in vault → "Export" → choose output directory + format preferences
- Settings per type: "Convert PICTs to [PNG/JPEG/both]", "Convert sounds to [WAV/AIFF]"
- Folder structure preservation: recreate the original Mac folder hierarchy in the output
- Export summary: "Exported 47 files: 12 PICTs→PNG, 5 sounds→WAV, 30 text→UTF-8"
- "Export All" button for entire vault
- Export log saved as `export_log.json` in the output directory

**7.4 — Restore mode (reverse export)**

Export from vault back to files with real macOS resource forks:
- Write data fork as file content
- Write resource fork to extended attribute `com.apple.ResourceFork`
- Set type/creator via `setxattr` (using `com.apple.FinderInfo` extended attribute — 32 bytes: type at offset 0, creator at offset 4)
- Restore creation/modification dates

This is for use with emulators (SheepShaver volumes) or real vintage Macs.

**7.5 — UI updates**

- Right-click file → "Export as..." with format picker
- Right-click folder → "Export folder..." with batch settings
- Menu bar → "Export" → "Export Vault..." for full vault export
- Export preferences in Settings: default formats, output structure, naming conventions
- Progress sheet with per-file progress and running totals

### What you can demo after Stage 7
"I imported a System 7 disk image with 200 files. One click on 'Export Vault', and I got a modern folder with PNG icons, WAV sounds, readable text files, and a JSON metadata catalog — all in 3 seconds."

---

## Stage 8: Thumbnails, Search & Polish

### What it delivers
The vault browser becomes fast and beautiful: thumbnails for images and icons, full-text search across file names and metadata, Quick Look support for `.retrovault` files in Finder.

### Technical work

**8.1 — Thumbnail generation**

When files are added to the vault, generate thumbnails asynchronously:
- PICT → 128×128 PNG thumbnail (via sips)
- Icons → render the largest available icon variant
- TEXT → first 4 lines rendered as image (using Chicago or Geneva font if available)
- Sounds → waveform mini-visualization
- Unknown → generic icon based on type/creator code (use the known types database)

Store in `thumbnails/{id}.png`. Index the thumbnail path in SQLite.

Generate on import (background queue), regenerate on demand for existing vaults ("Rebuild Thumbnails").

**8.2 — Search**

Already scaffolded in Stage 1 (FTS5 virtual table). Now wire it up:
- Search bar in toolbar: instant search across file names, paths, source archive names
- Filter by: type code, creator code, has resource fork, date range, file size range
- Results shown in flat list with breadcrumb paths
- Keyboard shortcut: Cmd+F focuses search

**8.3 — Quick Look plugin**

A QuickLook Thumbnail Extension and Preview Extension:
- Thumbnail: show the vault icon (custom app icon with file count badge)
- Preview: render a summary — volume name, file count, total size, top file types, sample thumbnails
- Registered for UTType `com.simplinity.retrorescue.vault`

**8.4 — Spotlight importer (optional)**

A Spotlight Importer plugin that indexes vault contents:
- Index file names, type/creator codes, source archive names
- Users can find vault contents via Spotlight: "kind:retrovault SimpleText"

**8.5 — UI polish**

- File browser: icon view (grid of thumbnails), list view (table), column view (Finder-style)
- Keyboard navigation: arrow keys, Enter to open, Space for Quick Look preview
- Drag from vault to Finder: exports the file (with resource fork restored if possible)
- Context menu: Open, Preview, Export, Copy to Clipboard, Delete, Show in Resource Browser
- Window title: vault name + file count
- Preferences: vault default location, auto-thumbnail on import, theme (light/dark/auto)

### What you can demo after Stage 8
"I have a vault with 500 files. I can search for 'ClarisWorks', see thumbnail previews, browse in icon view, and even find my vaults in Spotlight."

---

## Stage 9: Advanced Converters — Fonts, Documents, Video

### What it delivers
The hardest conversions: bitmap fonts to TrueType, ClarisWorks documents to DOCX, QuickTime movies to modern codecs. Each is independent and can be tackled in any order.

### Technical work

**9.1 — Bitmap font converter (FONT/NFNT/FOND → TTF)**

Classic Mac bitmap fonts are stored as pixel grids at specific sizes. Conversion approach:
1. Parse FOND resource for font family info (encoding, association table linking sizes to NFNT IDs)
2. Parse NFNT/FONT resources: header (first/last char, max width, ascent, descent, leading) + bitmap data + offset/width table + optional location table
3. For each glyph: extract the bitmap pixels from the strike (bitfield row by row)
4. Generate TrueType outlines: trace the pixel edges to create vector paths (simple algorithm: walk the pixel boundary, emit line segments)
5. Write a minimal TrueType/OpenType file using a font generation library or manually construct the required tables (head, hhea, maxp, OS/2, name, cmap, glyf, loca, post)

Complexity: medium-high. Consider using `fonttools` (Python) as a backend to generate the actual .ttf, since constructing TrueType tables by hand is tedious.

Alternative: export as BDF (Bitmap Distribution Format) which is much simpler and can be converted to TTF with existing tools.

**9.2 — ClarisWorks / AppleWorks document converter**

No public documentation exists. Known reverse-engineering:
- File starts with type `BOBO` (creator code for ClarisWorks)
- Header contains document type (word processing, spreadsheet, draw, database, painting, presentation)
- Text is stored in MacRoman encoding in data runs
- Formatting is stored in a separate style table
- Embedded objects (images, frames) have their own sub-structures

Pragmatic approach for v1:
1. Extract raw text: scan the data fork for MacRoman text runs (heuristic: look for long sequences of printable characters)
2. Output as plain text / Markdown
3. Leave structured conversion (styled text, embedded images) for a future version
4. Alternative: extract via LLM — render the document in an emulator, screenshot it, OCR it. Brute force but works.

**9.3 — MacWrite document converter**

MacWrite format is slightly better documented (it was simpler):
- Header with version, paragraph count
- Paragraphs stored sequentially with style runs
- Text in MacRoman

Approach: parse known MacWrite II format structure, extract text and basic formatting, output as RTF or Markdown.

**9.4 — QuickTime transcoding (via ffmpeg)**

```swift
func transcodeQuickTime(input: URL, output: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    process.arguments = [
        "-i", input.path,
        "-c:v", "libx264",
        "-crf", "18",            // high quality
        "-c:a", "aac",
        "-b:a", "192k",
        "-movflags", "+faststart",
        output.path
    ]
    // ... run
}
```

Handles: Cinepak, Sorenson 1/3, Intel Indeo, Apple Animation, Apple Graphics, Motion JPEG. ffmpeg supports all of these.

For QTVR (QuickTime VR panoramas): extract the panoramic image strip and generate an interactive HTML/JS viewer using pannellum or similar.

### What you can demo after Stage 9
"I converted a folder of classic Mac bitmap fonts into real TrueType files — I can install Chicago 12 on my modern Mac. And those old QuickTime movies from 1998? They're now H.264 MP4s."

---

## Stage 10: Drag & Drop from Web — Macintosh Garden Integration

### What it delivers
Drag a URL from a browser onto RetroRescue, and it downloads the file, identifies the format, extracts it, and stores it in the current vault. Works with Macintosh Garden, Macintosh Repository, Internet Archive, and any direct download link. This turns RetroRescue from a local tool into a collection-building workflow.

### Technical work

**10.1 — URL drop target**

Extend the drop zone to accept `NSPasteboard.PasteboardType.URL`:
- Detect URL drop
- Download to temp directory (async, with progress)
- Feed the downloaded file into ContainerCracker (same pipeline as local files)
- Store result in current vault

**10.2 — Content-Disposition / redirect handling**

Many archive sites serve downloads through redirects and with `Content-Disposition` headers:
- Follow HTTP redirects (URLSession handles this)
- Parse `Content-Disposition: attachment; filename="MyApp.sit"` for the real filename
- Use the filename for format detection (extension matters)

**10.3 — Macintosh Garden scraper (optional)**

If the dropped URL is a Macintosh Garden page (not a direct download):
- Fetch the page HTML
- Find the download link(s) on the page
- Present them in a picker: "Found 3 downloads: MyApp.sit (1.2 MB), MyApp.img (800 KB), ReadMe.txt (2 KB)"
- Download selected files

Same approach for Macintosh Repository and Internet Archive detail pages.

**10.4 — Download history**

Track all URLs downloaded into a vault:
- Store in SQLite: URL, download date, resulting file count
- "Sources" tab in vault browser showing download origins
- Re-download capability if source is still available

### What you can demo after Stage 10
"I dragged a Macintosh Garden link onto RetroRescue. It downloaded the StuffIt archive, extracted 12 files, and they're all in my vault with full metadata — one drag-and-drop."

---

## Stage 11: Vault-to-Emulator Bridge

### What it delivers
Export files from a vault directly into a format usable by SheepShaver, Basilisk II, or Mini vMac. Create HFS disk images from vault contents. This closes the loop: files go from vintage → vault → modern AND back from vault → vintage.

### Technical work

**11.1 — HFS disk image writer**

Using `machfs` (Python) or `hfsutils`:

```python
from machfs import Volume, Folder, File

v = Volume()
# For each vault entry, create the corresponding file
f = File()
f.data = data_fork_bytes
f.rsrc = rsrc_fork_bytes
f.type = b'TEXT'
f.creator = b'ttxt'
v['MyFolder']['MyFile'] = f

with open('output.dsk', 'wb') as out:
    out.write(v.write(size=1440*1024, align=512, desktopdb=True))
```

Options:
- Disk size: 800K, 1.4MB, 10MB, 100MB, 800MB (CD), custom
- Volume name: user-specified or inherited from vault name
- Include Desktop DB (prevents rebuild dialog on vintage Mac)
- Bootable option (for system disks)

**11.2 — SheepShaver / Basilisk II shared folder export**

Both emulators support shared host folders. Export vault contents to a shared folder with proper AppleDouble `._` files so the emulator reconstructs the resource forks:
- For each file: write data fork as `filename`, write resource fork + Finder info as `._filename` (AppleDouble format)
- The emulator's host filesystem driver reads both and presents a proper Mac file inside the VM

**11.3 — UI: "Send to Emulator" action**

- Right-click file/folder → "Create Disk Image..." → size/name picker → writes .dsk/.img
- Right-click file/folder → "Export for SheepShaver..." → exports to shared folder with AppleDouble
- Settings: configure default emulator shared folder path

### What you can demo after Stage 11
"I found an app on Macintosh Garden, imported it into my vault, then created a 1.4MB floppy image. I opened SheepShaver, and the app runs perfectly."

---

## Stage 12: App Distribution & Website

### What it delivers
A polished, distributable macOS app and a marketing website at retrorescue.app.

### Technical work

**12.1 — App packaging**

- Code signing with Developer ID
- Notarization with `notarytool`
- DMG creation with background image (same workflow as RetroGate)
- Sparkle framework for auto-updates (or manual download from website)
- Homebrew cask: `brew install --cask retrorescue`

**12.2 — Dependency bundling**

Decision per dependency:
- `unar`: prompt user to install via Homebrew (too large to bundle, LGPL complicates bundling)
- `hfsutils`: small, can bundle the binary inside the app bundle's `Resources/`
- `sips`: ships with macOS, no action needed
- `ffmpeg`: prompt user to install via Homebrew (optional dependency, huge binary)
- Python + machfs: bundle a minimal Python via `python3 -m venv` or use `hfsutils` only

**12.3 — App Store considerations**

The App Store is problematic because:
- Sandbox restricts `Process()` calls to external tools
- Can't bundle GPL'd binaries
- File system access is restricted

Options:
- Direct distribution only (like RetroGate): DMG from website, notarized
- App Store with reduced functionality: built-in parsers only (MacBinary, BinHex, resource forks, HFS via pure Swift port), no external tool integration
- Both: App Store "Lite" + full-featured direct download

Recommendation: direct distribution first. App Store can come later if demand exists, with a pure-Swift rewrite of critical parsers.

**12.4 — Website (retrorescue.app)**

Same style as retrogate.app. Key pages:
- Hero: "Your classic Mac files. Safe on your modern Mac." + download button
- Features: Open → Store → Browse → Convert pipeline, illustrated
- Supported formats: visual grid of all formats handled
- Screenshots: vault browser, resource viewer, conversion in action
- Docs: getting started, FAQ, format reference

---

## Stage 13: Advanced Features (Future)

These are independent features that can be added in any order after the core is stable.

**13.1 — Vault merge**
Merge two vaults into one, deduplicating by checksum. Useful when consolidating collections.

**13.2 — Vault diff**
Compare two vaults and show differences: files unique to each, files with different versions.

**13.3 — Collection statistics**
Dashboard showing: total files, breakdown by type/creator, oldest/newest files, most common apps, file size distribution, format coverage ("You have 47% of known System 7 extensions").

**13.4 — Catalog export**
Generate a static HTML site from a vault: browsable file tree with thumbnails, metadata tables, downloadable exports. Host your collection online.

**13.5 — Duplicate detection**
Scan a vault (or across vaults) for duplicate files by checksum. Show duplicates, offer to merge/delete.

**13.6 — Provenance graph**
Visual graph showing: this disk image → contained this archive → which contained these files → which were exported to these modern files. Full traceability.

**13.7 — Batch import from folder**
Point RetroRescue at a folder (e.g., a dump from an old hard drive) and auto-detect + import all classic Mac files recursively. Identify MacBinary-wrapped files mixed in with regular files.

**13.8 — RetroGate integration**
When RetroGate downloads a file through its proxy, offer to store it in a RetroRescue vault. Shared protocol via URL scheme: `retrorescue://import?url=...`

---

## Technology Summary

| Component | Technology | Reason |
|-----------|------------|--------|
| App framework | SwiftUI | Native macOS, same as RetroGate |
| Package manager | SPM | Same as RetroGate, no CocoaPods/Carthage |
| Database | SQLite (via system libsqlite3) | Ships with macOS, zero dependencies |
| Archive extraction | unar CLI (Homebrew) | Handles all classic Mac archive formats |
| HFS volumes | hfsutils CLI or machfs (Python) | Proven, maintained |
| Resource forks | Built-in Swift parser | Well-documented format, ~200 lines |
| PICT conversion | macOS sips | Ships with macOS, handles PICT natively |
| Resource conversion | resource_dasm or built-in | Icons, sounds, text are simple formats |
| Video transcoding | ffmpeg CLI (Homebrew) | Optional, for legacy QuickTime |
| Font conversion | Built-in + fonttools (Python) | BDF export is simple; TTF needs fonttools |
| Disk image writing | machfs (Python) | Clean API for HFS image creation |

## Stage Dependency Graph

```
Stage 1: Vault Core
    │
    ├── Stage 2: MacBinary & BinHex parsers
    │       │
    │       ├── Stage 3: Archive extraction (unar)
    │       │       │
    │       │       └── Stage 10: Web drag & drop
    │       │
    │       └── Stage 4: HFS disk images
    │               │
    │               └── Stage 11: Vault-to-emulator bridge
    │
    ├── Stage 5: Resource fork browser
    │       │
    │       └── Stage 6: Preview engine
    │               │
    │               └── Stage 8: Thumbnails, search, polish
    │
    └── Stage 7: Conversion engine
            │
            └── Stage 9: Advanced converters (fonts, docs, video)

Stage 12: App distribution (can start after Stage 7)
Stage 13: Advanced features (independent, any time after Stage 8)
```

## What Ships When

| Milestone | Stages | What the user gets |
|-----------|--------|--------------------|
| **Alpha** | 1-4 | Create vaults, import MacBinary/BinHex/StuffIt/HFS, browse file tree with metadata |
| **Beta** | 5-7 | Preview resources (icons, sounds, images, text), export to modern formats |
| **v1.0** | 8 | Thumbnails, search, Quick Look, polished UI |
| **v1.1** | 9-10 | Font converter, ClarisWorks converter, web drag & drop |
| **v1.2** | 11 | Disk image writer, emulator bridge |
| **v2.0** | 12-13 | App Store, website, advanced features |
