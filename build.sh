#!/bin/zsh
# Builds Tally.app and installs it to /Applications.
set -e
cd "$(dirname "$0")"

APP=build/Tally.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Compiling Swift sources…"
swiftc -O -parse-as-library \
  -target arm64-apple-macosx14.0 \
  Sources/*.swift Sources/Engine/*.swift \
  -o "$APP/Contents/MacOS/Tally"

echo "▸ Writing Info.plist…"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Tally</string>
    <key>CFBundleDisplayName</key><string>Tally</string>
    <key>CFBundleIdentifier</key><string>com.spiraos.tally</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>Tally</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

echo "▸ Building app icon from Icon.png (full-bleed)…"
swift scripts/make_icon.swift Icon.png build/AppIcon.iconset >/dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Code signing (ad-hoc)…"
codesign --force --deep -s - "$APP"

echo "▸ Installing to /Applications…"
rm -rf /Applications/Tally.app
cp -R "$APP" /Applications/Tally.app

echo "✓ Done — Tally.app installed in /Applications"
