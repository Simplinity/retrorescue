# RetroRescue — Missing Formats & Features Analysis

> Compiled April 10, 2026. Complement to `docs/file-formats.md` and `docs/TODO.md`.
> This document inventories what we **don't** yet support and proposes 50 concrete
> features that would close the most painful gaps for classic Mac preservation.

---

## What We Already Support (baseline)

Before proposing additions, here is the current scope at a glance:

- **Archives (22)**: PackIt, StuffIt 1.x/5.x/SITX, Compact Pro, DiskDoubler, MacCompress, ARC, Zoo, LHA/LZH, ARJ, ZIP, RAR, 7-Zip, gzip, bzip2, tar, xz, Zstandard, CAB, Binary II (.bny), AppleLink PE (.acu), NuFX/ShrinkIt
- **Encoding wrappers (4)**: MacBinary I/II/III, BinHex 4.0, AppleSingle, AppleDouble
- **Disk images (15)**: DiskCopy 4.2, DART (RLE+LZHUF), NDIF, UDIF/DMG, raw .dsk/.hfv, 2IMG, WOZ, MOOF, ISO 9660, hybrid HFS/ISO, Toast, BIN/CUE, sector-order detection
- **Filesystems (9 native + 1 via tools)**: MFS, ProDOS, DOS 3.2/3.3, CP/M (140K + 800K), Apple Pascal/UCSD, Gutenberg WP, RDOS, plus HFS via hfsutils
- **Partitions (7)**: APM, Mac TS, CFFA, AmDOS/OzDOS/UniDOS, FocusDrive/MicroDrive, PPM, DOS hybrids
- **Resource fork**: 50+ types in registry, 19 type renderers
- **Preview**: CoreText font sheets (TTF/OTF/sfnt/FFIL/LWFN/AFM), text, PICT, MacPaint, icons, sounds, waveform, hex
- **Conversion**: PICT/MacPaint→PNG, snd→WAV, TEXT→UTF-8, ClarisWorks/MacWrite→Markdown (text only), QuickTime→MP4, bitmap font→BDF

---

## The 50 Missing Features

Each entry has: **effort** (XS/S/M/L/XL), **impact** (low/med/high), **approach** (native Swift / external tool / out of scope), and a brief justification.

Effort scale: XS = <1 day, S = 1-2 days, M = 3-5 days, L = 1-2 weeks, XL = >2 weeks.

---

## Category 1 — Word Processors & Text (10 features)

These were the dominant Mac document formats from 1984 onwards. Without proper extraction, decades of writing are stranded in opaque binaries.

### 1. WriteNow (`nX^n` / `WORD`) text + style extraction — M, **HIGH**
WriteNow was the second-most-popular Mac word processor (1986-1994), bundled free with NeXT computers. T/Maker. Format is documented (small chunked binary with style runs). Native Swift parser feasible. Currently: zero support.

### 2. MacWrite II / Pro full extraction — M, HIGH
We extract MacWrite Classic text only. MacWrite II (1989) and MacWrite Pro (1993) used different formats with style runs, embedded images, tables. Full extractor would need ~500 lines.

