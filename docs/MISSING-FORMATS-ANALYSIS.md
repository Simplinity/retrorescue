# RetroRescue — Missing Formats Analysis

> Analysis of 50 features (formats, parsers, converters, viewers) that RetroRescue
> should ideally support but does not yet. Compiled April 10, 2026, after a full
> audit of the 178 existing features.
>
> **Legend:**
> - **Priority**: 🔴 critical (encountered in real vaults often) · 🟡 important (common) · 🟢 nice-to-have (rare/historical)
> - **Effort**: S = small (≤1 day) · M = medium (~1 week) · L = large (multiple weeks) · XL = research project
> - **Approach**: 🦉 native Swift · 📦 external library · 🛠 wrap CLI tool · 🔬 reverse-engineer

---

## Current coverage (baseline)

We currently support **178 features** spread across 19 sections. Strong coverage in:
archive extraction (22 formats), encoding wrappers (4), disk images (15), filesystems
(9 native + HFS via tools), partitions (7), resource fork rendering (19 type renderers,
50+ types in registry), font preview (7 formats via CoreText), basic conversion
(PICT/MacPaint→PNG, snd→WAV, ClarisWorks/MacWrite text-only).

The gaps below are organized by category in roughly the order I'd recommend tackling them.

---

## Category 1 — Word Processors & Text Documents (10 features)

These are the highest-impact missing features. Vaults from any office worker or writer in
the 1985-2000 era will be full of these, and we currently extract zero usable content from
most of them.

### 1. WriteNow (`nX^n` / type `nX^n`) 🔴 priority · M effort · 🦉 native

T/Maker's WriteNow was bundled with the Mac Plus and was the most popular Mac word
processor between 1986 and 1990 before Word took over. The format is documented in the
Stanford CS files and there are existing converters (writenow2rtf). Fork-based: text in
data fork with style runs in resource fork (`STYL` resources). Native parser is feasible
in ~500 lines. **Convert to Markdown or RTF.**

### 2. MacWrite II / MacWrite Pro (`MWPd` / `MWPr`) 🔴 priority · M effort · 🦉 native

Our current MacWrite extractor only handles MacWrite 1.x text extraction. MacWrite II
(1989) and MacWrite Pro (1993) used a completely different format with paragraph styles,
rulers, headers/footers, and embedded graphics. Format is documented in old Claris
developer notes. **Convert to Markdown with style preservation.**

### 3. Microsoft Word 4/5/5.1/6/98 binary (`WDBN` / `W6BN` / `W8BN`) 🔴 priority · L effort · 📦 library

