# OpenMW iOS dependency superbuild

This directory owns the reproducible third-party dependency graph for the iOS
fork. It intentionally does not reuse host packages or the dynamic macOS
dependency bundle.

## Layout

- `dependencies.lock.json` pins every source archive, SHA-256 and license.
- `vcpkg.json` exposes additive build groups as manifest features.
- `vcpkg-configuration.json` pins the exact builtin registry revision.
- `triplets/` separates `iphoneos/arm64` from
  `iphonesimulator/arm64`.
- `smoke/` is a minimal bundle that forces selected dependency symbols through
  the Apple linker.

Generated output is always below `build/ios-deps/`:

```text
source-cache/                         immutable archives from the lock
downloads/                            vcpkg's verified download cache
asset-cache/                          content-addressed offline asset cache
tooling/vcpkg/                        pinned vcpkg source and executable
iphoneos/vcpkg_installed/<triplet>/   device static prefix
iphonesimulator/vcpkg_installed/<triplet>/ simulator static prefix
```

Device and simulator artifacts must never be combined with `lipo`.

## Bootstrap proof

On macOS with Xcode 16.4:

```bash
bash CI/ios/deps/build.sh --platform iphoneos --feature bootstrap --clean
bash CI/ios/deps/build.sh --platform iphonesimulator --feature bootstrap --clean
```

The returned path is the selected prefix. Validate it and link the smoke app:

```bash
bash CI/ios/deps/validate-prefix.sh iphoneos <device-prefix>
bash CI/ios/deps/build-smoke.sh iphoneos <device-prefix>
```

After one online build, a clean source rebuild can be forced without origin
access:

```bash
bash CI/ios/deps/build.sh \
  --platform iphoneos \
  --feature bootstrap \
  --clean \
  --offline
```

`--clean` preserves only the immutable source/download/tool caches. It removes
the selected platform's build trees, packages and installed prefix.
