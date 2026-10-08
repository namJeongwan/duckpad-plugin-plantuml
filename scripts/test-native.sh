#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$ROOT/SDK/DuckpadNative"
mkdir -p "$ROOT/build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache"
PLUGIN="$ROOT"
STAGING="$(mktemp -d /tmp/duckpad-plantuml-native.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
swiftc -swift-version 6 -I "$SDK/include" "$SDK/Swift/DuckpadHost.swift" \
  "$PLUGIN/Tests/HostSmoke.swift" -o "$STAGING/host-smoke"
"$STAGING/host-smoke"
APP="$STAGING/PreviewSmoke.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -swift-version 6 -I "$SDK/include" "$SDK/Swift/DuckpadHost.swift" \
  "$ROOT/SDK/DuckpadRuntime/NativeInstallerXPCProtocol.swift" \
  "$ROOT/SDK/DuckpadRuntime/PlantUMLRequest.swift" "$PLUGIN"/Sources/*.swift \
  "$PLUGIN/Tests/PreviewSmoke.swift" -framework AppKit -framework Security -o "$APP/Contents/MacOS/PreviewSmoke"
cp "$PLUGIN"/Resources/*.strings "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.namjeongwan.duckpad.plantuml-ui-smoke</string>
<key>CFBundleName</key><string>PlantUML UI Smoke</string>
<key>CFBundleExecutable</key><string>PreviewSmoke</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
"$APP/Contents/MacOS/PreviewSmoke"
