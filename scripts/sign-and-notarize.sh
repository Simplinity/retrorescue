#!/bin/bash
# O1: Code signing + notarization script for RetroRescue
# Usage: ./scripts/sign-and-notarize.sh [--skip-notarize]
#
# Prerequisites:
#   1. "Developer ID Application" certificate in Keychain
#   2. App-specific password stored: xcrun notarytool store-credentials "RetroRescue"
#      (or set NOTARY_PROFILE env var)
#   3. Xcode command line tools installed
#
# The script will:
#   1. Build a release archive
#   2. Sign the app + all embedded binaries (tools, frameworks, extensions)
#   3. Create a ZIP for notarization
#   4. Submit to Apple's notary service
#   5. Staple the notarization ticket
#   6. Verify the result

set -euo pipefail

# Configuration
SCHEME="RetroRescue"
PROJECT="RetroRescue.xcodeproj"
BUILD_DIR="build/release"
APP_NAME="RetroRescue.app"
BUNDLE_ID="com.simplinity.retrorescue"
NOTARY_PROFILE="${NOTARY_PROFILE:-RetroRescue}"
SKIP_NOTARIZE=false

# Parse args
for arg in "$@"; do
    case $arg in
        --skip-notarize) SKIP_NOTARIZE=true ;;
    esac
done

# Find signing identity
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$IDENTITY" ]; then
    echo "⚠️  No 'Developer ID Application' certificate found."
    echo "   Using 'Apple Development' for local signing only."
    IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    SKIP_NOTARIZE=true
fi

if [ -z "$IDENTITY" ]; then
    echo "❌ No signing identity found. Install a certificate first."
    exit 1
fi
echo "🔑 Signing with: $IDENTITY"

# Step 1: Clean build for release
echo "🔨 Building release archive…"
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    clean build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed — $APP_PATH not found"
    exit 1
fi
echo "✅ Build succeeded: $APP_PATH"

# Step 2: Sign all embedded binaries (inside-out order)
echo "🔏 Signing embedded binaries…"
ENTITLEMENTS="Sources/RetroRescue/RetroRescue.entitlements"

# Sign bundled tools (no entitlements needed for command-line tools)
for tool in "$APP_PATH/Contents/Resources/tools/"*; do
    echo "   Signing tool: $(basename "$tool")"
    codesign --force --options runtime --timestamp \
        --sign "$IDENTITY" "$tool"
done

# Sign frameworks
for fw in "$APP_PATH/Contents/Frameworks/"*.framework; do
    [ -d "$fw" ] || continue
    echo "   Signing framework: $(basename "$fw")"
    codesign --force --options runtime --timestamp \
        --sign "$IDENTITY" "$fw"
done

# Sign Quick Look extension
QLEXT="$APP_PATH/Contents/PlugIns/RetroRescueQuickLook.appex"
if [ -d "$QLEXT" ]; then
    echo "   Signing extension: RetroRescueQuickLook.appex"
    codesign --force --options runtime --timestamp \
        --sign "$IDENTITY" "$QLEXT"
fi

# Sign the main app (last — outermost)
echo "   Signing app: $APP_NAME"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" "$APP_PATH"

# Verify signature
echo "🔍 Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "✅ Signature valid"

# Step 3: Notarize (unless skipped)
if [ "$SKIP_NOTARIZE" = true ]; then
    echo "⏭️  Skipping notarization (--skip-notarize or no Developer ID cert)"
else
    echo "📦 Creating ZIP for notarization…"
    ZIP_PATH="$BUILD_DIR/RetroRescue.zip"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    echo "🚀 Submitting to Apple notary service…"
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "📎 Stapling notarization ticket…"
    xcrun stapler staple "$APP_PATH"

    echo "🔍 Final verification…"
    spctl --assess --type execute --verbose "$APP_PATH"
    echo "✅ Notarization complete — app is ready for distribution"

    rm -f "$ZIP_PATH"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Signed app: $APP_PATH"
echo "🔑 Identity: $IDENTITY"
echo "🏷️  Bundle ID: $BUNDLE_ID"
[ "$SKIP_NOTARIZE" = false ] && echo "✅ Notarized and stapled"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
