#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
manifest_root="${repo_root}/ios-deps"
build_root="${IOS_DEPS_BUILD_ROOT:-${repo_root}/build/ios-deps}"
shared_downloads="${IOS_DEPS_DOWNLOADS:-${build_root}/downloads}"
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

case "$(uname -m)" in
    arm64)
        host_triplet=arm64-osx
        ;;
    x86_64)
        host_triplet=x64-osx
        ;;
    *)
        echo "Unsupported macOS host architecture: $(uname -m)" >&2
        exit 1
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

if ! jq -e --arg feature "$feature" \
        '.build_profiles[$feature] | arrays and length > 0' \
        "${manifest_root}/dependencies.lock.json" >/dev/null; then
    echo "Unsupported or empty dependency feature: $feature" >&2
    exit 2
fi

locked_dependencies=()
while IFS= read -r dependency; do
    locked_dependencies+=("$dependency")
done < <(
    jq -r --arg feature "$feature" \
        '.build_profiles[$feature][]' \
        "${manifest_root}/dependencies.lock.json"
)

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

if ((offline)); then
    # An offline rebuild must prove that the content-addressed asset cache is
    # sufficient.  Reusing VCPKG_DOWNLOADS (or --no-downloads) would bypass the
    # asset provider and could produce a false-positive offline result.
    downloads="${platform_root}/offline-downloads"
    case "$downloads" in
        "${build_root}"/*) rm -rf "$downloads" ;;
        *)
            echo "Refusing to reset offline downloads outside the iOS dependency build root" >&2
            exit 1
            ;;
    esac
else
    downloads="$shared_downloads"
fi

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

for dependency in "${locked_dependencies[@]}"; do
    vcpkg_port="$(
        jq -er --arg dependency "$dependency" \
            'first(.dependencies[] |
                select(.name == $dependency) |
                .vcpkg_port)' \
            "${manifest_root}/dependencies.lock.json"
    )"
    expected_vcpkg_sha512="$(
        jq -er --arg dependency "$dependency" \
            'first(.dependencies[] |
                select(.name == $dependency) |
                .vcpkg_sha512)' \
            "${manifest_root}/dependencies.lock.json"
    )"
    vcpkg_source_marker="$(
        jq -er --arg dependency "$dependency" \
            'first(.dependencies[] |
                select(.name == $dependency) |
                .vcpkg_source_marker)' \
            "${manifest_root}/dependencies.lock.json"
    )"
    portfile="${vcpkg_root}/ports/${vcpkg_port}/portfile.cmake"
    if [[ ! -f "$portfile" ]]; then
        echo "$dependency: pinned vcpkg portfile is missing: $portfile" >&2
        exit 1
    fi
    if ! awk -v marker="$vcpkg_source_marker" \
            -v expected_sha512="$expected_vcpkg_sha512" '
        index($0, marker) {
            in_source_block = 1
        }
        in_source_block && $0 ~ /^[[:space:]]*SHA512[[:space:]]+/ &&
                index($0, expected_sha512) {
            source_hash_matches = 1
        }
        in_source_block && $0 ~ /^[[:space:]]*\)[[:space:]]*$/ {
            exit
        }
        END {
            exit(source_hash_matches ? 0 : 1)
        }
    ' "$portfile"; then
        echo "$dependency: lock SHA-512 is not bound to the pinned source block" >&2
        exit 1
    fi
done

export VCPKG_DISABLE_METRICS=1
export VCPKG_DOWNLOADS="$downloads"
export VCPKG_BINARY_SOURCES=clear
if ((offline)); then
    export X_VCPKG_ASSET_SOURCES="clear;x-azurl,file://${asset_cache},,read;x-block-origin"
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
    --host-triplet="$host_triplet"
    --x-feature="$feature"
    --clean-buildtrees-after-build
    --clean-packages-after-build
)
"${vcpkg_root}/vcpkg" install "${vcpkg_args[@]}" >&2

prefix="${install_root}/${triplet}"
if [[ ! -d "$prefix" ]]; then
    echo "Expected vcpkg prefix was not created: $prefix" >&2
    exit 1
fi

for dependency in "${locked_dependencies[@]}"; do
    expected_vcpkg_sha512="$(
        jq -er --arg dependency "$dependency" \
            'first(.dependencies[] |
                select(.name == $dependency) |
                .vcpkg_sha512)' \
            "${manifest_root}/dependencies.lock.json"
    )"
    cached_asset="${asset_cache}/${expected_vcpkg_sha512}"
    if [[ ! -f "$cached_asset" ]]; then
        echo "$dependency: verified vcpkg source is absent from the asset cache" >&2
        exit 1
    fi
    actual_asset_sha512="$(
        shasum -a 512 "$cached_asset" | awk '{print $1}'
    )"
    if [[ "$actual_asset_sha512" != "$expected_vcpkg_sha512" ]]; then
        echo "$dependency: vcpkg asset cache SHA-512 mismatch" >&2
        exit 1
    fi
done

installed_json="${platform_root}/installed-packages.json"
"${vcpkg_root}/vcpkg" list --x-json \
    --x-install-root="$install_root" >"$installed_json"
if ! jq -e 'type == "object"' "$installed_json" >/dev/null; then
    echo "vcpkg list did not produce an installed-package JSON object" >&2
    exit 1
fi

installed_core_field() {
    local package="$1"
    local wanted_field="$2"
    jq -er --arg package "$package" --arg triplet "$triplet" \
        --arg field "$wanted_field" '
        first(to_entries[].value
            | select(.package_name == $package and .triplet == $triplet))
        | if $field == "version" then .version else .port_version end
    ' "$installed_json"
}

installed_version() {
    installed_core_field "$1" version
}

installed_port_version() {
    installed_core_field "$1" port-version
}

for dependency in "${locked_dependencies[@]}"; do
    vcpkg_port="$(
        jq -er --arg dependency "$dependency" \
            'first(.dependencies[] |
                select(.name == $dependency) |
                .vcpkg_port)' \
            "${manifest_root}/dependencies.lock.json"
    )"
    expected_version="$(
        jq -er --arg dependency "$dependency" \
            'first(.dependencies[] |
                select(.name == $dependency) |
                .version)' \
            "${manifest_root}/dependencies.lock.json"
    )"
    expected_port_version="$(
        jq -er --arg dependency "$dependency" \
            'first(.dependencies[] |
                select(.name == $dependency) |
                (.vcpkg_port_version // 0))' \
            "${manifest_root}/dependencies.lock.json"
    )"
    actual_version="$(installed_version "$vcpkg_port")"
    actual_port_version="$(installed_port_version "$vcpkg_port")"
    if [[ -z "$actual_version" ]]; then
        echo "$dependency is absent from the $triplet vcpkg prefix" >&2
        exit 1
    fi
    if [[ "$actual_version" != "$expected_version" ]]; then
        echo "$dependency version mismatch: lock=$expected_version, installed=$actual_version" >&2
        exit 1
    fi
    if [[ "$actual_port_version" != "$expected_port_version" ]]; then
        echo "$dependency port-version mismatch: lock=$expected_port_version, installed=$actual_port_version" >&2
        exit 1
    fi
done

bash "${script_dir}/validate-installed-closure.sh" \
    --lock "${manifest_root}/dependencies.lock.json" \
    --installed-json "$installed_json" \
    --profile "$feature" \
    --target-triplet "$triplet" \
    --host-triplet "$host_triplet"

{
    echo "platform=${platform}"
    echo "triplet=${triplet}"
    echo "host_triplet=${host_triplet}"
    echo "deployment_target=${deployment_target}"
    echo "feature=${feature}"
    echo "offline=${offline}"
    echo "prefix=${prefix}"
    for dependency in "${locked_dependencies[@]}"; do
        vcpkg_port="$(
            jq -er --arg dependency "$dependency" \
                'first(.dependencies[] |
                    select(.name == $dependency) |
                    .vcpkg_port)' \
                "${manifest_root}/dependencies.lock.json"
        )"
        echo "dependency.${dependency}=$(installed_version "$vcpkg_port")"
        echo "dependency.${dependency}.port-version=$(installed_port_version "$vcpkg_port")"
    done
} >"${platform_root}/build-manifest.txt"

printf '%s\n' "$prefix"
