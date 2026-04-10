#!/usr/bin/env bash
# bundle-mwaw-tools.sh — copy libmwaw command-line tools and their dylib
# dependencies into Resources/tools/, and rewrite the dylib search paths
# with install_name_tool so they look in @loader_path (i.e. the same dir).
#
# Run this once after installing libmwaw via Homebrew. The result is
# committed to git and shipped inside RetroRescue.app.
#
# Tools shipped:
#   mwaw2text  — legacy Mac document → plain text
#   mwaw2html  — legacy Mac document → HTML with styling
#   mwawFile   — identify legacy Mac document format
#
# Required dylibs (the rest are macOS system libs):
#   libmwaw-0.3.3.dylib
#   librevenge-0.0.0.dylib
#   librevenge-generators-0.0.0.dylib
#   librevenge-stream-0.0.0.dylib

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/Resources/tools"
MWAW_PREFIX="$(brew --prefix libmwaw)"
REVENGE_PREFIX="$(brew --prefix librevenge)"

if [ ! -d "$MWAW_PREFIX" ] || [ ! -d "$REVENGE_PREFIX" ]; then
    echo "Error: libmwaw or librevenge not installed via Homebrew." >&2
    echo "Run: brew install libmwaw" >&2
    exit 1
fi

mkdir -p "$TOOLS_DIR"

echo "==> Copying binaries from $MWAW_PREFIX/bin"
for tool in mwaw2text mwaw2html mwawFile; do
    src="$MWAW_PREFIX/bin/$tool"
    if [ ! -x "$src" ]; then
        echo "  ! missing: $src" >&2
        exit 1
    fi
    cp "$src" "$TOOLS_DIR/$tool"
    chmod +x "$TOOLS_DIR/$tool"
    echo "  + $tool"
done

echo "==> Copying dylibs"
DYLIBS=(
    "$MWAW_PREFIX/lib/libmwaw-0.3.3.dylib"
    "$REVENGE_PREFIX/lib/librevenge-0.0.0.dylib"
    "$REVENGE_PREFIX/lib/librevenge-generators-0.0.0.dylib"
    "$REVENGE_PREFIX/lib/librevenge-stream-0.0.0.dylib"
)
for dylib in "${DYLIBS[@]}"; do
    if [ ! -f "$dylib" ]; then
        echo "  ! missing: $dylib" >&2
        exit 1
    fi
    base="$(basename "$dylib")"
    cp "$dylib" "$TOOLS_DIR/$base"
    chmod +w "$TOOLS_DIR/$base"
    echo "  + $base"
done

echo "==> Rewriting dylib install names with install_name_tool"

# For each dylib, set its own install name to @loader_path/<basename>,
# and rewrite all its dependencies on the libmwaw/librevenge family to
# @loader_path/<dep-basename>.
rewrite_dylib() {
    local dylib_path="$1"
    local base
    base="$(basename "$dylib_path")"

    # Set its own ID
    install_name_tool -id "@loader_path/$base" "$dylib_path"

    # Rewrite dependencies — only the libmwaw / librevenge family.
    otool -L "$dylib_path" | tail -n +2 | awk '{print $1}' | while read -r dep; do
        case "$dep" in
            *libmwaw*|*librevenge*)
                local dep_base
                dep_base="$(basename "$dep")"
                install_name_tool -change "$dep" "@loader_path/$dep_base" "$dylib_path"
                ;;
        esac
    done
}

for base in libmwaw-0.3.3.dylib librevenge-0.0.0.dylib librevenge-generators-0.0.0.dylib librevenge-stream-0.0.0.dylib; do
    echo "  ~ $base"
    rewrite_dylib "$TOOLS_DIR/$base"
done

echo "==> Rewriting binary dependency paths"

rewrite_binary() {
    local bin_path="$1"
    otool -L "$bin_path" | tail -n +2 | awk '{print $1}' | while read -r dep; do
        case "$dep" in
            *libmwaw*|*librevenge*)
                local dep_base
                dep_base="$(basename "$dep")"
                install_name_tool -change "$dep" "@loader_path/$dep_base" "$bin_path"
                ;;
        esac
    done
}

for tool in mwaw2text mwaw2html mwawFile; do
    echo "  ~ $tool"
    rewrite_binary "$TOOLS_DIR/$tool"
done

echo "==> Re-signing with ad-hoc identity (install_name_tool invalidated signatures)"
for f in libmwaw-0.3.3.dylib librevenge-0.0.0.dylib librevenge-generators-0.0.0.dylib librevenge-stream-0.0.0.dylib mwaw2text mwaw2html mwawFile; do
    codesign --force -s - "$TOOLS_DIR/$f" 2>/dev/null && echo "  + $f"
done

echo "==> Verification"
for tool in mwaw2text mwaw2html mwawFile; do
    echo ""
    echo "--- $tool ---"
    otool -L "$TOOLS_DIR/$tool" | grep -E "mwaw|revenge" || echo "  (none)"
done

echo ""
echo "==> Done. $(du -sh "$TOOLS_DIR" | cut -f1) total in $TOOLS_DIR"
echo ""
echo "Bundled libmwaw tools:"
ls -lh "$TOOLS_DIR"/{mwaw2text,mwaw2html,mwawFile,libmwaw*,librevenge*} 2>/dev/null
