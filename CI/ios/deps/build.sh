#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
manifest_root="${repo_root}/ios-deps"
build_root="${IOS_DEPS_BUILD_ROOT:-${repo_root}/build/ios-deps}"
downloads="${IOS_DEPS_DOWNLOADS:-${build_root}/downloads}"
asset_cache="${IOS_DEPS_ASSET_CACHE:-${build_root}/asset-cache}"
source_cache="${IOS_DEPS_SOURCE_CACHE:-${build_root}/source-cache}"
platform=
feature=bootstrap
offline=0
clean=0

usage() {
    cat <<'EOF'
Usage: build.sh --platform iphoneos|iphonesimulator
                [--feature NAME] [--offline] [--clean]

Builds one static per-SDK vcpkg prefix. --offline forbids origin downloads.
--clean removes only generated build/package/install state and preserves the
verified source and vcpkg download caches.
EOF
}

while (($#)); do
    case "$1" in
        --platform)
            platform="$2"
            shift 2
            ;;
        --feature)
            feature="$2"
            shift 2
            ;;
        --offline)
            offline=1
            shift
            ;;
        --clean)
            clean=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$platform" in
    iphoneos)
        triplet=arm64-ios-openmw
        ;;
    iphonesimulator)
        triplet=arm64-ios-simulator-openmw
        ;;
    *)
        echo "--platform must be iphoneos or iphonesimulator" >&2
        exit 2
        ;;
esac

if [[ "$(uname -s)" != Darwin ]]; then
    echo "The iOS dependency superbuild requires macOS and Xcode" >&2
    exit 1
fi

case "$feature" in
    bootstrap)
        locked_dependencies=(zlib)
        ;;
    *)
        echo "Unsupported dependency feature: $feature" >&2
        exit 2
        ;;
esac

for command in jq xcrun; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command is unavailable: $command" >&2
        exit 1
    fi
done

deployment_target="$(
    jq -er '.deployment_target' "${manifest_root}/dependencies.lock.json"
)"
if [[ "$deployment_target" != 16.4 ]]; then
    echo "Unexpected deployment target in dependency lock: $deployment_target" >&2
    exit 1
fi

for dependency in "${locked_dependencies[@]}"; do
    fetch_args=(
        --lock "${manifest_root}/dependencies.lock.json"
        --cache "$source_cache"
        --dependency "$dependency"
    )
    if ((offline)); then
        fetch_args+=(--offline)
    fi
    bash "${script_dir}/fetch-sources.sh" "${fetch_args[@]}" >&2
done

platform_root="${build_root}/${platform}"
buildtrees="${platform_root}/buildtrees"
packages="${platform_root}/packages"
install_root="${platform_root}/vcpkg_installed"

if ((clean)); then
    for path in "$buildtrees" "$packages" "$install_root"; do
        case "$path" in
            "${build_root}"/*) rm -rf "$path" ;;
            *)
                echo "Refusing to clean outside the iOS dependency build root" >&2
                exit 1
                ;;
        esac
    done
fi

mkdir -p "$downloads" "$asset_cache" "$source_cache" "$platform_root"
export IOS_DEPS_BUILD_ROOT="$build_root"
export IOS_DEPS_SOURCE_CACHE="$source_cache"
export IOS_DEPS_OFFLINE="$offline"
vcpkg_root="$(bash "${script_dir}/bootstrap-vcpkg.sh")"

export VCPKG_DISABLE_METRICS=1
export VCPKG_DOWNLOADS="$downloads"
export VCPKG_BINARY_SOURCES=clear
if ((offline)); then
    export X_VCPKG_ASSET_SOURCES="clear;x-azurl,file://${asset_cache},,readwrite;x-block-origin"
else
    export X_VCPKG_ASSET_SOURCES="clear;x-azurl,file://${asset_cache},,readwrite"
fi

vcpkg_args=(
    --x-manifest-root="$manifest_root"
    --x-install-root="$install_root"
    --x-buildtrees-root="$buildtrees"
    --x-packages-root="$packages"
    --overlay-triplets="${manifest_root}/triplets"
    --triplet="$triplet"
    --x-feature="$feature"
    --clean-buildtrees-after-build
    --clean-packages-after-build
)
if ((offline)); then
    vcpkg_args+=(--no-downloads)
fi
"${vcpkg_root}/vcpkg" install "${vcpkg_args[@]}" >&2

prefix="${install_root}/${triplet}"
if [[ ! -d "$prefix" ]]; then
    echo "Expected vcpkg prefix was not created: $prefix" >&2
    exit 1
fi

{
    echo "platform=${platform}"
    echo "triplet=${triplet}"
    echo "deployment_target=${deployment_target}"
    echo "feature=${feature}"
    echo "offline=${offline}"
    echo "prefix=${prefix}"
} >"${platform_root}/build-manifest.txt"

printf '%s\n' "$prefix"
