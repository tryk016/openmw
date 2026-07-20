#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
    echo "Usage: build-smoke.sh iphoneos|iphonesimulator PREFIX" >&2
    exit 2
fi

platform="$1"
prefix="$2"
case "$platform" in
    iphoneos)
        expected_platform=IOS
        ;;
    iphonesimulator)
        expected_platform=IOSSIMULATOR
        ;;
    *)
        echo "Unsupported platform: $platform" >&2
        exit 2
        ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
build_dir="${repo_root}/build/ios-deps/${platform}/smoke"
case "$build_dir" in
    "${repo_root}/build/ios-deps/"*) rm -rf "$build_dir" ;;
    *)
        echo "Refusing to clean smoke output outside build/ios-deps" >&2
        exit 1
        ;;
esac

cmake -S "${repo_root}/ios-deps/smoke" \
    -B "$build_dir" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$platform" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.4 \
    -DIOS_DEPS_PREFIX="$prefix" \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=
cmake --build "$build_dir" \
    --config Release \
    --target \
        openmw-ios-deps-smoke \
        openmw-ios-jpeg-probe \
        openmw-ios-turbojpeg-probe \
    --parallel 3

app="$(
    find "$build_dir" -type d -name OpenMWDepsSmoke.app -print -quit
)"
if [[ -z "$app" ]]; then
    echo "The dependency smoke app was not produced" >&2
    exit 1
fi

app_binary="${app}/OpenMWDepsSmoke"
jpeg_probe="$(
    find "$build_dir" -type f -name OpenMWJPEGProbe \
        ! -path '*.dSYM/*' -print -quit
)"
turbojpeg_probe="$(
    find "$build_dir" -type f -name OpenMWTurboJPEGProbe \
        ! -path '*.dSYM/*' -print -quit
)"
for binary in "$app_binary" "$jpeg_probe" "$turbojpeg_probe"; do
    if [[ -z "$binary" || ! -f "$binary" ]]; then
        echo "A dependency smoke binary was not produced" >&2
        exit 1
    fi
    lipo -archs "$binary" | grep -Fx arm64
    build_version="$(xcrun vtool -show-build "$binary")"
    printf '%s\n' "$build_version" | grep -Eq \
        "platform[[:space:]]+${expected_platform}([[:space:]]|$)"
    printf '%s\n' "$build_version" | grep -Eq \
        'minos[[:space:]]+16\.4([[:space:]]|$)'
    if otool -L "$binary" | tail -n +2 |
            grep -Ev '^[[:space:]]+(/System/Library/Frameworks/|/usr/lib/)'; then
        echo "${binary}: links a non-system dynamic dependency" >&2
        exit 1
    fi
done

echo "$app"
