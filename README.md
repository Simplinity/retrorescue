# RetroRescue

**Rescue vintage Mac files for the modern world.**

RetroRescue is a macOS app that opens, preserves, and converts classic Macintosh files. Drop a disk image, a StuffIt archive, or a folder of old Mac files — RetroRescue cracks them open, lets you browse the contents with full classic Mac fidelity, stores them safely in a `.retrovault` bundle, and converts them to modern formats.

🌐 **retrorescue.app**

## What it does

1. **Open Anything** — Disk images (.dsk, .img, .smi, .toast, .iso), archives (.sit, .cpt, .hqx, .bin, .dd), MacBinary, BinHex, HFS/HFS+ volumes. If it's from a classic Mac, RetroRescue can open it.
2. **Browse & Preview** — See files with their original icons, type/creator codes, and resource forks. Preview PICT images, play sounds, inspect icons, read documents.
3. **Safe Storage** — The `.retrovault` bundle preserves everything: data forks, resource forks, type/creator codes, Finder metadata. Survives iCloud, Dropbox, ZIP, FAT32, email — nothing gets stripped.
4. **Convert & Export** — Batch-convert to modern formats: PICT → PNG, snd → WAV, bitmap fonts → TTF, ClarisWorks → DOCX, MacWrite → Markdown.

## The .retrovault format

A macOS bundle that safely stores classic Mac files on modern filesystems:

```
MyArchive.retrovault/
├── vault.sqlite              ← metadata database
├── manifest.json             ← human-readable vault info
├── files/
│   ├── 0001/
│   │   ├── data              ← data fork (raw bytes)
│   │   ├── rsrc              ← resource fork (raw bytes)
│   │   └── meta.json         ← type/creator, dates, Finder flags
│   └── ...
├── thumbnails/               ← generated previews
└── sources/                  ← original disk images/archives (optional)
```

No extended attributes. No special filesystem features. Survives everything.

## Requirements

- macOS 14+ (Sonoma) on Apple Silicon
- Swift 5.9+

## Building

```bash
cd retrorescue
swift build
swift run RetroRescue
```

Or open in Xcode:
```bash
open Package.swift
```

## Architecture

```
Sources/
├── RetroRescue/         # SwiftUI app
├── ContainerCracker/    # Archive & disk image unpacking
├── VaultEngine/         # .retrovault read/write/query
├── PreviewEngine/       # Type-aware file previewing
└── ConversionEngine/    # Format converters (PICT→PNG, snd→WAV, etc.)
```

## Powered by

RetroRescue wraps battle-tested open-source tools:

- [The Unarchiver / unar](https://theunarchiver.com) — StuffIt, Compact Pro, DiskDoubler, BinHex, MacBinary
- [hfsutils / libhfs](https://www.mars.org/home/rob/proj/hfs/) — HFS volume access
- [resource_dasm](https://github.com/fuzziqersoftware/resource_dasm) — Resource fork conversion
- [ResForge](https://github.com/andrews05/ResForge) — Resource fork parsing (Swift, MIT)
- macOS `sips` — PICT image conversion
- `ffmpeg` — Legacy QuickTime codec transcoding

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

Copyright (C) 2026 Bruno van Branden (Simplinity)
