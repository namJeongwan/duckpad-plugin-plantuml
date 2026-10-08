#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
SDK="$ROOT/SDK/DuckpadNative"
OUTPUT="dist/com.duckpad.plantuml.duckpad-plugin"
mkdir -p "$OUTPUT" build/module-cache
case "${1:-native}" in
  universal) ARCHES=(arm64 x86_64) ;;
  native) ARCHES=("$(uname -m)") ;;
  *) exit 64 ;;
esac
MODULES=()
for ARCH in "${ARCHES[@]}"; do
  mkdir -p "build/$ARCH"
  swiftc -swift-version 6 -target "$ARCH-apple-macosx13.0" -module-cache-path "$PWD/build/module-cache" \
    -O -emit-library -module-name DuckpadPlantUML_0_1_0 -I "$SDK/include" \
    "$SDK/Swift/DuckpadHost.swift" "$ROOT/SDK/DuckpadRuntime/NativeInstallerXPCProtocol.swift" \
    "$ROOT/SDK/DuckpadRuntime/PlantUMLRequest.swift" Sources/*.swift \
    -framework AppKit -framework Security -o "build/$ARCH/module.dylib"
  MODULES+=("build/$ARCH/module.dylib")
done
if [[ "${#MODULES[@]}" == 1 ]]; then cp "${MODULES[0]}" "$OUTPUT/module.dylib"; else lipo -create "${MODULES[@]}" -output "$OUTPUT/module.dylib"; fi
codesign --force --sign "${DUCKPAD_PLUGIN_SIGN_IDENTITY:--}" --options runtime "$OUTPUT/module.dylib"
cp plugin.json "$OUTPUT/"
cp Resources/*.strings "$OUTPUT/"
python3 - "$OUTPUT" <<'PY'
import hashlib,pathlib,sys
p=pathlib.Path(sys.argv[1])
files=sorted(f for f in p.iterdir() if f.name not in {'SHA256SUMS','SIGNATURE.ed25519'})
(p/'SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in files))
PY
printf 'Built: %s\n' "$PWD/$OUTPUT"
