# Duckpad PlantUML

Local PlantUML previews for Duckpad. Plugin releases live in this repository;
Duckpad's plugin catalog records their immutable download URLs and checksums.

Requires **Duckpad 0.10.0 or later**, host API **1.4.0**, and macOS 13 or later.
Install the signed `com.duckpad.plantuml.duckpad-plugin` package through Plugins Admin.
Open Plugins → PlantUML or press **Command-Option-U**.

- Compact preview dock with document/file actions, PNG/SVG export and zoom.
- **Control-W** closes the preview dock without closing the editor document.
- Runtime paths live in Settings, including offline Java and PlantUML JAR paths.
- Automatic setup downloads a private Temurin Java 21 JRE and pinned PlantUML 1.2026.8.
- Rendering stays local, with a sandboxed JVM reused until ten minutes of inactivity.
- Eight languages: English, Korean, Japanese, Simplified Chinese, German, French,
  Italian and Brazilian Portuguese.

PlantUML syntax highlighting and hexadecimal color chips belong to Duckpad's
editor and work independently of this plugin. No Java or JAR is bundled here.
See Duckpad's [PlantUML guide](https://github.com/namJeongwan/duckpad/blob/main/docs/plugins/plantuml.md)
for runtime limits, security boundaries and offline setup.

## Build and verify

Xcode command-line tools are required. The checked-in SDK snapshot lets the plugin
build without a Duckpad checkout. Do not include private diagrams or rendered
outputs in the repository.

```sh
bash scripts/test-native.sh
bash scripts/build.sh universal
swift scripts/sign.swift dist/com.duckpad.plantuml.duckpad-plugin
```

Signing reuses the existing configured publisher key outside the repository.
It never creates or rotates a key. Set `DUCKPAD_PLUGIN_SIGN_IDENTITY` to use an
existing Mach-O signing identity; the default is ad-hoc signing, without Apple
notarization. Ed25519 package signing is separate from Mach-O signing.

Host runtime tests live in Duckpad's `tests/PlantUMLRuntimeSmoke` and are run with
its `scripts/test_plantuml_runtime.sh`; they exercise JVM reuse, idle expiry,
cancellation, errors and process-group cleanup.

## Release order

1. Review and tag this repository, build both architectures, sign and verify the package.
2. Publish `Duckpad-PlantUML-0.1.0-universal.zip` with its SHA-256 checksum.
3. Update `namJeongwan/duckpad-plugins` using the published URL, digest and publisher key.
4. Publish the compatible Duckpad host release.

Never replace an existing version's assets. A local candidate archive is not a
published release; catalog metadata must only be merged after its asset is available.
