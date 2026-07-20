#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lock_file="${IOS_DEPS_LOCK_FILE:-${script_dir}/../../../ios-deps/dependencies.lock.json}"
cache_dir="${IOS_DEPS_SOURCE_CACHE:-${PWD}/build/ios-deps/source-cache}"
offline=0

usage() {
    cat <<'EOF'
Usage: fetch-sources.sh [--cache DIR] [--lock FILE] [--offline]
                        [--group NAME | --dependency NAME]

Downloads immutable archives from lock.json and verifies every SHA-256.
Active builtin-vcpkg profiles additionally verify the SHA-512 used by the
pinned registry port.
With --offline, network access is forbidden and every archive must already be
present in the cache. NAME is one of: base, language, multimedia, render, all.
EOF
}

group=all
dependency_name=
while (($#)); do
    case "$1" in
        --cache)
            cache_dir="$2"
            shift 2
            ;;
        --lock)
            lock_file="$2"
            shift 2
            ;;
        --offline)
            offline=1
            shift
            ;;
        --group)
            group="$2"
            shift 2
            ;;
        --dependency)
            dependency_name="$2"
            shift 2
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

case "$group" in
    base|language|multimedia|render|all) ;;
    *)
        echo "Unsupported dependency group: $group" >&2
        exit 2
        ;;
esac
if [[ -n "$dependency_name" && "$group" != all ]]; then
    echo "--group and --dependency are mutually exclusive" >&2
    exit 2
fi

for command in cmake curl jq shasum; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command is unavailable: $command" >&2
        exit 1
    fi
done

cmake -DLOCK_FILE="$lock_file" -P "${script_dir}/validate-lock.cmake"
mkdir -p "$cache_dir"

if [[ -n "$dependency_name" ]]; then
    selector=".dependencies[] | select(.name == \"${dependency_name}\")"
elif [[ "$group" == all ]]; then
    selector='.dependencies[]'
else
    selector=".dependencies[] | select(.group == \"${group}\")"
fi

dependencies=()
while IFS= read -r dependency; do
    dependencies+=("$dependency")
done < <(
    jq -r \
        "${selector} |
            [.name, .archive, .url, .sha256, (.vcpkg_sha512 // \"-\")] |
            @tsv" \
        "$lock_file"
)

if ((${#dependencies[@]} == 0)); then
    echo "No dependencies selected for group: $group" >&2
    exit 1
fi

for dependency in "${dependencies[@]}"; do
    IFS=$'\t' read -r name archive url expected_sha256 expected_sha512 \
        <<<"$dependency"
    destination="${cache_dir}/${archive}"

    if [[ -f "$destination" ]]; then
        actual_sha256="$(shasum -a 256 "$destination" | awk '{print $1}')"
        if [[ "$actual_sha256" != "$expected_sha256" ]]; then
            echo "${name}: cached archive has an invalid SHA-256" >&2
            rm -f "$destination"
            if ((offline)); then
                exit 1
            fi
        fi
    fi

    if [[ ! -f "$destination" ]]; then
        if ((offline)); then
            echo "${name}: archive is absent in offline cache: ${destination}" >&2
            exit 1
        fi
        temporary="${destination}.partial"
        rm -f "$temporary"
        echo "${name}: downloading immutable source archive"
        curl --fail --location --retry 4 --retry-all-errors \
            --output "$temporary" "$url"
        mv "$temporary" "$destination"
    fi

    actual_sha256="$(shasum -a 256 "$destination" | awk '{print $1}')"
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        echo "${name}: SHA-256 mismatch" >&2
        echo "  expected: ${expected_sha256}" >&2
        echo "  actual:   ${actual_sha256}" >&2
        rm -f "$destination"
        exit 1
    fi
    if [[ "$expected_sha512" != "-" ]]; then
        actual_sha512="$(shasum -a 512 "$destination" | awk '{print $1}')"
        if [[ "$actual_sha512" != "$expected_sha512" ]]; then
            echo "${name}: vcpkg SHA-512 mismatch" >&2
            echo "  expected: ${expected_sha512}" >&2
            echo "  actual:   ${actual_sha512}" >&2
            rm -f "$destination"
            exit 1
        fi
    fi
    echo "${name}: verified ${expected_sha256}"
done

echo "Verified ${#dependencies[@]} source archives in ${cache_dir}"
