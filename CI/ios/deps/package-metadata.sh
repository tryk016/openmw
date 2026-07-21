#!/usr/bin/env bash
set -euo pipefail

if (($# != 3)); then
    echo "Usage: package-metadata.sh PLATFORM PREFIX OUTPUT_DIR" >&2
    exit 2
fi

platform="$1"
prefix="$2"
output_dir="$3"
case "$platform" in
    iphoneos|iphonesimulator) ;;
    *)
        echo "Unsupported platform: $platform" >&2
        exit 2
        ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
lock_file="${repo_root}/ios-deps/dependencies.lock.json"
icu_filter_file="${repo_root}/extern/icufilters.json"
build_root="${IOS_DEPS_BUILD_ROOT:-${repo_root}/build/ios-deps}"
vcpkg_root="${IOS_DEPS_VCPKG_ROOT:-${build_root}/tooling/vcpkg}"
vcpkg_license="${vcpkg_root}/LICENSE.txt"
vcpkg_stamp="${vcpkg_root}/.openmw-ios-revision"
boost_uninstall_spdx_validator="${script_dir}/validate-boost-uninstall-spdx.jq"
expected_vcpkg_revision="$(
    jq -er '.dependencies[] | select(.name == "vcpkg") | .revision' \
        "$lock_file"
)"

mkdir -p "$(dirname "$output_dir")"
output_dir="$(
    cd "$(dirname "$output_dir")"
    printf '%s/%s\n' "$PWD" "$(basename "$output_dir")"
)"
case "$output_dir" in
    "${repo_root}/build/ios-deps"/*) ;;
    *)
        echo "Refusing to replace metadata outside build/ios-deps" >&2
        exit 1
        ;;
esac

if [[ ! -d "$prefix" ]]; then
    echo "Prefix does not exist: $prefix" >&2
    exit 1
fi

rm -rf "$output_dir"
mkdir -p "${output_dir}/licenses" "${output_dir}/sbom"
cp "$lock_file" "${output_dir}/dependencies.lock.json"

packages=()
while IFS= read -r package_dir; do
    packages+=("$package_dir")
done < <(find "${prefix}/share" -mindepth 1 -maxdepth 1 -type d -print | sort)

if ((${#packages[@]} == 0)); then
    echo "The prefix has no vcpkg package metadata" >&2
    exit 1
fi

metadata_count=0
for package_dir in "${packages[@]}"; do
    package="$(basename "$package_dir")"
    copyright_file="${package_dir}/copyright"
    spdx_file="${package_dir}/vcpkg.spdx.json"

    # Helper packages may not ship runtime notices, but every target package
    # with a generated SPDX document must carry its source notice.
    if [[ -f "$spdx_file" ]]; then
        if [[ ! -f "$copyright_file" ]]; then
            case "$package" in
                boost-uninstall)
                    # This pinned vcpkg helper intentionally declares an empty
                    # package and installs only Boost's CMake wrapper. Its
                    # generated SPDX concludes MIT but the port has no
                    # copyright payload, so retain the pinned vcpkg MIT text.
                    if ! jq -e -f "$boost_uninstall_spdx_validator" \
                            "$spdx_file" >/dev/null; then
                        echo "boost-uninstall: unexpected SPDX identity or license" >&2
                        exit 1
                    fi
                    actual_stamp_revision=
                    if [[ -f "$vcpkg_stamp" ]]; then
                        actual_stamp_revision="$(<"$vcpkg_stamp")"
                    fi
                    actual_head_revision="$(
                        git -C "$vcpkg_root" rev-parse HEAD \
                            2>/dev/null || true
                    )"
                    if [[ "$actual_stamp_revision" != "$expected_vcpkg_revision" ]] ||
                            [[ "$actual_head_revision" != "$expected_vcpkg_revision" ]]; then
                        echo "boost-uninstall: vcpkg notice checkout is not pinned" >&2
                        exit 1
                    fi
                    if [[ ! -f "$vcpkg_license" ]]; then
                        echo "boost-uninstall: pinned vcpkg notice is missing" >&2
                        exit 1
                    fi
                    if ! git -C "$vcpkg_root" show \
                            "${expected_vcpkg_revision}:LICENSE.txt" |
                            cmp - "$vcpkg_license"; then
                        echo "boost-uninstall: vcpkg notice differs from the pinned revision" >&2
                        exit 1
                    fi
                    cp "$vcpkg_license" \
                        "${output_dir}/licenses/${package}.txt"
                    ;;
                *)
                    echo "${package}: SPDX exists but copyright notice is missing" >&2
                    exit 1
                    ;;
            esac
        else
            cp "$copyright_file" "${output_dir}/licenses/${package}.txt"
        fi
        cp "$spdx_file" "${output_dir}/sbom/${package}.spdx.json"
        ((metadata_count += 1))
    fi
done

icu_filter_sha256=
icu_filter_sha512=
if [[ -d "${prefix}/share/icu" ]]; then
    mkdir -p "${output_dir}/icu"
    tr -d '\r' <"$icu_filter_file" >"${output_dir}/icu/icufilters.json"
    icu_filter_sha256="$(
        shasum -a 256 "${output_dir}/icu/icufilters.json" | awk '{print $1}'
    )"
    icu_filter_sha512="$(
        shasum -a 512 "${output_dir}/icu/icufilters.json" | awk '{print $1}'
    )"
    expected_filter_sha256="$(
        jq -er '.dependencies[] | select(.name == "icu") |
            .data_filter.sha256' "$lock_file"
    )"
    expected_filter_sha512="$(
        jq -er '.dependencies[] | select(.name == "icu") |
            .data_filter.sha512' "$lock_file"
    )"
    if [[ "$icu_filter_sha256" != "$expected_filter_sha256" ||
            "$icu_filter_sha512" != "$expected_filter_sha512" ]]; then
        echo "ICU metadata filter hash does not match the lock" >&2
        exit 1
    fi

    host_icu_share="$(dirname "$prefix")/arm64-osx/share/icu"
    if [[ ! -f "${host_icu_share}/vcpkg.spdx.json" ||
            ! -f "${host_icu_share}/copyright" ]]; then
        echo "ICU host SPDX or notice is missing" >&2
        exit 1
    fi
    cp "${host_icu_share}/vcpkg.spdx.json" \
        "${output_dir}/sbom/icu-host.spdx.json"
    cp "${host_icu_share}/copyright" \
        "${output_dir}/licenses/icu-host.txt"
    ((metadata_count += 1))
fi

if ((metadata_count == 0)); then
    echo "No package SPDX documents were generated" >&2
    exit 1
fi

{
    echo "platform=${platform}"
    echo "prefix=${prefix}"
    echo "package_spdx_count=${metadata_count}"
    if [[ -n "$icu_filter_sha256" ]]; then
        echo "icu_filter_sha256=${icu_filter_sha256}"
        echo "icu_filter_sha512=${icu_filter_sha512}"
    fi
} >"${output_dir}/metadata-manifest.txt"

(
    cd "$output_dir"
    while IFS= read -r file; do
        shasum -a 256 "$file"
    done < <(
        find . -type f ! -name SHA256SUMS -print | LC_ALL=C sort
    )
) >"${output_dir}/SHA256SUMS"

echo "Packaged ${metadata_count} SPDX documents and license notices"
