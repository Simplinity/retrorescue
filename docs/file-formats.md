# Classic Macintosh File Formats — Complete Reference

> RetroRescue internal documentation. Covers all file formats, archive types, disk images,
> encoding wrappers, and type/creator codes relevant to classic Macintosh file preservation.
> Compiled from Apple documentation, community research, and reverse engineering efforts.

---

## Table of Contents

1. [The Macintosh File System Philosophy](#1-the-macintosh-file-system-philosophy)
2. [Archive & Compression Formats](#2-archive--compression-formats)
3. [Encoding & Transport Wrappers](#3-encoding--transport-wrappers)
4. [Disk Image Formats](#4-disk-image-formats)
5. [File Systems](#5-file-systems)
6. [CD-ROM & Optical Disc Formats](#6-cd-rom--optical-disc-formats)
7. [Type & Creator Codes](#7-type--creator-codes)
8. [Classic Mac File Types by Category](#8-classic-mac-file-types-by-category)
9. [Tools & Extraction Pipeline](#9-tools--extraction-pipeline)
10. [References](#10-references)

---

## 1. The Macintosh File System Philosophy

Unlike DOS/Windows which used file extensions (.txt, .doc) to identify files, the original Macintosh
used a fundamentally different approach:

### Dual Fork Architecture
Every Macintosh file consists of two "forks":
- **Data Fork** — The main content (text, image data, etc.)
- **Resource Fork** — Structured binary data: icons, menus, dialog layouts, sounds, code

This architecture meant that a single file could contain its data AND its user interface elements.
Applications stored their executable code in the resource fork. This is why simply copying a Mac file
to a DOS disk would often destroy it — the resource fork would be lost.

### Type and Creator Codes
Instead of file extensions, every Mac file carried two 4-character codes in its Finder metadata:
- **Type Code** — What kind of file it is (e.g., `TEXT`, `PICT`, `APPL`)
- **Creator Code** — Which application created it (e.g., `MSWD` for Microsoft Word)

The Finder maintained a desktop database mapping creator codes to applications. Double-clicking a file
would look up the creator code and launch the correct application. This was more sophisticated than
file extensions because different applications could create the same file type, and the system knew
which specific app to use.

Apple reserved all-lowercase creator codes for its own use. Developers registered their codes with Apple
to avoid conflicts. The TCDB (Type/Creator Database) by Ilan Szekely documented over 44,000 type/creator
combinations.

---

## 2. Archive & Compression Formats

### PackIt (.pit) — 1986
- **Developer**: Harry Chesley
- **Purpose**: First widely-used Mac archiving utility
- **History**: Created to distribute code for the online magazine *MacDeveloper*. Originally a pure
  archiver (no compression) that combined data fork, resource fork, and Finder info into one stream.
  PackIt II added Huffman compression. PackIt III (mid-1986) added DES encryption.
- **Type/Creator**: `PACK`/`PIT `
- **Fate**: Completely superseded by StuffIt in late 1987. Chesley joined Apple in Dec 1986.
- **Support in RetroRescue**: Via unar

### StuffIt (.sit) — 1987
- **Developer**: Raymond Lau (16-year-old student at Stuyvesant High School, NYC)
- **Company**: Aladdin Systems (1988), later Allume Systems (2004), then Smith Micro Software (2005)
- **Purpose**: The dominant Mac compression utility for 14 years (1987–2001)
- **History**: Combined MacBinary-style fork handling with LZW compression. Compressed data and resource
  forks separately for better ratios. By fall 1987, had replaced PackIt entirely. Last shareware
  release by Lau was v1.5.1. Aladdin split into StuffIt Classic (shareware) and StuffIt Deluxe
  (commercial). StuffIt Expander (free decompressor) was bundled with Mac OS from mid-1990s until 2005.
- **Format versions**:
  - StuffIt 1.5 — Original format
  - StuffIt 5.x — New format, incompatible with older versions
  - StuffIt X (.sitx) — Completely new format (Sept 2002), added PPM/BWT compression, encryption,
    error correction, block mode
- **Type/Creator**: `SIT!`/`SIT!` (or `SITD`/`SIT!` for Deluxe), `SITX`/`SITx` for StuffIt X
- **Self-extracting**: `.sea` — Application that decompresses itself when double-clicked
- **Support in RetroRescue**: Via unar (all versions)

### Compact Pro (.cpt) — 1990
- **Developer**: Bill Goodman
- **Original name**: Compactor (renamed due to trademark issues)
- **Purpose**: Competitor to StuffIt with better compression on some file types
- **History**: Freeware utilities like cptExpand and Extractor could decompress. StuffIt Expander
  also added support. Never seriously threatened StuffIt's dominance.
- **Type/Creator**: `PACT`/`CPCT`
- **Support in RetroRescue**: Via unar

### DiskDoubler (.dd) — 1989
- **Developer**: Terry Morse & Lloyd Chambers (Salient Software)
- **Purpose**: Transparent in-place file compression (not archiving)
- **History**: Unlike StuffIt which creates archive files, DiskDoubler compressed files "in place" on
  the hard drive. Files decompressed automatically when opened. AutoDoubler added background compression.
  Was the second-best-selling Mac product (after After Dark screensaver). Included DDExpand freeware
  decompressor. Sold to Fifth Generation Systems (1992), then Symantec (Norton DiskDoubler Pro 1.1).
- **Algorithms**: DD1 (fast), DD2, DD3, DD3+ (highest compression of any Mac software at the time)
- **Hardware**: Sigma Designs' DoubleUp NuBus card provided hardware-accelerated compression
- **Type/Creator**: `DBLR`/`DDsk`
- **Support in RetroRescue**: Via unar

### MacCompress (.Z) — Late 1980s
- **Developer**: Lloyd Chambers (later of DiskDoubler fame)
- **Purpose**: Mac port of Unix `compress` utility (LZW algorithm)
- **Support in RetroRescue**: Via unar

### Other Mac Archive Formats

| Format | Extension | Developer | Year | Notes |
|--------|-----------|-----------|------|-------|
| ARC | .arc | System Enhancement Associates | 1985 | Popular on BBS systems, Mac port existed |
| Zoo | .zoo | Rahul Dhesi | 1986 | Cross-platform, used on early Internet |
| LHA/LZH | .lzh, .lha | Haruyasu Yoshizaki | 1988 | Dominant in Japan, used for Amiga too |
| Diamond | .dia | – | 1980s | Obscure Mac archiver |
| Zoom | .zoo | – | 1980s | Mac-specific variant |
| MacLHa | .lzh | – | 1990s | Mac port of LHA |
| ShrinkWrap | .img | Aladdin Systems | 1990s | Disk image mounting + StuffIt decompression |
| Now Compress | – | Now Software | 1990s | Competed with DiskDoubler |
| StuffIt SpaceSaver | – | Aladdin Systems | 1990s | Aladdin's DiskDoubler competitor |
| SuperDisk! | – | Alysis Software | 1990s | Faster than DiskDoubler, less compression |

### Cross-Platform Formats on Mac

| Format | Extension | Notes |
|--------|-----------|-------|
| ZIP | .zip | Supported via ZipIt, later built into Mac OS X |
| RAR | .rar | Via MacRAR or later StuffIt |
| 7-Zip | .7z | Modern, via The Unarchiver |
| gzip | .gz | Unix standard, via MacGzip |
| bzip2 | .bz2 | Unix standard |
| tar | .tar | Unix standard, via SunTar or MacTar |
| XZ | .xz | Modern LZMA2 compression |
| Zstandard | .zst | Facebook's compression, very fast |
| CAB | .cab | Microsoft Cabinet files |
| ARJ | .arj | DOS archiver by Robert Jung |

---

## 3. Encoding & Transport Wrappers

These are NOT compression formats. They wrap Mac files for safe transport over networks that
don't understand dual-fork files or 8-bit data.

### BinHex 4.0 (.hqx) — 1985
- **Developer**: Yves Lempereur
- **Purpose**: Convert Mac binary files to 7-bit ASCII for email/Usenet transmission
- **How it works**: Encodes the data fork, resource fork, and Finder info (type/creator codes)
  into a text stream using a 6-bit encoding (like Base64 but different character set). Also applies
  RLE compression.
- **Header**: `(This file must be converted with BinHex 4.0)`
- **History**: Essential for early Internet when email could only handle 7-bit ASCII. The name comes
  from the binary-to-hexadecimal conversion concept. BinHex 5.0 was a different, incompatible format.
- **Type/Creator**: `TEXT`/`BnHq`
- **Support in RetroRescue**: Native parser (ContainerCracker) + unar

### MacBinary (.bin) — 1985
- **Developer**: Dennis Brothers (spec), community effort
- **Purpose**: Combine both forks + Finder info into a single binary stream for file transfer
- **Versions**:
  - MacBinary I (1985) — Original 128-byte header + data fork + resource fork
  - MacBinary II (1987) — Added CRC, secondary header info, script code
  - MacBinary III (1996) — Added support for longer filenames
- **Header**: 128 bytes containing filename, type/creator, fork sizes, dates, Finder flags
- **History**: The standard way to store Mac files on non-Mac systems. Most FTP clients auto-encoded
  downloads to MacBinary. The header starts with a zero byte, then filename length (1-63).
- **Type/Creator**: varies (preserves original)
- **Support in RetroRescue**: Native parser (ContainerCracker)

### AppleSingle / AppleDouble — 1990
- **Developer**: Apple Computer
- **Purpose**: Store Mac file metadata on non-Mac filesystems
- **AppleSingle**: Both forks + metadata in one file (magic: 0x00051600)
- **AppleDouble**: Data fork as normal file, metadata in companion `._filename` file (magic: 0x00051607)
- **History**: AppleDouble became the standard on macOS for preserving resource forks on non-HFS
  volumes. When you copy a Mac file to a FAT32 USB drive, macOS creates `._filename` files.
  ZIP archives on Mac often contain these `._` files.
- **Support in RetroRescue**: Native parser (ContainerCracker)

### UUencode (.uu, .uue) — 1980
- **Purpose**: Unix-to-Unix encoding for binary files over email
- **Notes**: Predates BinHex, not Mac-specific but commonly encountered

### MIME/Base64
- **Purpose**: Modern email encoding that replaced both UUencode and BinHex
- **Notes**: Built into all modern email clients

---

## 4. Disk Image Formats

### DiskCopy 4.2 (.image, .img, .dc42) — 1988
- **Developer**: Apple Computer (Steve Christensen)
- **Purpose**: Create exact copies of floppy disks for distribution and backup
- **Reference**: CiderPress2 DiskCopy-notes.md, DiscFerret wiki
- **Type/Creator**: `dImg`/`dCpy`
- **Format**: 84-byte header + user data + tag data
- **Header structure** (all big-endian):
  ```
  +$00 /64: diskName — Pascal string (length byte + up to 63 chars, Mac OS Roman)
  +$40 / 4: dataSize — length of user data in bytes (must be multiple of 512)
  +$44 / 4: tagSize — length of tag data (multiple of 12; may be zero)
  +$48 / 4: dataChecksum — custom checksum of userData area
  +$4c / 4: tagChecksum — custom checksum of tagData (first 12 bytes excluded!)
  +$50 / 1: diskFormat — 0=400K GCR, 1=800K GCR, 2=720K MFM, 3=1440K MFM
  +$51 / 1: formatByte — $12=400K, $22=800K Mac, $24=800K IIgs
  +$52 / 2: private — must be $0100 (identifies DiskCopy 4.2)
  +$54 / n: userData — sequential 512-byte blocks
  +xxx / n: tagData — 12 bytes per block (important for Lisa, mostly zero on Mac)
  ```
- **Checksum algorithm**: Custom (not CRC). Rotate-and-add on 32-bit values.
  NOTE: First 12 bytes of tag data excluded from tag checksum (backward compat bug).
- **Disk sizes**:
  - 400K: 409,600 bytes (original Mac 128K/512K single-sided floppy)
  - 800K: 819,200 bytes (Mac Plus double-sided floppy)
  - 720K: 737,280 bytes (PC MFM format)
  - 1440K: 1,474,560 bytes (High Density, SuperDrive)
- **Resource fork**: Contains copy of checksums. Not required; often lost in transit.
- **History**: DiskCopy 4.2 was the most common format for distributing floppy disk images.
  DiskCopy 6.x (NDIF) replaced it. The `.image` extension is canonical.
  macOS dropped DiskCopy 4.2 support after Catalina (10.15).
- **Support in RetroRescue**: Native Swift parser (DiskImageParser) + hfsutils
### DART (.dart, .image) — 1988
- **Developer**: Apple Computer
- **Full name**: Disk Archive/Retrieval Tool
- **Purpose**: Compressed disk images for internal Apple software distribution
- **Format**: Header (compression type + disk type + size + block lengths) + compressed chunks
- **Compression**: RLE (word-oriented, "fast") or LZHUF ("best")
- **Each chunk**: 20960 bytes = 40 blocks × (512 data + 12 tag) bytes
- **Header**: Byte 0 = compression (0=RLE, 1=LZH, 2=none), Byte 1 = disk type, Bytes 2-3 = size in KB
- **Type/Creator**: `DMd1`–`DMd7`/`DART` (type varies by disk kind)
- **History**: Used by Apple for internal software distribution. Never officially published.
  DART was not an official product. File format documented by CiderPress II project (Andy McFadden).
  DiskCopy 6.x, ShrinkWrap 2.1+, and MungeImage could also open DART images.
  macOS hdiutil supported DART until Catalina (10.15); removed in Big Sur.
- **Note**: `.mar` files are NOT DART — they use the separate MAR (Macintosh ARchive) format.
- **Support in RetroRescue**: RLE-compressed DART images fully supported. LZH planned.

### NDIF — New Disk Image Format (.img) — 1995
- **Developer**: Apple Computer
- **Used by**: DiskCopy 6.0 through 6.3.3
- **Purpose**: Successor to DiskCopy 4.2 format for larger volumes
- **Sub-formats**:
  - `RdWr` — Read/write (raw sector data in data fork)
  - `Rdxx` — Read-only (truncated unused sectors)
  - `ROCo` — Compressed (data in resource fork — if resource fork lost, image is useless!)
  - `Rken` — Compressed (obsolete variant)
  - `DC42` — DiskCopy 4.2 compatible mode
- **History**: DiskCopy 6.0 was a complete rewrite. Could mount images on the desktop (4.2 couldn't).
  WARNING: macOS `hdiutil` has a known bug that corrupts DiskCopy 6.x images.
- **Support in RetroRescue**: Via macOS `hdiutil convert` → raw → hfsutils

### UDIF — Universal Disk Image Format (.dmg) — 2001
- **Developer**: Apple Computer
- **Purpose**: Modern macOS disk image format
- **Magic**: `koly` (0x6B6F6C79) in the 512-byte trailer at end of file
- **Compression**: ADC (Apple proprietary), zlib, bzip2, LZFSE (10.11+), lzma (10.15+)
- **History**: Introduced with Mac OS X. XML plist in trailer describes block map.
  The standard format for distributing macOS software.
- **Support in RetroRescue**: Via macOS `hdiutil`

### Raw Disk Images (.dsk, .hfv, .raw)
- **No header** — just raw sector data (512 bytes/sector)
- **Detection**: Check for filesystem magic at offset 1024
- **Common sources**: Created by `dd`, disk dumping tools, emulators
- **Support in RetroRescue**: Direct to hfsutils

---

## 5. File Systems

### MFS — Macintosh File System (1984)
- **Magic**: 0xD2D7 at offset 1024 from volume start (high ASCII "RW")
- **Reference**: Inside Macintosh Vol. II ch.4, CiderPress2 MFS-notes.md
- **Used on**: Original Macintosh 128K, 512K (400K single-sided floppies)
- **Features**: FLAT directory (no nested folders!), dual forks, type/creator codes
- **Structure**:
  - Blocks 0-1: Boot code
  - Blocks 2-3: Master Directory Block (volume info + 12-bit allocation block map)
  - Blocks 4-15: File directory (fixed size, ~12 blocks on 400K)
  - Blocks 16+: Allocation blocks with file data
  - Last 2 blocks: MDB backup
- **Volume Info** (at block 2):
  ```
  +$00 / 2: drSigWord — 0xD2D7
  +$02 / 4: drCrDate — creation date (seconds since Jan 1, 1904)
  +$0c / 2: drNmFls — number of files
  +$12 / 2: drNmAlBlks — number of allocation blocks
  +$14 / 4: drAlBlkSiz — allocation block size in bytes
  +$24 /28: drVN — volume name (Pascal string)
  ```
- **Block map**: Array of 12-bit values. 0=free, 1=end of chain, 2+=next block number.
- **Directory entries**: Variable size (51 bytes + filename), cannot cross block boundaries.
  Each entry has: type/creator, data fork start/size, rsrc fork start/size, dates, filename.
- **Filenames**: Up to 255 chars (64K ROM), 31 chars recommended (128K ROM+). Mac OS Roman.
- **Note**: Folders in the Finder were an illusion maintained by the Desktop Database.
- **History**: First Mac filesystem (1984). Replaced by HFS in 1986. OS support until Mac OS 8.1.
- **Support in RetroRescue**: Detected, not yet extractable. Planned via native Swift parser.

### HFS — Hierarchical File System (1985)
- **Magic**: 0x4244 ("BD") at offset 1024 from volume start
- **Reference**: Inside Macintosh: Files ch.2, CiderPress2 HFS-notes.md (700+ lines)
- **Used on**: Mac Plus through Mac OS 9, most classic Mac floppies and hard drives
- **Features**: True directory hierarchy, dual forks, type/creator codes, Finder info,
  31-character filenames (case-preserving, case-insensitive), B*-tree catalog
- **Max volume size**: 2 GB (increased to 2 TB with System 7.5)
- **Key structures**:
  - Block 0-1: Boot blocks (signature `LK` = 0x4C4B for bootable)
  - Block 2: Master Directory Block (MDB, 162 bytes, signature `BD` = 0x4244)
  - Block 3+: Volume bitmap (1 bit per allocation block)
  - Catalog file: B*-tree with files, directories, and thread records
  - Extents overflow: B*-tree for files with >3 extents
  - Second-to-last block: MDB backup copy
- **MDB key fields**: volume name, allocation block size/count, catalog tree location,
  free blocks, next CNID, creation/modification dates
- **B*-tree**: 512 bytes/node, header node → index nodes → leaf nodes, singly-linked leaves
- **Catalog keys**: parent CNID + filename, sorted by CNID then case-insensitive name
- **4 record types**: file (102 bytes), directory (70 bytes), file thread, directory thread
- **CNIDs**: 0=invalid, 1=root parent, 2=root dir, 3=extents file, 4=catalog file, 5=bad blocks
- **Timestamps**: Unsigned 32-bit, seconds since Jan 1, 1904, local time. Rolls over Feb 6, 2040.
- **History**: Introduced with the Macintosh Plus and HD20 hard drive in 1985.
  Standard Mac filesystem for 13 years. macOS dropped HFS read support in Catalina (2019).
- **Support in RetroRescue**: Via bundled hfsutils. Native Swift reader planned for v2.

### HFS+ — HFS Plus / Mac OS Extended (1998)
- **Magic**: 0x482B ("H+") at offset 1024 from volume start
- **Used on**: Mac OS 8.1 through macOS Mojave
- **Features**: Unicode filenames (255 chars), nanosecond timestamps, journaling (10.2.2+),
  case-sensitivity option, transparent compression (10.6+)
- **Support in RetroRescue**: Planned (macOS can mount HFS+ natively)

### APFS — Apple File System (2017)
- **Used on**: macOS High Sierra and later, iOS 10.3+
- **Not relevant for classic Mac file preservation**

### Apple Partition Map (APM)
- **Reference**: Inside Macintosh: Devices ch.3, CiderPress2 APM-notes.md
- **Purpose**: Partition scheme for Mac hard drives, CD-ROMs, and other block devices
- **Used on**: Macintosh II (1987) through Intel Macs (replaced by GPT)
- **Structure**:
  - Block 0: Driver Descriptor Record (DDR) — signature `ER` (0x4552), block size, block count
  - Block 1+: Partition entries — signature `PM` (0x504D), one per block
  - Each entry: start block, block count, name (32 chars), type (32 chars)
- **Partition types**:
  - `Apple_HFS` — HFS filesystem (the one we want)
  - `Apple_MFS` — MFS filesystem (original 64K ROM Macs)
  - `Apple_partition_map` — the map itself (self-referential)
  - `Apple_Driver` / `Apple_Driver43` — disk drivers
  - `Apple_Free` — unused space
  - `Apple_Scratch` — empty
  - `Apple_PRODOS` — ProDOS (Apple II)
  - `Apple_Unix_SVR2` — A/UX (Apple's Unix)
- **Real-world issues**: Third-party formatters produce bad DDR values (zero block count/size).
  CD-ROMs may have oversized or out-of-bounds partitions. Tolerance is required.
- **Support in RetroRescue**: Not yet implemented (CRITICAL gap for CD-ROMs)

---

## 6. CD-ROM & Optical Disc Formats

### ISO 9660 (.iso) — 1988
- **Standard**: International standard for CD-ROM filesystems
- **Magic**: "CD001" at offset 32,769 (sector 16, byte 1)
- **Levels**: Level 1 (8.3 names), Level 2/3 (up to 30 chars)
- **Extensions**:
  - **Rock Ridge** — Unix permissions, symlinks, long names
  - **Joliet** — Microsoft extension, UCS-2 Unicode (up to 64 chars)
  - **El Torito** — Bootable CD specification
  - **Apple ISO 9660 Extensions** — Adds type/creator codes, resource forks, Finder info to ISO
- **Support in RetroRescue**: Via unar

### Hybrid ISO 9660/HFS
- **Detection**: "CD001" at offset 32,769 AND HFS magic 0x4244 at offset 1024
- **Purpose**: CDs readable on both Mac and PC. The ISO partition uses the first 32KB (system area)
  to coexist with the Apple partition map or HFS MDB.
- **History**: Mac OS 9 and OS X burned hybrid discs by default. Common for commercial software
  that shipped on CD (e.g., Blizzard games, Adobe Creative Suite).
- **Support in RetroRescue**: HFS side via hfsutils, ISO side via unar

### Toast (.toast) — Roxio
- **Developer**: Roxio (originally Astarte, then Adaptec)
- **Purpose**: Disc image format for Toast CD/DVD burning software
- **Support in RetroRescue**: Via unar

### BIN/CUE (.bin, .cue)
- **Purpose**: Raw CD sector dump (2352 bytes/sector) with layout description
- **The .bin file**: Raw sectors including subcode data
- **The .cue file**: Text file describing track layout
- **Support in RetroRescue**: Via unar

### Other Optical Disc Formats

| Format | Extension | Developer | Notes |
|--------|-----------|-----------|-------|
| NRG | .nrg | Nero AG | Nero Burning ROM proprietary format |
| CDR | .cdr | Apple | macOS Disk Utility "DVD/CD Master" format |
| MDF/MDS | .mdf, .mds | Alcohol Software | Alcohol 120% disc image |
| UDF | — | OSTA | Universal Disc Format, used on DVDs |

---

## 7. Type & Creator Codes

### System File Types (Apple-defined)

| Type Code | Description |
|-----------|-------------|
| `TEXT` | Plain text file |
| `ttro` | Read-only text (TeachText/SimpleText) |
| `sEXT` | Styled text |
| `utxt` | Unicode text |
| `PICT` | QuickDraw picture |
| `PNTG` | MacPaint image (1-bit bitmap, 576×720) |
| `APPL` | Application (executable) |
| `INIT` | System extension (loads at boot) |
| `cdev` | Control Panel device |
| `DRVR` | Desk Accessory |
| `dfil` | Desk Accessory file |
| `FFIL` | Font file (bitmap) |
| `sfnt` | TrueType font |
| `tfil` | Font suitcase |
| `snd ` | Sound resource |
| `AIFF` | Audio Interchange File Format |
| `MooV` | QuickTime movie |
| `MOOV` | QuickTime movie (alternate) |
| `GIFf` | GIF image |
| `JPEG` | JPEG image |
| `PNGf` | PNG image |
| `TIFF` | TIFF image |
| `PDF ` | PDF document |
| `ZSYS` | System file |
| `FNDR` | Finder |
| `zsys` | System suitcase |
| `tbmp` | Thumbnail/bitmap |
| `clpt` | Text clipping |
| `clpp` | Picture clipping |
| `clps` | Sound clipping |
| `WDBN` | Microsoft Word document |
| `XLS ` | Microsoft Excel spreadsheet |
| `SIT!` | StuffIt archive |
| `SITD` | StuffIt Deluxe archive |
| `dImg` | DiskCopy disk image |
| `rohd` | RAM disk |
| `rsrc` | Resource file |
| `BNDL` | Bundle (icon mapping) |

### Notable Creator Codes

| Creator | Application | Developer |
|---------|-------------|-----------|
| `MACS` | Finder | Apple |
| `ttxt` | TeachText / SimpleText | Apple |
| `MSWD` | Microsoft Word | Microsoft |
| `XCEL` | Microsoft Excel | Microsoft |
| `PPT3` | Microsoft PowerPoint | Microsoft |
| `ALD3`/`ALD4` | PageMaker | Aldus (later Adobe) |
| `BOBO` | BBEdit / BBEdit Lite | Bare Bones Software |
| `R*ch` | BBEdit (later) | Bare Bones Software |
| `RSED` | ResEdit | Apple |
| `CWIE` | CodeWarrior | Metrowerks |
| `KAHL` | THINK C / Symantec C++ | THINK Technologies / Symantec |
| `PJMM` | THINK Pascal | THINK Technologies |
| `MPS ` | MPW (Macintosh Programmer's Workshop) | Apple |
| `WILD` | HyperCard | Apple |
| `8BIM` | Photoshop | Adobe |
| `ART5` | Illustrator | Adobe |
| `CARO` | Acrobat | Adobe |
| `FH50`–`FH90` | FreeHand | Aldus/Macromedia |
| `XPRS` | QuarkXPress | Quark |
| `dCpy` | DiskCopy | Apple |
| `SIT!` | StuffIt | Aladdin Systems |
| `BnHq` | BinHex | Yves Lempereur |
| `CPCT` | Compact Pro | Bill Goodman |
| `DDsk` | DiskDoubler | Salient Software |
| `drag` | Claris FileMaker Pro | Claris/Apple |
| `nX^n` | WriteNow | T/Maker |
| `MOUP` | MOTU Performer | Mark of the Unicorn |
| `SCEL` | SoundEdit | Macromedia |
| `TVOD` | QuickTime Player | Apple |
| `ogle` | DVD Player | Apple |

---

---

## 7b. Resource Fork Binary Format

> Reference: Inside Macintosh: More Macintosh Toolbox p.1-121, CiderPress2 ResourceFork-notes.md

Every classic Mac file can have a resource fork containing structured data. The format is:

### Overall Layout
```
+$00  / 4: offset from file start to resource data
+$04  / 4: offset from file start to resource map
+$08  / 4: length of resource data
+$0c  / 4: length of resource map
+$10  /112: reserved (used by AppleShare for metadata)
+$80  /128: available for application data
+$100 / N: resource data area
+xxx  / N: resource map
```

### Resource Data Area
Each resource stored sequentially:
```
+$00 / 4: length of resource data that follows
+$04 / N: resource data bytes
```

### Resource Map
```
+$00 /16: reserved (copy of header when loaded to memory)
+$10 / 4: reserved (handle to next resource map)
+$14 / 2: reserved (file reference number)
+$16 / 2: resource file attributes
+$18 / 2: offset from map start to type list
+$1a / 2: offset from map start to name list
```

### Type List
Starts with count-1 (16-bit), then per type:
```
+$00 / 4: resource type (e.g. "ICON", "snd ", "STR#")
+$04 / 2: count of resources of this type, minus 1
+$06 / 2: offset from type list start to reference list
```

### Reference List (per resource)
```
+$00 / 2: resource ID (signed 16-bit)
+$02 / 2: offset to name in name list (-1 if no name)
+$04 / 1: resource attributes (locked, purgeable, preload, etc.)
+$05 / 3: offset from data area start to this resource's data
+$08 / 4: reserved (handle when loaded)
```

### Key Notes
- All multi-byte values are signed big-endian
- 3-byte data offset limits resource forks to 16MB
- 4-byte resource type, 2-byte resource ID (unlike Apple IIgs which uses 2/4)
- Resource attributes: bit 6=sysHeap, 5=purgeable, 4=locked, 3=protected, 2=preload, 1=changed

## 8. Classic Mac File Types by Category

### Text & Documents
| Type | Extension | Description | Previewable |
|------|-----------|-------------|-------------|
| TEXT | .txt | Plain text | Yes (MacRoman → UTF-8) |
| ttro | — | Read-only text (SimpleText) | Yes |
| RTF | .rtf | Rich Text Format | Yes (via textutil) |
| WDBN | .doc | MS Word (classic) | Via Quick Look |
| XDOC | .docx | MS Word (modern) | Via Quick Look |
| W6BN | .doc | MS Word 6 | Via Quick Look |
| W8BN | .doc | MS Word 98 | Via Quick Look |

### Images
| Type | Extension | Description | Previewable |
|------|-----------|-------------|-------------|
| PICT | .pct, .pict | QuickDraw picture | Via sips → PNG |
| PNTG | .pntg, .mac | MacPaint (1-bit, 576×720) | Via PackBits decoder |
| TIFF | .tif, .tiff | Tagged Image File Format | Via Quick Look |
| JPEG | .jpg, .jpeg | JPEG | Via Quick Look |
| GIFf | .gif | GIF | Via Quick Look |
| PNGf | .png | PNG | Via Quick Look |
| 8BPS | .psd | Photoshop | Via Quick Look |
| EPSF | .eps | Encapsulated PostScript | Via sips |

### Audio
| Type | Extension | Description | Previewable |
|------|-----------|-------------|-------------|
| AIFF | .aif, .aiff | Audio Interchange File Format (Apple's WAV) | Via Quick Look |
| Sd2f | .sd2 | Sound Designer II (Digidesign) | Needs converter |
| snd  | — | System sound resource | Needs converter |
| WAVE | .wav | Waveform audio | Via Quick Look |
| ULAW | .au | Sun/NeXT audio | Via ffmpeg |
| MPG3 | .mp3 | MPEG Audio Layer 3 | Via Quick Look |

### Video
| Type | Extension | Description | Previewable |
|------|-----------|-------------|-------------|
| MooV | .mov | QuickTime Movie | Via Quick Look / AVFoundation |
| MPEG | .mpg, .mpeg | MPEG-1/2 video | Via Quick Look |
| MPG4 | .mp4 | MPEG-4 video | Via Quick Look |
| VfW  | .avi | Video for Windows (AVI) | Via Quick Look |
| FLI  | .fli, .flc | Autodesk Animator | Needs converter |

### Fonts
| Type | Extension | Description | Notes |
|------|-----------|-------------|-------|
| FFIL | — | Bitmap font file | Stored in resource fork as FONT/NFNT resources |
| sfnt | .ttf | TrueType font | Data fork, modern format |
| tfil | — | Font suitcase | Container for multiple bitmap fonts |
| LWFN | .pfb | PostScript Type 1 (printer font) | Paired with screen font suitcase |
| — | .pfm | PostScript font metrics | Windows companion to .pfb |
| — | .otf | OpenType font | Modern, cross-platform |
| — | .dfont | Data-fork suitcase | Mac OS X transition format |

**Note on Classic Mac Fonts**: The Mac font system was complex. A complete font installation required:
1. A bitmap screen font (in a suitcase, FFIL type) for on-screen display
2. A PostScript printer font (LWFN type) for high-quality printing
3. TrueType later unified these into a single file

### Development Files
| Type | Extension | Description | Application |
|------|-----------|-------------|-------------|
| TEXT | .c, .h | C source code | THINK C, MPW, CodeWarrior |
| TEXT | .p, .pas | Pascal source code | THINK Pascal, MPW Pascal |
| TEXT | .r, .rez | Rez source (resource descriptions) | MPW Rez compiler |
| rsrc | — | Compiled resource file | ResEdit, Rez |
| APPL | — | Compiled application | All Mac compilers |
| MPST | — | MPW Shell script | MPW |
| MPWT | — | MPW tool | MPW |
| pref | — | Preferences file | Various |
| OBJ  | .o | Object code | Compilers |
| PRLB | — | Precompiled library | CodeWarrior |
| MMPr | — | CodeWarrior project | Metrowerks CodeWarrior |
| — | .π | THINK project file | THINK C / THINK Pascal |

### System Files
| Type | Extension | Description | Notes |
|------|-----------|-------------|-------|
| ZSYS | — | System file | The Mac OS itself |
| FNDR | — | Finder | The desktop manager |
| zsys | — | System suitcase | System resources |
| INIT | — | System extension | Loads at startup (Extensions folder) |
| cdev | — | Control Panel | Appears in Control Panels |
| appe | — | Background application | Faceless, runs in background |
| DRVR | — | Desk Accessory | Apple menu items (pre-System 7) |
| thng | — | Component | QuickTime components, etc. |
| scri | — | AppleScript script | Compiled AppleScript |
| osas | — | AppleScript applet | Standalone script application |

### Desktop Publishing & Graphics
| Type | Creator | Application | Developer | Era |
|------|---------|-------------|-----------|-----|
| ALB3 | ALD3 | PageMaker 3 | Aldus | 1987 |
| ALB4 | ALD4 | PageMaker 4 | Aldus | 1990 |
| ALB6 | ALD5 | PageMaker 6 | Adobe (acquired Aldus 1994) | 1995 |
| XDOC | XPRS | QuarkXPress document | Quark | 1987– |
| FHD2–FH90 | FH* | FreeHand | Aldus → Macromedia → Adobe | 1988–2003 |
| ILLU | ART5 | Illustrator | Adobe | 1987– |
| 8BPS | 8BIM | Photoshop | Adobe | 1990– |
| DRAW | MDPL | MacDraw | Apple/Claris | 1984–1998 |
| MPNT | MPNT | MacPaint | Apple | 1984–1998 |
| CWDB | CWDB | ClarisWorks/AppleWorks | Claris/Apple | 1991–2007 |
| AAPL | FLDR | Canvas | Deneba | 1987– |

### HyperCard
| Type | Creator | Description |
|------|---------|-------------|
| STAK | WILD | HyperCard stack |
| XFCN | — | External function (XFCN) |
| XCMD | — | External command (XCMD) |

HyperCard (1987, Bill Atkinson) was revolutionary — a visual programming environment
bundled free with every Mac. It introduced concepts later seen in the World Wide Web.
Stacks could contain text, images, buttons, scripts, sounds, and movies.
Type code `WILD` comes from the original name "WildCard."

---

## 9. Tools & Extraction Pipeline

### RetroRescue Extraction Flow

```
File dropped into vault
        │
        ├── MacBinary/BinHex/AppleDouble?
        │     └── Yes → Native Swift parser unwraps → store unwrapped file
        │     └── No → store as-is
        │
        ├── User clicks "Extract"
        │
        ├── Archive? (.sit, .cpt, .zip, .7z, .rar, .iso, etc.)
        │     └── unar (bundled, LGPL 2.1)
        │
        ├── HFS disk image? (.img, .image, .dsk, .mar, .dart)
        │     ├── DiskCopy 4.2 → strip 84-byte header (native Swift)
        │     ├── NDIF → hdiutil convert (macOS built-in)
        │     ├── UDIF → hdiutil convert (macOS built-in)
        │     ├── Raw HFS → pass through
        │     └── → hfsutils (bundled, GPL 2.0) extracts files
        │
        ├── Nested archive inside extracted files?
        │     └── User can extract recursively (unlimited depth)
        │
        └── Preview/Open
              ├── Text files → inline preview (MacRoman/UTF-8)
              ├── PDF → macOS Preview.app
              ├── Images → Quick Look (qlmanage)
              ├── PICT → sips convert to PNG (macOS built-in)
              └── Other → Quick Look or default app
```

### Bundled Tools

| Tool | Size | License | Purpose |
|------|------|---------|---------|
| unar | 2.2 MB | LGPL 2.1 | Archive extraction (40+ formats) |
| lsar | 2.3 MB | LGPL 2.1 | Archive listing |
| hmount | 146 KB | GPL 2.0 | Mount HFS volumes |
| hls | 146 KB | GPL 2.0 | List HFS contents |
| hcopy | 146 KB | GPL 2.0 | Copy from HFS |
| humount | 146 KB | GPL 2.0 | Unmount HFS |

### macOS Built-in Tools (always available)

| Tool | Purpose |
|------|---------|
| sips | Image conversion (PICT → PNG, resize, format change) |
| textutil | Document conversion (RTF, DOC → TXT, HTML) |
| qlmanage | Quick Look preview for any supported format |
| hdiutil | Disk image conversion (NDIF, UDIF → raw) |

### Future: Native Swift Replacements

These Python tools are used during development and will be rewritten in Swift for the release:

| Current Tool | Purpose | Swift Replacement Plan |
|-------------|---------|----------------------|
| machfs (Python) | HFS volume reading | Native Swift HFS reader using libhfs source as reference |
| macresources (Python) | Resource fork parsing | Native Swift Rez/DeRez implementation |

---

## 10. References

### Apple Documentation
- Inside Macintosh, Volumes I–VI (Apple Computer, 1985–1991)
- Inside Macintosh: Files (Apple Computer, 1992) — HFS specification
- Inside Macintosh: More Macintosh Toolbox — Resource Manager
- Technical Note TN1150: HFS Plus Volume Format (Apple, 2004)

### Format Specifications
- DiskCopy 4.2: https://www.discferret.com/wiki/Apple_DiskCopy_4.2
- MacBinary: https://files.stairways.com/other/macbinaryii-standard-info.txt
- BinHex 4.0: https://files.stairways.com/other/binhex-40-specs-info.txt
- AppleSingle/AppleDouble: Apple A/UX Toolbox Reference (1990)
- ISO 9660: ECMA-119 (freely available)

### Community Resources
- TCDB (Type/Creator Database): 44,000+ type/creator pairs by Ilan Szekely
  https://macintoshgarden.org/apps/typecreator-database
- Mac File Format Documentation: https://github.com/dgelessus/mac_file_format_docs
- machfs (Python HFS library): https://github.com/elliotnunn/machfs
- macresources (Python resource fork library): https://github.com/elliotnunn/macresources
- The Unarchiver (unar source): https://github.com/MacPaw/XADMaster
- hfsutils: https://www.mars.org/home/rob/proj/hfs/
- Just Solve the File Format Problem: http://fileformats.archiveteam.org/
- Macintosh Garden: https://macintoshgarden.org
- Vintage Mac Museum: https://vintagemacmuseum.com
- The Eclectic Light Company (Mac history): https://eclecticlight.co

### Historical Context
- StuffIt history: Raymond Lau, 16-year-old at Stuyvesant High School (1987)
- PackIt: Harry Chesley, first Mac archiver (1986), joined Apple Dec 1986
- DiskDoubler: Terry Morse & Lloyd Chambers, Salient Software (1989)
- Compact Pro: Bill Goodman, originally "Compactor" (1990)
- BinHex 4.0: Yves Lempereur (1985)
- MacBinary: Dennis Brothers spec, community effort (1985)
- HyperCard: Bill Atkinson, bundled free with every Mac (1987)
- ResEdit: Apple's resource editor, essential developer tool

---

*This document is maintained as part of the RetroRescue project.*
*Last updated: April 2026*
*License: GPLv3 (same as RetroRescue)*