### 3. Microsoft Word 4/5/5.1 binary → Markdown — L, HIGH
The peak classic Word era (1989-1992). We currently rely on Quick Look which often fails. A native Swift extractor for Word 5 binary (the most common version, type code `WDBN`) would be a huge win. Reference: [wvWare](http://wvware.sourceforge.net/) source as a guide.

### 4. Microsoft Works Mac (`AWWP` text, `AWDB` db, `AWSS` ss) — L, MED
Bundled with cheap Performa Macs and many schools (1986-2000). Multi-document container with text, spreadsheet, database, draw. Whole generation of school papers stuck in here.

### 5. WordPerfect for Mac (`WPC2`/`WPD3`) — M, MED
Niche on Mac but used in legal/government. Format is well-documented (same as DOS WordPerfect 5.1/6.0). `libwpd` C library could be ported or shelled out to.

### 6. Nisus Writer Classic (`NISI`/`GLOB`) — M, MED
Rich Mac-only word processor with PowerPC versions. Used a custom format with embedded graphics. Beloved by linguists for its non-Roman script support.

### 7. FullWrite Professional (`FWRT`) — S, LOW
Ann Arbor Softworks/Akimbo, 1988. Briefly competed with Word. Few survivors but meaningful for archival.

### 8. RTF stylized parser — S, MED
We currently let the system handle RTF via `textutil`. A native parser that preserves Mac-specific RTF extensions (color tables, font tables with type codes) would extract more cleanly to Markdown.

### 9. styl resource → CSS/HTML — S, MED
Mac TextEdit and SimpleText stored style runs in `styl` resources alongside `TEXT`. We have the parser but don't render to HTML. Would let users see styled text exactly as it appeared.

### 10. SimpleText / TeachText with embedded PICTs — S, MED
TeachText documents could embed PICT images inline. Currently we show only the text. Needs to scan resource fork for PICT resources and inline them at the right offsets.

---

## Category 2 — Spreadsheets & Databases (8 features)

### 11. Microsoft Excel 4/5/98 (`XLS5`/`XLW4`) → CSV — L, HIGH
Excel BIFF format is documented (Microsoft's OpenOffice handover). Native Swift parser doable for the most common Mac versions. Currently we have nothing — Excel files just show as opaque blobs.

### 12. Lotus 1-2-3 Mac (`L123`/`WK1 `/`WK3 `) — M, MED
Lotus 1-2-3 was the spreadsheet on early Macs before Excel won. Format is identical to DOS .wk1/.wk3. `libwks` exists in C, could shell out.

### 13. ClarisWorks/AppleWorks spreadsheet (`CWSS`) → CSV — M, HIGH
We extract ClarisWorks text but ignore the spreadsheet documents. CWSS is a chunked binary, well-documented. Native Swift parser feasible.

### 14. FileMaker Pro Classic (`FMP3`/`FMP5`) → SQLite/CSV — XL, HIGH
The dominant Mac database (still alive today). Format is closed but partially reverse-engineered. The `fmptools` project decodes older FMP3-FMP5. Schools, churches, medical practices stored everything here.

### 15. HyperCard stack (`STAK`) — full content extraction — L, **HIGH**
We currently identify HyperCard stacks but don't extract them. A `STAK` file contains: card layout, fields, buttons, scripts (HyperTalk), painted backgrounds, sounds. The format is documented in [Apple's HyperCard Stack Format Specification](http://www.kreativekorp.com/miscpages/hcstackformat.html). Native Swift parser would be 1500+ lines but the cultural value is enormous — HyperCard was the original hyperlink medium.

### 16. SuperCard project (`SCRZ`) — M, MED
HyperCard's color-capable competitor. Similar architecture, less documented but the [SuperCard project](https://github.com/SuperCardMac) has open notes.

### 17. 4D Database (`4D03`) — XL, LOW
4D was popular in France/Europe for business apps. Closed binary format, very hard to reverse. Probably out of scope unless someone provides the spec.

### 18. Panorama (`PANR`) database → CSV — L, LOW
ProVUE Development. Niche but loyal user base. Format is partially documented in Panorama's own export tools.

---

## Category 3 — Graphics, DTP & Vector (10 features)

### 19. MacDraw / MacDraw II / MacDraw Pro (`DRWG`/`MDPL`) → SVG — L, **HIGH**
The original Mac vector drawing app, used for everything from architectural plans to school worksheets (1984-1998). Format is QuickDraw-based, documented. Native Swift parser → SVG export would let users finally open these files in modern tools.

### 20. SuperPaint (`SPNT`) → PNG/SVG hybrid — M, MED
Silicon Beach Software, 1986. Combined paint + draw layers. Beloved among educators. PICT-based with extensions.

### 21. Canvas (`CV15`/`CV35`/`drw2`) → SVG — L, MED
Deneba Canvas (1987-2003) was a serious Illustrator/PageMaker hybrid. Multiple format versions. Older ones (Canvas 3.5) are partially documented.

### 22. PageMaker 3-6.5 (`ALB3`-`ALB6`) text + layout extraction — L, **HIGH**
Aldus/Adobe PageMaker was the DTP standard. We need at minimum: extract all text frames in reading order, list image references, output a JSON layout map. Reference: [pmd-converter](https://github.com/Telecommunication-Telemedia-Assessment/pmd-converter).

### 23. QuarkXPress (`XDOC`) text + layout — L, HIGH
Quark dominated DTP from 1990-2005. Closed format but [`libqxp`](https://github.com/LibreOffice/libqxp) (LibreOffice's importer) handles versions 3.x-4.x. Could be linked or ported.

### 24. FreeHand v3-v11 (`FHD3`-`FHA1`) → SVG — XL, MED
Aldus/Macromedia/Adobe FreeHand. Closed binary format. `libfreehand` (LibreOffice) handles v3-v11. Cross-platform — same format on Mac and Windows.

### 25. Illustrator classic (`ART5`/`ART3`) — pre-PDF Illustrator — L, MED
Illustrator 1-7 used a custom format based on PostScript with binary header. Not the modern PDF-based AI files. `libcdr` handles some of these.

### 26. Photoshop (`8BPS`) layer extraction → PNG — M, HIGH
Photoshop .psd is documented. Modern macOS Quick Look only shows the flat composite. A real extractor would dump each layer as PNG with names + opacity + blend mode in a sidecar JSON.

### 27. PixelPaint Pro (`PIXR`) → PNG — S, LOW
SuperMac PixelPaint, the first 32-bit color paint program for Mac. Custom format with palette. Few survivors.

### 28. ClarisDraw / MacDraw III merge — M, MED
ClarisDraw (1993) was the last MacDraw. Combined MacDraw Pro + MacPaint + MacDraft. Same QuickDraw-based format family as MacDraw. If feature 19 is built, this comes mostly free.

---

## Category 4 — Audio & Music (7 features)

### 29. Sound Designer II (`Sd2f`) — data fork extractor — S, **HIGH**
Digidesign's standard 8/16-bit sample format used by every Mac musician 1989-2000. The audio is in the **resource fork** as a `STR ` resource (yes, really) and the sample rate is in `STR 1000`. Without us, every Mac sample library is unreadable. Native Swift, ~150 lines.

### 30. SoundEdit (`SDEV`/`FSSD`/`MACS`) → WAV — S, MED
Macromedia SoundEdit 16. Stored in resource fork. Decoder doable in <200 lines.

### 31. Standard MIDI File (.mid) preview & playback — M, MED
We don't preview MIDI files. We could either render to a WAV via macOS' built-in MIDI synth (`AVAudioEngine` + `AVAudioUnitMIDIInstrument`) or just show the track listing + tempo + instrument map.

### 32. Performer / Digital Performer (`PERF`/`DPS5`) — L, LOW
MOTU's professional sequencer. Closed format. Only summary extraction realistic (track count, tempo, length).

### 33. Cubase Mac (`Cubs`) song file — L, LOW
Steinberg Cubase. Mac users had VST 1.0 here. Format closed but partial reverse engineering exists.

### 34. AIFC compressed AIFF — XS, MED
We treat AIFF as supported but AIFC variants (MACE 3:1, MACE 6:1, μ-law, A-law) need decompression. Apple's AudioToolbox can handle this directly — just need to wire it up for export.

### 35. snd resource → SoundFont (.sf2) export — M, LOW
For people rebuilding old Mac game soundtracks. Bundles all `snd ` resources from a vault into a single SoundFont file with proper key mapping.

---

## Category 5 — Animation, Multimedia & Video (5 features)

### 36. PICS animation (`PICS`) → animated GIF/MP4 — M, MED
The classic Mac animation format: a sequence of PICTs in a single file. Used by Macromedia Director, HyperCard, MacroMind for animations. Format is trivial (PICT chain) — converter is small.

### 37. Macromedia Director (`MV93`/`MV97`) — XL, **HIGH**
Director was THE multimedia authoring tool 1990-2005 (Lingo, Shockwave). Closed binary format. The [`prj-converter`](https://github.com/n0samu/director-files-extract) project decodes some versions. This would unlock a massive cultural archive.

### 38. HyperStudio (`STK2`) — M, MED
Roger Wagner Publishing. The "HyperCard for kids" — used in millions of school projects.

### 39. mTropolis project files — XL, LOW
mFactory's HyperCard competitor. Tiny user base, closed format. Probably out of scope.

### 40. FLI / FLC (Autodesk Animator) — S, LOW
Used in Mac ports of Autodesk Animator. Format is well-documented, decoder is small. Could output to GIF.

---

## Category 6 — Code, Development & Executables (6 features)

### 41. PEF (Preferred Executable Format) PowerPC inspector — M, MED
PEF is the format used for PowerPC Mac apps (1994-2005). Header parser would show: code section size, data section size, imported libraries, exported symbols, version info. Helps identify whether an app is PPC, Carbon, or Classic.

### 42. CFM-68K binary inspector — S, LOW
Code Fragment Manager binaries for 68K. Older relative of PEF.

### 43. Mach-O fat binary inspector — S, MED
Modern macOS apps with PPC/i386/x86_64 slices. Shows architectures present and code-signing status. Useful when restoring early Mac OS X apps.

### 44. ResEdit TMPL → editable resource form — L, MED
ResEdit could load `TMPL` resources and use them to display ANY unknown resource as a form. This is the "killer feature" of ResEdit. We currently show known resources only; TMPL parsing would let us display arbitrary user-defined resources structurally.

### 45. CodeWarrior project (`MMPr`) → JSON — M, LOW
Metrowerks CodeWarrior project file. Lists source files, build settings, target. Useful for archaeology of Mac game/app development.

### 46. THINK C/Pascal project (`.π` files) — S, LOW
Symantec THINK C and THINK Pascal used π files (yes, the Greek letter) as project files. Custom binary, partially documented in old THINK manuals.

---

## Category 7 — Disk Images, Cross-Platform & Misc (4 features)

### 47. ShrinkWrap (`.smi`) — S, MED
Aladdin's self-mounting disk image format. A `.smi` is essentially a Mac executable that mounts a DiskCopy 4.2 image embedded in its data fork. Common in 1995-2000 era downloads. Need to extract the embedded image.

### 48. Atari ST disk images (`.st`/`.msa`/`.stx`) — M, LOW
Many Mac users had Atari ST emulators (STeem, Hatari) and shared disks. Same era, similar archive aesthetic. Format is simple (MSA is RLE). Native Swift, ~200 lines.

### 49. Commodore D64/D71/D81 — M, MED
C64/C128/C65 disk images. Mac users running Vice or Frodo. D64 format is fully documented. Native Swift parser feasible. Pairs well with our existing Apple II support.

### 50. Apple II `.po`/`.do`/`.dsk` deep auto-detection + sector swap — S, **HIGH**
We have basic sector-order detection but it can be wrong. Many Apple II images circulating online have the wrong extension. A heuristic that tries both orders, parses the catalog, and picks the one that succeeds — plus an optional swap-and-save action — would prevent endless user confusion. Native Swift, ~150 lines.

---

## Prioritization Matrix

Sorted by impact (high → low) and within tier by effort (smallest first).

### Tier 1 — High Impact (12 features)
*Build these first. Each unlocks a major chunk of cultural content that is currently lost.*

| # | Feature | Effort | Why |
|---|---------|--------|-----|
| 29 | Sound Designer II (.sd2) | S | Every Mac sample library |
| 50 | Apple II sector-order auto-fix | S | Stops endless user confusion |
| 1 | WriteNow text + style | M | #2 Mac word processor of the 80s |
| 13 | ClarisWorks SS → CSV | M | Schools, churches, small biz |
| 26 | Photoshop layer extraction | M | Industry standard, layered .psd |
| 2 | MacWrite II/Pro full | M | Completes our MacWrite story |
| 19 | MacDraw → SVG | L | Decades of plans/drawings |
| 22 | PageMaker text + layout | L | DTP archive king |
| 23 | QuarkXPress text + layout | L | DTP archive king #2 |
| 15 | HyperCard stack content | L | Cultural treasure |
| 11 | Excel BIFF → CSV | L | Schools, businesses |
| 3 | MS Word 4/5/5.1 → MD | L | The Word era we lose to Quick Look failures |

### Tier 2 — Medium Impact (18 features)
*Build after Tier 1 is solid. Each closes a meaningful niche.*

8, 9, 10, 12, 14, 16, 20, 21, 25, 28, 30, 31, 34, 36, 37, 38, 41, 47

### Tier 3 — Low Impact / Nice-to-Have (12 features)
*Build if a user asks or if we find a champion contributor.*

5, 6, 7, 18, 27, 32, 33, 35, 40, 42, 43, 45, 46, 48, 49

### Tier 4 — Out of Scope (likely v3 or never)
*Closed formats with tiny user bases or no documentation.*

17 (4D), 24 (FreeHand — needs full libfreehand port), 39 (mTropolis), 4 (Works Mac — would need huge effort for unclear gain), 44 (TMPL editor — overlaps with ResEdit which still works in emulation)

---

## Effort Summary

| Effort | Count | Total dev time (rough) |
|--------|-------|------------------------|
| XS (<1 day) | 2 | ~1 day |
| S (1-2 days) | 14 | ~3 weeks |
| M (3-5 days) | 18 | ~12 weeks |
| L (1-2 weeks) | 13 | ~20 weeks |
| XL (>2 weeks) | 3 | ~10 weeks |
| **TOTAL** | **50** | **~46 weeks of one-developer effort** |

If we picked only Tier 1 (12 high-impact features), that's roughly **15-18 weeks** of focused work and would more than double the actual cultural value RetroRescue delivers.

---

## Implementation Strategy Recommendations

### Pattern A — Native Swift parser
Best for documented formats with stable specs: WriteNow, MacDraw, Sound Designer II, HyperCard, PICS, Sector-order detection, Apple II / Atari ST / C64 disk images, MIDI, AIFC.

### Pattern B — Port from C library
For complex formats where someone has already done the reverse engineering: WordPerfect (libwpd), Lotus 1-2-3 (libwks), Photoshop (libpsd), QuarkXPress (libqxp), FreeHand (libfreehand). Either port to Swift or shell out via a small bridge tool.

### Pattern C — Shell out via subprocess
Pragmatic for one-off conversions: Office binary formats via LibreOffice headless mode (`soffice --headless --convert-to`), Director files via the prj-converter Python tool. Slow but works.

### Pattern D — System framework
For audio: AudioToolbox handles AIFC, Sound Designer II via AVAudioFile, MIDI playback via AVAudioEngine. Already on every Mac, zero added size.

### Pattern E — JSON sidecar instead of full conversion
For complex formats where we can't realistically reproduce the visual fidelity: dump everything we CAN extract (text, image refs, structure) to a JSON file alongside the original. Even partial extraction is better than zero.

---

## What This Doesn't Cover

This analysis intentionally excludes:
- **Apple II software niche formats** beyond what we already have (DOS 3.3, ProDOS, Pascal, CP/M) — there are hundreds but our existing 9 readers cover ~95% of what circulates
- **Pre-Mac Apple formats** (Lisa Office System docs, Apple /// SOS) — extreme niche
- **NeXT-related formats** (.nib, NeXTstep bundles) — different platform, deserves its own tool
- **iOS/modern macOS formats** — RetroRescue is for *classic* Mac
- **Game-specific formats** (Marathon maps, Bungie ABK, etc.) — there are too many; better as standalone preservation projects (see retro-ideas.md)

---

## References

- [CiderPress2 source](https://github.com/fadden/ciderpress2) — Apple II side, many disk image format notes
- [The Unarchiver / unar source](https://github.com/MacPaw/XADMaster) — Mac archive format ground truth
- [LibreOffice import filters](https://git.libreoffice.org/core/+/master/writerperfect/) — wpd, qxp, freehand, cdr, mwaw, abw
- [Format Specs collection](https://www.fileformat.info/format/) — general reference
- [Mac GUI / Mac Garden](https://macgui.com/) — file format wiki contributions
- [HyperCard Stack Format Spec](http://www.kreativekorp.com/miscpages/hcstackformat.html) — Kelvin Sherlock
- Andy McFadden's CiderPress notes (DiskCopy, DART, MFS, HFS, APM)
