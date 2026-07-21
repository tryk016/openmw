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
The pinned vcpkg checkout deliberately retains complete Git history: versioned
builtin-registry entries can reference historical port trees. A shallow tooling
cache is rejected and rebuilt before dependency resolution.

## Build profiles

On macOS with Xcode 16.4:

```bash
bash CI/ios/deps/build.sh \
  --platform iphoneos \
  --feature data-foundation \
  --clean
bash CI/ios/deps/build.sh \
  --platform iphonesimulator \
  --feature data-foundation \
  --clean
```

`base-foundation` contains the first production slice: SDL2, LZ4 and zlib.
`image-foundation` is cumulative and adds FreeType, libpng and libjpeg-turbo.
`cpp-foundation` adds only the Boost surface used by OpenMW:
Geometry, Iostreams without compression filters, and Program Options. Its
checked-in closure records every target and host helper port resolved by the
pinned vcpkg baseline.
`data-foundation` is cumulative and adds yaml-cpp plus SQLite with JSON1
enabled and runtime extension loading omitted. It intentionally excludes the
SQLite command-line tool, ICU integration and implicit default-feature
expansion; JSON1 is selected explicitly.
`bootstrap` remains available as the smaller zlib-only pipeline proof. The
profile-to-source mapping lives in `dependencies.lock.json`; every profile must
have a matching vcpkg manifest feature. After installation, the build also
compares each selected package version with the lock and rejects any target
package outside the exact profile. Host-only vcpkg helper ports remain governed
by the pinned registry commit.

The returned path is the selected prefix. Validate every archive member and
link the smoke app:

```bash
bash CI/ios/deps/validate-prefix.sh iphoneos <device-prefix>
bash CI/ios/deps/build-smoke.sh iphoneos <device-prefix>
```

After one online build, a clean source rebuild can be forced without origin
access:

```bash
bash CI/ios/deps/build.sh \
  --platform iphoneos \
  --feature data-foundation \
  --clean \
  --offline
```

`--clean` preserves only the immutable source/download/tool caches. It removes
the selected platform's build trees, packages and installed prefix.
