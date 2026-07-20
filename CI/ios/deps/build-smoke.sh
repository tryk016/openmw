#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
    echo "Usage: build-smoke.sh iphoneos|iphonesimulator PREFIX" >&2
    exit 2
fi

platform="$1"
prefix="$2"
case "$platform" in
    iphoneos|iphonesimulator) ;;
    *)
        echo "Unsupported platform: $platform" >&2
        exit 2
        ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
build_dir="${repo_root}/build/ios-deps/${platform}/smoke"

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
    --target openmw-ios-deps-smoke \
    --parallel 3

app="$(
    find "$build_dir" -type d -name OpenMWDepsSmoke.app -print -quit
)"
if [[ -z "$app" ]]; then
    echo "The dependency smoke app was not produced" >&2
    exit 1
fi

binary="${app}/OpenMWDepsSmoke"
test -f "$binary"
lipo -archs "$binary" | grep -Fx arm64
xcrun vtool -show-build "$binary" | grep -Eq \
    'minos[[:space:]]+16\.4([[:space:]]|$)'
if otool -L "$binary" | tail -n +2 |
        grep -Ev '^[[:space:]]+(/System/Library/Frameworks/|/usr/lib/)'; then
    echo "Smoke bundle links a non-system dynamic dependency" >&2
    exit 1
fi

echo "$app"
