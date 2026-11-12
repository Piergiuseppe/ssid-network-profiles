#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
NAME="WiFi Profili"
APP="build/$NAME.app"
BINARY="$APP/Contents/MacOS/WiFiProfili"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)}"

rm -rf build dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"

for ARCH in arm64 x86_64; do
    swiftc -O -parse-as-library -target "$ARCH-apple-macos14" Sources/*.swift -o "build/WiFiProfili-$ARCH"
done
lipo -create build/WiFiProfili-arm64 build/WiFiProfili-x86_64 -output "$BINARY"
rm build/WiFiProfili-arm64 build/WiFiProfili-x86_64
codesign --force --sign - "$APP"

case "${1:-}" in
install)
    DEST="$HOME/Applications/$NAME.app"
    pkill -x WiFiProfili || true
    mkdir -p "$HOME/Applications"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    open "$DEST"
    ;;
package)
    DMG="WiFi-Profili-$VERSION.dmg"
    mkdir -p dist build/dmg
    cp -R "$APP" build/dmg/
    ln -s /Applications build/dmg/Applications
    hdiutil create -quiet -volname "$NAME" -srcfolder build/dmg -format UDZO "dist/$DMG"
    (cd dist && shasum -a 256 "$DMG" > "$DMG.sha256")
    cat "dist/$DMG.sha256"
    ;;
esac
