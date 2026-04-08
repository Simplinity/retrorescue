# RetroRescue — Release Checklist

## Before First Release

### ⚠️ Developer ID Certificate (REQUIRED for distribution)
- [ ] Log in to https://developer.apple.com
- [ ] Go to: Certificates, Identifiers & Profiles → Certificates
- [ ] Click "+" → choose "Developer ID Application"
- [ ] Generate CSR in Keychain Access (Certificate Assistant → Request a Certificate)
- [ ] Upload CSR, download certificate, double-click to install in Keychain

### ⚠️ Notarization Credentials (REQUIRED for Gatekeeper)
- [ ] Generate app-specific password at https://appleid.apple.com → Security
- [ ] Store credentials:
  ```bash
  xcrun notarytool store-credentials "RetroRescue" \
    --apple-id "bruno@simplinity.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"
  ```
- [ ] Test: `./scripts/sign-and-notarize.sh`

## For Each Release

- [ ] Update `MARKETING_VERSION` in project.yml
- [ ] Update `CURRENT_PROJECT_VERSION`
- [ ] Run: `./scripts/sign-and-notarize.sh`
- [ ] Verify: app opens without Gatekeeper warning on a clean Mac
- [ ] Create DMG (O2)
- [ ] Upload to retrorescue.app website (O5)
- [ ] Update Homebrew cask (O4)
- [ ] Tag release in git: `git tag v0.x.0 && git push --tags`
