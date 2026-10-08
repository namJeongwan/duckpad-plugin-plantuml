#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
PACKAGE="dist/com.duckpad.plantuml.duckpad-plugin"
ARCHIVE="dist/Duckpad-PlantUML-0.1.0-universal.zip"
[[ ! -e "$ARCHIVE" ]] || { echo "Refusing to replace existing release archive" >&2; exit 73; }
bash scripts/build.sh universal
swift scripts/sign.swift "$PACKAGE"
swift scripts/verify.swift "$PACKAGE"
codesign --verify --strict "$PACKAGE/module.dylib"
[[ "$(lipo -archs "$PACKAGE/module.dylib")" == *arm64* && "$(lipo -archs "$PACKAGE/module.dylib")" == *x86_64* ]]
ditto -c -k --keepParent "$PACKAGE" "$ARCHIVE"
unzip -tq "$ARCHIVE"
(cd dist && shasum -a 256 "$(basename "$ARCHIVE")" > SHA256SUMS.txt)
printf 'Prepared candidate: %s\n' "$PWD/$ARCHIVE"
