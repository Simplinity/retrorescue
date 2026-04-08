# RetroRescue v2 — Planning & Decisions

> Beslissingen en notities voor features die naar v2 zijn geschoven.

## Q11: ffmpeg — Optionele Download

**Beslissing**: ffmpeg wordt NIET gebundeld in de app (~80 MB zou de app-grootte verdriedubbelen). In plaats daarvan:

1. Bij eerste gebruik van video-conversie (J8) → prompt: "ffmpeg is nodig voor QuickTime → MP4 conversie. Wil je het downloaden? (~80 MB)"
2. Download naar `~/Library/Application Support/RetroRescue/tools/ffmpeg`
3. ToolChain checkt die locatie automatisch
4. Gebruikers die al ffmpeg via Homebrew hebben → die wordt automatisch gevonden

**Reden**: <5% van gebruikers heeft video-conversie nodig. LGPL/GPL licentie-complicaties bij bundelen. Homebrew-gebruikers hebben het vaak al.

## Q10: Native Swift HFS Reader

**Beslissing**: v2 — port van CiderPress2 HFS*.cs (~5,000 regels C#) naar Swift. Vervangt hfsutils dependency (hmount/hls/hcopy/humount/hformat).

**Impact**: snellere extractie (geen process spawning), betere metadata, write support mogelijk.

## E2: Native HFS Reader + E3: HFS Write

Gekoppeld aan Q10. Zodra de native HFS reader werkt:
- E2: directe HFS file extractie zonder hfsutils
- E3: HFS volumes aanmaken/wijzigen in pure Swift (vervangt hformat+hcopy)

## E6: HFS+ Read

**Beslissing**: v2 — macOS kan HFS+ natively mounten, dus lage prioriteit. Implementeer als hdiutil-bridge of native parser.

## D5: DiskCopy 4.2 Write

**Beslissing**: v2 — nodig voor perfecte floppy image reproductie. Rotate-and-add checksum + tag data + 84-byte header schrijven.

## O6: App Store

**Beslissing**: v2 — vereist volledige sandbox compliance. Veel features (bundled tools, process spawning, xattr schrijven) werken niet in sandbox. Zou een beperkte "Lite" versie worden.

## P1-P8: Advanced Features

Alle naar v2:
- P1: Vault merge (deduplicate by SHA-256)
- P2: Vault diff (vergelijk twee vaults)
- P3: Collection statistics dashboard
- P4: Catalog export (static HTML site)
- P5: Cross-vault duplicate detection
- P6: Provenance graph
- P7: Batch import from folder
- P8: RetroGate URL scheme integration

## J7-J10: Document Converters (verbeteren)

v1 heeft basic text extractie voor ClarisWorks en MacWrite. v2 voegt toe:
- J7: FONT/NFNT → TTF (niet alleen BDF)
- J9: ClarisWorks volledige opmaak → DOCX (vereist binary format reverse engineering)
- J10: MacWrite volledige opmaak → RTF
