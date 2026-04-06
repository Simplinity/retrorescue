# Retro Computing Project Ideas

> All projects in the spirit of **RetroGate**: focused tools for retro computing enthusiasts, each buildable in a few days.

---

## 1. DiskJockey

Disk image browser. Mount and browse `.dsk`, `.img`, `.smi`, `.toast`, `.iso` files visually on your modern Mac. See the contents as a classic Mac OS Finder window with the correct icons. Extract files with resource fork preservation.

## 2. ResEdit Reborn

A modern macOS app that lets you browse and edit classic Mac resource forks (PICT, ICON, snd, STR#, MENU). Point it at a classic app or disk image, explore its resources visually. The nostalgia factor alone is worth it.

## 3. AbandonFinder

A search engine for abandonware. Indexes Macintosh Garden, Macintosh Repository, Internet Archive, old FTP mirrors. Search by year, category, System version compatibility, and "vibes."

## 4. AirTalk

LocalTalk-over-WiFi bridge. A small daemon that lets your real vintage Mac (with a LocalTalk adapter) communicate with emulated Macs and modern Macs over your WiFi network. File sharing across eras.

## 5. PrintShop

A print server that accepts jobs from vintage Macs (LaserWriter protocol / PAP) and routes them to modern AirPrint/USB/network printers. Your Mac Plus can finally print again.

## 6. TerminalTypewriter

Turns a real vintage Mac (or emulator) into a distraction-free writing machine. A tiny server app that provides a full-screen text editor via Telnet — write your novel on a Mac Plus, sync to iCloud.

## 7. TimeCapsule.fm

Internet radio that only plays what was on the radio in a given year. Pick 1984, hear what was charting. Integrates with Wayback + music databases. The audio companion to RetroGate's Wayback mode.

## 8. FloppyCopy

A modern Mac app that reads/writes real 3.5" floppy disks via USB floppy drives (Greaseweazle, KryoFlux, or standard USB drives). Handles HFS, MFS, ProDOS, FAT, and creates verified disk images.

## 9. StuffItOpen

A modern decompression tool that handles every classic Mac archive format: `.sit`, `.sea`, `.hqx`, `.bin`, `.cpt`, `.dd`, `.pit`, `.arc`. Preserves resource forks. Because StuffIt Expander for macOS is long dead.

## 10. ScreenMirror

Stream your vintage Mac's screen to your modern Mac in real time over the network. Record sessions, take screenshots, share your retro computing on Twitch without a capture card.

## 11. FingerDaemon

Revive the finger protocol. Run a finger server on your Mac, let people `finger bruno@yourdomain.com` to see your current status, `.plan` file, and what vintage Mac you're currently tinkering with.

## 12. IconExtractor

Pull every icon from classic Mac apps and system files. Browse the gorgeous hand-pixeled 32×32 icons from Susan Kare and the OS 8/9 era. Export as ICO, PNG, SVG upscales.

## 13. MacBinSplit

A fast, drag-and-drop tool that handles MacBinary, BinHex, and AppleSingle/AppleDouble encoding and decoding. Convert between formats, inspect headers, extract data+resource forks separately. The missing Rosetta Stone for classic Mac file transfer.

## 14. HFSExplorer+

Read-only HFS and HFS+ volume browser that runs natively on Apple Silicon. Opens disk images, partitions, and raw block devices. Shows the real resource/data fork structure, Finder metadata, desktop database entries, and file type/creator codes.

## 15. ForkLift68k

Dual-pane file manager that speaks AppleShare/AFP to vintage Macs on one side and modern APFS/SMB on the other. Drag files between eras with automatic MacBinary wrapping, resource fork preservation, and text encoding conversion.

## 16. PICTView

A modern viewer for PICT, PICT2, and MacPaint files. Drag and drop, batch convert to PNG/SVG, inspect QuickDraw opcodes. Because Preview dropped PICT support years ago and thousands of classic Mac graphics are locked in this format.

## 17. AFPBridge

A bridge daemon that translates between modern SMB3 file shares and Apple Filing Protocol (AFP). Your Mac OS 9 machine sees your NAS. Your NAS doesn't need to support AFP. Handles the auth, encoding, and resource fork negotiation.

## 18. MacIPGateway

MacIP gateway that routes AppleTalk-over-IP traffic between real vintage Macs and the internet. Your Mac SE with MacTCP and an Ethernet card can reach the real internet through your modern Mac acting as a NAT gateway.

## 19. DiskCopy42

Faithful recreation of Apple's Disk Copy 4.2 functionality on modern macOS. Create, verify, and mount classic 400K/800K/1.4MB disk images in DiskCopy 4.2 format (`.img` with checksums). The original is Classic-only and Disk Utility doesn't fully handle these.

## 20. FontForge68k

Convert classic Mac bitmap fonts (FONT, NFNT, FOND resources) to modern TrueType/OpenType fonts. Preserve the exact pixel grid at specific sizes while generating smooth outlines for arbitrary scaling. Chicago 12 as a real `.ttf`.

## 21. DialTone

A modem AT-command emulator that runs over TCP. Your vintage Mac's comm software thinks it's connected to a real modem, but it's actually tunneling through your modern Mac's network. `ATDT` becomes a TCP connect. Full Hayes compatibility.

## 22. Claris2Modern

Converts ClarisWorks and AppleWorks documents to modern formats. Word processing → Markdown/DOCX, spreadsheets → CSV/XLSX, drawings → SVG, databases → SQLite/CSV. Rescue your 1990s homework.

## 23. EmailGateway

SMTP/POP3 proxy that lets vintage Mac email clients (Eudora, Claris Emailer, Outlook Express 5) connect to modern email providers. Handles TLS, OAuth2 tokens, and translates modern MIME to something Eudora understands.

## 24. NetBootServer

Boot a vintage Mac from the network using your modern Mac as a NetBoot/BOOTP server. Serve System 7 or Mac OS 9 boot images. No hard drive needed on the vintage machine — perfect for diskless setups or testing.

## 25. FTPDClassic

A dead-simple FTP server that speaks FTP exactly the way vintage Mac FTP clients (Fetch, Anarchie, Transit) expect. No TLS complications, passive mode tuned for old clients, MacBinary mode support. Drop files into a folder, they appear in Fetch.

## 26. PanicScreen

A screensaver that cycles through classic Mac error screens: Sad Mac codes, bomb dialogs (with different ID numbers), "The application has unexpectedly quit," and the gray screen of death. Each with accurate fonts and rendering.

## 27. MacWriteConvert

Batch converter for MacWrite, MacWrite II, and MacWrite Pro documents to Markdown, RTF, or HTML. Preserves formatting, inline images, and footnotes. Unlock decades of trapped documents.

## 28. DNSMasqRetro

A preconfigured DNS + DHCP server that makes setting up a vintage Mac network trivial. Boot it on your modern Mac, and it hands out IP addresses, resolves hostnames, and even injects a PAC file for automatic RetroGate proxy configuration. Zero-config retro networking.

## 29. InstallerValet

A manager for classic Mac Installer VISE and Apple Installer packages. Opens `.smi`, `.pkg`, and Installer VISE archives, shows what they would install (files, extensions, control panels), extracts contents without actually running them.

## 30. BinhexCLI

A fast, modern command-line tool for encoding/decoding BinHex 4.0 files. Pipe-friendly, handles batch operations, preserves all metadata. Perfect for scripting and automation in retro software archives.

## 31. QuickTimeArchive

Scans your collection for QuickTime movies in obsolete codecs (Cinepak, Sorenson 1, Intel Indeo, QTVR) and transcodes them to H.264/H.265 while preserving the originals. Saves VR panoramas as interactive web pages.

## 32. PrintSpooler

Captures PostScript output from vintage Macs and saves it as PDF on your modern Mac. Every print job becomes a perfectly rendered PDF archive. Print your ClarisWorks document to "PDF" from Mac OS 9.

## 33. CompactProOpen

Open and extract Compact Pro (`.cpt`) archives. This was the #2 Mac compression format after StuffIt, and nothing modern reads it. Also handles DiskDoubler (`.dd`) files.
