#!/usr/bin/env bash
# Builds build/Deskflip.app from the Swift package.
#
# Environment:
#   UNIVERSAL=1   build one binary for both arm64 and x86_64
#   VERSION=x.y.z set the bundle version (default: the latest git tag)

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Deskflip"
BUNDLE_ID="io.github.ardakyncu.deskflip"
BUILD_DIR="build"

if [[ -z "${VERSION:-}" ]]; then
    VERSION="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    VERSION="${VERSION#v}"
    VERSION="${VERSION:-0.0.0}"
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: VERSION must look like 1.2.3, got '$VERSION'" >&2
    exit 1
fi
APP_DIR="$BUILD_DIR/$APP_NAME.app"
ICON_WORK_DIR="$BUILD_DIR/icon"

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swift >/dev/null 2>&1; then
    echo "error: Swift was not found." >&2
    echo "Install the Xcode Command Line Tools and try again:" >&2
    echo "    xcode-select --install" >&2
    exit 1
fi

SWIFT_FLAGS=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    SWIFT_FLAGS+=(--arch arm64 --arch x86_64)
fi

echo "==> Building $APP_NAME $VERSION"
swift build "${SWIFT_FLAGS[@]}"
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Renders the icon with scripts/make-icon.swift and packs it into AppIcon.icns.
make_icon() {
    local iconset="$ICON_WORK_DIR/AppIcon.iconset"
    local master="$ICON_WORK_DIR/icon_1024.png"
    local size

    rm -rf "$ICON_WORK_DIR"
    mkdir -p "$iconset"

    xcrun swiftc -O -o "$ICON_WORK_DIR/make-icon" scripts/make-icon.swift || return 1
    "$ICON_WORK_DIR/make-icon" "$master" || return 1

    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$master" --out "$iconset/icon_${size}x${size}.png" >/dev/null || return 1
        sips -z $((size * 2)) $((size * 2)) "$master" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null || return 1
    done

    iconutil -c icns "$iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns" || return 1
}

ICON_ENTRY=""
echo "==> Rendering app icon"
if make_icon; then
    ICON_ENTRY="<key>CFBundleIconFile</key>
    <string>AppIcon</string>"
else
    echo "warning: could not generate the app icon, continuing without it" >&2
fi

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    $ICON_ENTRY
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ardakyncu. MIT License.</string>
</dict>
</plist>
EOF
plutil -lint -s "$APP_DIR/Contents/Info.plist"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP_DIR"

echo "==> Done: $APP_DIR"