Word 5.1a (1992) was the legendary "perfect" Mac Word and is still used by retro
enthusiasts today. The pre-Word 97 binary format (`.doc`) is documented in MS-DOC and
there are libraries (libwpd's wpd2rtf-style, antiword for older docs). **Wrap antiword
or use LibreOffice's writerperfect for headless conversion to RTF.**

### 4. Microsoft Works Mac (`AWWP` / `AWDB` / `AWSS`) 🟡 priority · M effort · 🔬 reverse

Microsoft Works for Mac (1986-2000) was the budget alternative to Office. Used in
schools and homes everywhere. Multi-document format (word processor + spreadsheet +
database + draw). Format partially documented by libwps. **Try wrapping libwps via
homebrew, fall back to text-only extraction.**

### 5. WordPerfect Mac (`WPC2` / `WPD2` / `WPD3`) 🟡 priority · M effort · 📦 library

WordPerfect Mac (1988-1997) had a strong corporate following. Format is documented and
libwpd handles it well. **Wrap libwpd CLI tool (wpd2html or wpd2text) via homebrew.**

### 6. Nisus Writer Classic (`NSCT` / `NisU` / `NIS!`) 🟡 priority · M effort · 🦉 native

Nisus Writer (1989-2003) was the Mac power-user word processor — full multilingual
support, regex find/replace, true non-contiguous selection. Format is RTF-derived but
with custom resource fork extensions for the Nisus-specific features. **Extract text
+ basic formatting via the data fork RTF stream.**

### 7. FullWrite Professional (`FWRT` / `FWRP`) 🟢 priority · M effort · 🔬 reverse

Ann Arbor Softworks' FullWrite (1988-1995, later acquired by Akimbo Systems) was the
"thinking writer's" word processor — outline view, footnotes, change tracking. Smaller
user base. Format never publicly documented. **Best-effort text extraction via heuristic
scanning of the data fork.**

### 8. RagTime (`RTd1` / `RTSt`) 🟢 priority · L effort · 🔬 reverse

German DTP/spreadsheet hybrid (1986-2007). Used in European publishing for technical
documents. Format is proprietary and complex (frame-based layout). **Best-effort text
extraction only; full conversion is not feasible without RagTime SDK access.**

### 9. Ready,Set,Go! (`MMPP` / `RSGD`) 🟢 priority · M effort · 🔬 reverse

Letraset's Ready,Set,Go! (1985-1996) was the first Mac DTP application, predating
PageMaker. Used by indie publishers and schools. Frame-based like PageMaker. **Best-effort
text extraction; proper conversion requires hand-decoding the frame format.**

### 10. PageMaker / QuarkXPress text extraction (`ALB3-6` / `XDOC`) 🟡 priority · M effort · 🔬 reverse

We currently identify these but don't extract content. Both formats store text streams
in identifiable chunks within the data fork. We don't need full layout reconstruction —
extracting the article text in reading order is sufficient for archival purposes.
**Heuristic text-chunk extraction → plain text or Markdown.**

---

## Category 2 — Databases & Spreadsheets (6 features)

### 11. HyperCard stack content (`STAK` / `WILD`) 🔴 priority · L effort · 🦉 native

We identify HyperCard stacks but extract zero content. HyperCard (1987-2004) was Bill
Atkinson's revolutionary multimedia authoring system — every Mac shipped with it for years.
Stacks contain cards (with text fields, buttons, paint layers), backgrounds, scripts
(HyperTalk), sounds, and pictures. The format is well-documented in *HyperCard Stack
Design Guidelines* and there's a reference implementation in **stackimport** (Python).
This is **the** most culturally significant Mac format we don't yet handle. **Native
parser for cards, fields, scripts, and embedded resources; render as HTML or Markdown.**

### 12. FileMaker Pro classic (`FMP3` / `FMP5` / `FMPR`) 🟡 priority · L effort · 📦 library

FileMaker Pro 3-6 (1995-2003) was the dominant Mac database. Format is proprietary
but partially reverse-engineered by **HyperFileSQL** and the Python `fp7-tools`. Modern
FileMaker (.fmp12) is yet another format. **Wrap an external converter or extract
schema + first-N records via reverse-engineered parser.**

### 13. 4D database (`4DBM`) 🟢 priority · L effort · 🔬 reverse

ACI's 4D was a powerful Mac database with its own programming language. Proprietary
format never publicly documented. **Detection + metadata only; no content extraction
without 4D itself.**

### 14. Microsoft Excel 4/5/98 binary (`XLS5` / `XLS8`) 🔴 priority · L effort · 📦 library

Excel 4 (1992) through Excel 98 used the BIFF binary format (different from modern .xlsx).
Well-documented in MS-XLS spec, supported by **xlrd** (Python) and **libxls** (C).
**Wrap libxls via homebrew to extract sheets to CSV.**

### 15. Lotus 1-2-3 Mac (`L123`) 🟢 priority · M effort · 📦 library

Lotus 1-2-3 had a Mac version (1991-1997) that briefly competed with Excel. WK1/WK3/WK4
formats are documented and supported by **gnumeric**. **Wrap ssconvert (gnumeric CLI)
to extract to CSV.**

### 16. ClarisWorks/AppleWorks spreadsheet & database (`CWSS` / `CWDB`) 🟡 priority · M effort · 🦉 native

We currently extract ClarisWorks word processor documents as Markdown (text only).
ClarisWorks/AppleWorks 1-6 also had spreadsheet, database, draw, and paint modules.
The container format is documented (libwps handles it). **Extend our existing
ClarisWorks parser to handle CWSS (→CSV) and CWDB (→CSV with field metadata).**

---

## Category 3 — Graphics, Vector Art & DTP (8 features)

We handle PICT and MacPaint (raster) but no vector formats at all. Vector art is a major
gap because vintage Mac graphics work was overwhelmingly vector-based.

### 17. MacDraw / MacDraw II / MacDraw Pro (`DRWG` / `MDPL` / `MDRW`) 🔴 priority · L effort · 🦉 native

Apple's MacDraw (1984-1998) was *the* Mac vector drawing application — bundled with the
original Mac, then sold by Claris. Format is documented in *Inside Macintosh* and
*Mac Draw File Format* technote. Object-based: rectangles, ovals, polygons, bezier
curves, text blocks, groups. **Native parser → SVG. This single feature would unlock
millions of vintage Mac drawings.**

### 18. SuperPaint (`SPNT` / `SPTG`) 🟡 priority · M effort · 🔬 reverse

Silicon Beach Software's SuperPaint (1986-1996) was the killer "paint + draw" hybrid —
combined raster and vector layers in one document. Format partially documented. **Best-
effort: extract paint layer as PNG, draw layer to SVG.**

### 19. Canvas (`CV15` / `CV35` / `cVPj`) 🟡 priority · L effort · 🔬 reverse

Deneba's Canvas (1987-2010) was the pro-level vector tool — competed with Illustrator
and FreeHand. Many technical illustrations from the 1990s exist in this format.
Proprietary format, never publicly documented. **Hand-decode the object stream;
output to SVG or PDF.**

### 20. FreeHand v3-v11 (`FHD3` - `FHA1`) 🔴 priority · L effort · 📦 library

Aldus → Macromedia → Adobe FreeHand (1988-2003) was the dominant Mac vector tool
alongside Illustrator. Killed by Adobe in 2007. Format has multiple versions
(FH3-FH11). **uniconvertor** (Linux) handles the older versions. **Wrap uniconvertor
or hand-port its FH parser → SVG.**

### 21. Adobe Illustrator classic (`ART3` / `ART5`) 🟡 priority · M effort · 📦 library

Pre-Illustrator 9, AI files were essentially structured PostScript (EPS-derived).
Modern AI files (CS+) are PDF-derived. Both can be handled by **Ghostscript** (gs)
or **Inkscape** in CLI mode. **Wrap gs/inkscape to convert to SVG/PDF.**

### 22. PixelPaint / Studio/8 / Studio/32 (`PIXP` / `STDF`) 🟢 priority · M effort · 🔬 reverse

SuperMac's PixelPaint (1988) was the first 8-bit color Mac paint program; Studio/8
and Studio/32 followed. Used for early color illustration. Format proprietary.
**Extract raster bitmap from data fork → PNG.**

### 23. ClarisCAD (`CCAD` / `CADD`) 🟢 priority · L effort · 🔬 reverse

Claris CAD (1988-1996) was a 2D drafting program. Used by architects and engineers.
Format proprietary. **Detection + metadata only initially; optional later: hand-decode
object stream to DXF.**

### 24. PostScript & EPS proper rendering (`EPSF` / `TEXT` with %!PS) 🔴 priority · S effort · 🛠 wrap CLI

We currently treat EPS as "Encapsulated PostScript" but don't render it. macOS has
**ghostscript** available via brew, and `sips` can also handle EPS in many cases.
**Wrap gs to render EPS → PNG/PDF for preview and conversion.**

---

## Category 4 — Audio & Music (6 features)

We render `snd ` resources as WAV but have no support for any standalone audio editing
formats from the classic Mac era.

### 25. Sound Designer II (`Sd2f`) 🔴 priority · M effort · 🦉 native

Digidesign's Sound Designer II (1985-2000) was *the* Mac audio file format used
throughout the music industry — every Mac recording from the 90s. Lives in the data fork
as raw PCM samples (16-bit, 44.1kHz typically) with metadata in the resource fork
(`STR ` for sample rate, region markers, loop points). **Native parser → AIFF or WAV.**

### 26. SoundEdit / SoundEdit Pro / SoundEdit 16 (`MACS` / `SFIL` / `jB1 `) 🟡 priority · M effort · 🔬 reverse

Macromedia's SoundEdit (1986-2004) was the consumer audio editor. Multi-track in later
versions. Format proprietary but partially documented in dev notes. **Extract first
audio track as AIFF.**

### 27. Standard MIDI Files (.mid / type `Midi`) 🟡 priority · S effort · 🦉 native

We don't preview MIDI files at all. SMF format is fully documented and trivial to parse.
Could render a piano-roll preview image and play via macOS `MIDIDriver`. **Native parser
+ piano roll PNG renderer + AVMIDIPlayer playback button.**

### 28. Performer / Digital Performer sequences (`PERF` / `MOUP`) 🟢 priority · L effort · 🔬 reverse

MOTU's Performer (1985-) and Digital Performer were the dominant Mac MIDI sequencers.
Proprietary format. **Best-effort: detect + extract embedded MIDI tracks if possible.**

### 29. Cubase Mac song files (`CUBA` / `Cubs`) 🟢 priority · L effort · 🔬 reverse

Steinberg Cubase had Mac versions throughout the classic era. Proprietary VST-era
format. **Detection + metadata only.**

### 30. Audio MOD / S3M / XM / IT tracker files 🟢 priority · S effort · 📦 library

The Mac demoscene used Amiga-style tracker formats heavily. These are well-supported
by **libopenmpt** (homebrew). **Wrap libopenmpt to render waveform + play via the
existing audio infrastructure.**

---

## Category 5 — Multimedia & Animation (5 features)

### 31. PICS animation files (`PICS`) 🟡 priority · S effort · 🦉 native

PICS (1985-) is just a sequence of PICT pictures concatenated with a simple header.
Trivial to parse. Used for early Mac animations before QuickTime. **Native parser →
animated GIF or APNG output.**

### 32. Macromedia Director (`MV93` / `MV97` / `MD93`) 🔴 priority · XL effort · 🔬 reverse

Director (1987-2017) was *the* Mac multimedia authoring tool. Used to create vast
amounts of CD-ROM content in the 90s — encyclopedias, games, edutainment. Proprietary
format with embedded scripts (Lingo), images, sounds, video. There's a partial reverse-
engineering effort (**OpenShockwave**) but full conversion is a research project.
**Stage 1: detect + extract embedded media (PICTs, sounds). Stage 2: optional Lingo
script extraction.**

### 33. SuperCard (`STAK` analog / `SCRZ`) 🟡 priority · L effort · 🔬 reverse

SuperCard was a HyperCard alternative with color, true windows, and PowerPC support.
Used for serious Mac applications throughout the 90s. Format is HyperCard-derived but
extended. **Once HyperCard support exists (#11), extend the same parser for SuperCard.**

### 34. mTropolis (`MTRP` / `mTrp`) 🟢 priority · XL effort · 🔬 reverse

mFactory's mTropolis (1995-1999) was a high-end multimedia authoring tool that competed
with Director. Used for some major CD-ROMs (Obsidian, The Dark Eye). Format is being
slowly reverse-engineered by the **ScummVM** project. **Best to wait for ScummVM
support and integrate from there.**

### 35. HyperStudio stack (`HSTK` / `HCRD`) 🟡 priority · L effort · 🔬 reverse

Roger Wagner's HyperStudio (1989-2015) was the educational HyperCard alternative used
in K-12 schools everywhere. Color, sound, video, simple animations. Format proprietary.
**Best-effort: extract embedded media + text content; render cards as static HTML.**

---

## Category 6 — Code, Development & Executables (6 features)

We identify code resources but don't extract usable information from them. For
preservation purposes, being able to inspect 68K and PowerPC binaries is valuable.

### 36. CODE 68K disassembly (`CODE` resources) 🟡 priority · L effort · 🦉 native

We list `CODE` resources but show them as opaque hex. A real 68K disassembler (like
Capstone's M68K module) could turn these into readable assembly. **Wrap Capstone via
Swift bindings or call out to a CLI tool. Show entry points + jump table.**

### 37. PEF (Preferred Executable Format) PowerPC binaries 🟡 priority · M effort · 🦉 native

PowerPC Macs (1994-2006) used PEF for executables and shared libraries. Format is
documented in *Mac OS Runtime Architectures*. Header gives section sizes, imports,
exports. **Native parser → display sections + imported libraries + exported symbols.**

### 38. CFM-68K binaries (`cfrg` resource for fragments) 🟢 priority · M effort · 🦉 native

The Code Fragment Manager existed briefly for 68K too (System 7.1.2+). Used for
shared libraries. Same general format as PEF but in `cfrg` resource. **Extension of
the PEF parser.**

### 39. Mach-O classic Mac binaries 🟢 priority · S effort · 🛠 wrap CLI

Late classic and early OS X Mac binaries used Mach-O. macOS has `otool` and `nm`
built in. **Wrap otool to display sections, libraries, symbols for Mach-O files in
the vault.**

### 40. CodeWarrior project files (`MMPr` / `MMPP`) 🟡 priority · M effort · 🔬 reverse

Metrowerks CodeWarrior (1994-2005) was the dominant Mac development environment in
the 90s. Project files contain target settings, file lists, build configurations.
Format proprietary but partially understood (some old Metrowerks dev notes leaked).
**Extract file list + target names → human-readable project summary.**

### 41. ResEdit TMPL-driven resource decoding 🔴 priority · M effort · 🦉 native

We render 19 known resource types (ICON, snd, MENU etc.) but classic Mac apps had
hundreds of custom resource types. ResEdit used `TMPL` resources to describe how to
display ANY resource type — basically a binary format DSL. **Native TMPL parser +
generic field renderer. This single feature would unlock thousands of "unknown"
resource types automatically.**

---

## Category 7 — Disk Image & Storage Gaps (5 features)

### 42. ShrinkWrap (.smi / `smIm`) 🟡 priority · M effort · 🔬 reverse

Aladdin Systems' ShrinkWrap (1995-1998) created compressed self-mounting disk images.
Format is StuffIt-derived but with a self-mounting wrapper. macOS dropped support
years ago. **Detect the SIT wrapper, decompress with our existing unar pipeline,
recover the inner disk image.**

### 43. Disk Doubler image format (`.dd` as image, not as archive) 🟢 priority · M effort · 🔬 reverse

DiskDoubler also produced compressed disk images (different from its file archives).
Same compression algorithms (DD1-DD3+). **Extension of our DiskDoubler archive support.**

### 44. ProDOS / DOS sector order detection improvements 🟡 priority · S effort · 🦉 native

We have basic sector order detection but it's not always reliable for `.po` (ProDOS-order)
vs `.do` (DOS-order) `.dsk` files. CiderPress2 has a robust algorithm using filesystem
heuristics. **Port CP2's `OrderHint` logic into our DiskImageParser.**

### 45. Atari ST disk images (.st / .msa / .stx) 🟢 priority · M effort · 🦉 native

Some Mac users had Atari ST emulators (Spectre GCR) and the disk image formats are
documented. .ST is raw, .MSA is Magic Shadow Archiver compressed, .STX is extended.
**Native parsers → wrap our existing FAT/Atari directory readers.**

### 46. Commodore disk images (.d64 / .d71 / .d81) 🟢 priority · M effort · 📦 library

Mac users in the 90s often had C64 emulators and copies of Commodore disks. Format
is well-documented and supported by **VICE** (the C64 emulator) tools and
**c1541** CLI. **Wrap c1541 to list + extract files from .d64.**

---

## Category 8 — System & Metadata Features (4 features)

### 47. Desktop Database parsing (Desktop DB / Desktop DF files) 🟡 priority · M effort · 🦉 native

Classic Mac volumes had a hidden Desktop Database (`Desktop`, `Desktop DB`, `Desktop DF`)
that mapped creator codes to applications and stored Get Info comments. Format is
documented in *Inside Macintosh: Files*. **Native parser to extract Get Info comments
and reconstruct the creator-code → application mapping for any HFS volume in the vault.**

### 48. AppleShare aliases (`alis` resource) 🟡 priority · M effort · 🦉 native

Mac aliases are stored as `alis` resources in the resource fork. Format is documented in
*Inside Macintosh: Files*. They contain the original path, volume name, file ID, parent
folder ID, plus relative path fallbacks. **Native parser → display alias target +
mark broken aliases. Useful for understanding what an old vault was structured around.**

### 49. Internet Config / IC preferences (`ICAp` / `ICRf`) 🟢 priority · S effort · 🦉 native

Internet Config (1994-2002) was the central Mac preferences database for Internet
settings — email accounts, helper apps, file mappings. Format is well-documented.
**Native parser → list email accounts (sanitized), bookmarks, file type associations.
Historical preservation value.**

### 50. Finder DS_Store / Get Info comments / Spotlight metadata 🟡 priority · M effort · 🦉 native

`.DS_Store` files (Mac OS 8.5+) contain folder view settings. Get Info comments live
in the resource fork's `STR ` resources or in the Desktop Database. Spotlight metadata
on later HFS+ volumes lives in extended attributes. **Native parser for `.DS_Store`
+ Get Info comment extraction across all entry types in the vault, displayed in the
Get Info panel.**

---

## Summary table

| # | Feature | Priority | Effort | Approach |
|---|---------|----------|--------|----------|
| 1 | WriteNow | 🔴 | M | 🦉 |
| 2 | MacWrite II / Pro | 🔴 | M | 🦉 |
| 3 | MS Word 4-98 binary | 🔴 | L | 📦 |
| 4 | MS Works Mac | 🟡 | M | 🔬 |
| 5 | WordPerfect Mac | 🟡 | M | 📦 |
| 6 | Nisus Writer Classic | 🟡 | M | 🦉 |
| 7 | FullWrite Professional | 🟢 | M | 🔬 |
| 8 | RagTime | 🟢 | L | 🔬 |
| 9 | Ready,Set,Go! | 🟢 | M | 🔬 |
| 10 | PageMaker / QuarkXPress text | 🟡 | M | 🔬 |
| 11 | HyperCard stack content | 🔴 | L | 🦉 |
| 12 | FileMaker Pro classic | 🟡 | L | 📦 |
| 13 | 4D database | 🟢 | L | 🔬 |
| 14 | MS Excel 4-98 binary | 🔴 | L | 📦 |
| 15 | Lotus 1-2-3 Mac | 🟢 | M | 📦 |
| 16 | ClarisWorks SS / DB | 🟡 | M | 🦉 |
| 17 | MacDraw / II / Pro | 🔴 | L | 🦉 |
| 18 | SuperPaint | 🟡 | M | 🔬 |
| 19 | Canvas | 🟡 | L | 🔬 |
| 20 | FreeHand v3-v11 | 🔴 | L | 📦 |
| 21 | Adobe Illustrator classic | 🟡 | M | 📦 |
| 22 | PixelPaint / Studio | 🟢 | M | 🔬 |
| 23 | ClarisCAD | 🟢 | L | 🔬 |
| 24 | PostScript / EPS proper | 🔴 | S | 🛠 |
| 25 | Sound Designer II | 🔴 | M | 🦉 |
| 26 | SoundEdit | 🟡 | M | 🔬 |
| 27 | MIDI files preview/playback | 🟡 | S | 🦉 |
| 28 | Performer / Digital Performer | 🟢 | L | 🔬 |
| 29 | Cubase Mac | 🟢 | L | 🔬 |
| 30 | MOD/S3M/XM/IT trackers | 🟢 | S | 📦 |
| 31 | PICS animations | 🟡 | S | 🦉 |
| 32 | Macromedia Director | 🔴 | XL | 🔬 |
| 33 | SuperCard | 🟡 | L | 🔬 |
| 34 | mTropolis | 🟢 | XL | 🔬 |
| 35 | HyperStudio | 🟡 | L | 🔬 |
| 36 | CODE 68K disassembly | 🟡 | L | 🦉 |
| 37 | PEF PowerPC binaries | 🟡 | M | 🦉 |
| 38 | CFM-68K binaries | 🟢 | M | 🦉 |
| 39 | Mach-O classic Mac | 🟢 | S | 🛠 |
| 40 | CodeWarrior projects | 🟡 | M | 🔬 |
| 41 | ResEdit TMPL parser | 🔴 | M | 🦉 |
| 42 | ShrinkWrap (.smi) | 🟡 | M | 🔬 |
| 43 | DiskDoubler image | 🟢 | M | 🔬 |
| 44 | Sector order detection (CP2 port) | 🟡 | S | 🦉 |
| 45 | Atari ST disk images | 🟢 | M | 🦉 |
| 46 | Commodore disk images | 🟢 | M | 📦 |
| 47 | Desktop Database parser | 🟡 | M | 🦉 |
| 48 | AppleShare aliases (`alis`) | 🟡 | M | 🦉 |
| 49 | Internet Config preferences | 🟢 | S | 🦉 |
| 50 | DS_Store / Get Info comments | 🟡 | M | 🦉 |


## Statistics

| Priority | Count | % |
|---|---|---|
| 🔴 Critical | 11 | 22% |
| 🟡 Important | 22 | 44% |
| 🟢 Nice-to-have | 17 | 34% |

| Effort | Count | % |
|---|---|---|
| S (≤1 day) | 7 | 14% |
| M (~1 week) | 24 | 48% |
| L (multi-week) | 16 | 32% |
| XL (research) | 3 | 6% |

| Approach | Count | % |
|---|---|---|
| 🦉 Native Swift | 21 | 42% |
| 🔬 Reverse-engineer | 19 | 38% |
| 📦 External library | 7 | 14% |
| 🛠 Wrap CLI tool | 3 | 6% |

## Recommended phasing

### Phase A — Critical formats with low/medium effort (≈4 weeks)

These give the biggest preservation value for the time invested. Pick these up first.

1. **#41 ResEdit TMPL parser** (M, 🦉) — multiplier feature: makes hundreds of unknown
   resource types automatically displayable.
2. **#24 PostScript/EPS proper rendering** (S, 🛠) — wrap ghostscript, instant win.
3. **#27 MIDI preview & playback** (S, 🦉) — small, high-impact, demoable.
4. **#11 HyperCard stack content** (L, 🦉) — culturally critical, well-documented.
5. **#1 WriteNow** (M, 🦉) — high real-world hit rate in 80s/early-90s vaults.
6. **#2 MacWrite II/Pro** (M, 🦉) — same era, same audience.
7. **#25 Sound Designer II** (M, 🦉) — every musician's vault has these.
8. **#17 MacDraw / II / Pro** (L, 🦉) — most-encountered vector format.

### Phase B — Important formats requiring external libraries (≈3 weeks)

1. **#3 MS Word 4-98 binary** (L, 📦) — wrap antiword/libwpd.
2. **#14 MS Excel 4-98 binary** (L, 📦) — wrap libxls.
3. **#5 WordPerfect Mac** (M, 📦) — wrap libwpd.
4. **#20 FreeHand** (L, 📦) — wrap uniconvertor.
5. **#21 Illustrator classic** (M, 📦) — wrap ghostscript/inkscape.

### Phase C — Native parsers for the long tail (≈4 weeks)

1. **#37 PEF PowerPC binaries** (M, 🦉)
2. **#44 Sector order detection port** (S, 🦉)
3. **#47 Desktop Database parser** (M, 🦉)
4. **#48 AppleShare aliases** (M, 🦉)
5. **#16 ClarisWorks SS/DB extension** (M, 🦉)
6. **#31 PICS animations** (S, 🦉)
7. **#49 Internet Config preferences** (S, 🦉)

### Phase D — Reverse-engineering projects (open-ended)

These need either community help, ScummVM-style efforts, or are nice-to-haves we can
defer indefinitely. **#32 Director, #34 mTropolis, #19 Canvas, #28-29 Performer/Cubase,
#33 SuperCard, #35 HyperStudio, #18 SuperPaint, #38 CFM-68K, #36 CODE disassembly,
#13 4D, #8 RagTime, #7 FullWrite, #9 Ready,Set,Go!**.

### Phase E — Vintage cross-platform (low priority)

**#45 Atari ST**, **#46 Commodore disk images**, **#30 MOD trackers**, **#42 ShrinkWrap**,
**#43 DiskDoubler image**, **#39 Mach-O classic**, **#23 ClarisCAD**, **#22 PixelPaint**,
**#40 CodeWarrior projects**, **#50 DS_Store/comments**, **#10 PageMaker/Quark text**,
**#4 MS Works**, **#6 Nisus**, **#12 FileMaker**, **#15 Lotus 1-2-3**, **#26 SoundEdit**.

## Total estimated effort

| Phase | Items | Effort |
|---|---|---|
| Phase A | 8 | ~4 weeks |
| Phase B | 5 | ~3 weeks |
| Phase C | 7 | ~4 weeks |
| Phase D | 13 | open-ended (could be months/years) |
| Phase E | 17 | ~2 weeks for the easy half, the rest deferred |

If we cap RetroRescue v2 at **Phases A+B+C** (20 features), that's roughly 11 weeks of
focused work and would bring us from 178 → 198 features, covering the most critical
historical formats. The remaining 30 items become v3 or community contributions.

## What this analysis is *not*

This is not a list of "broken" features — everything that already works keeps working.
This is a deliberate map of preservation gaps so we can prioritize honestly. The most
sobering observation: **HyperCard, MacDraw, Sound Designer II, and WriteNow are missing**.
Those four alone covered most of the creative output of the classic Mac era. Adding them
would change RetroRescue from "extracts the file" to "actually rescues the work."
