#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
lock_file="${repo_root}/ios-deps/dependencies.lock.json"
build_root="${IOS_DEPS_BUILD_ROOT:-${repo_root}/build/ios-deps}"
source_cache="${IOS_DEPS_SOURCE_CACHE:-${build_root}/source-cache}"
vcpkg_root="${IOS_DEPS_VCPKG_ROOT:-${build_root}/tooling/vcpkg}"
offline="${IOS_DEPS_OFFLINE:-0}"

revision="$(
    jq -er '.dependencies[] | select(.name == "vcpkg") | .revision' "$lock_file"
)"
fetch_args=(
    --lock "$lock_file"
    --cache "$source_cache"
    --dependency vcpkg
)
if [[ "$offline" == 1 ]]; then
    fetch_args+=(--offline)
fi
bash "${script_dir}/fetch-sources.sh" "${fetch_args[@]}" >&2

stamp="${vcpkg_root}/.openmw-ios-revision"
cached_revision=
cached_is_shallow=
if [[ -d "${vcpkg_root}/.git" ]]; then
    cached_revision="$(
        git -C "$vcpkg_root" rev-parse HEAD 2>/dev/null || true
    )"
    cached_is_shallow="$(
        git -C "$vcpkg_root" rev-parse --is-shallow-repository \
            2>/dev/null || true
    )"
fi
if [[ -x "${vcpkg_root}/vcpkg" && -f "$stamp" ]] &&
        [[ "$(<"$stamp")" == "$revision" ]] &&
        [[ "$cached_revision" == "$revision" ]] &&
        [[ "$cached_is_shallow" == false ]]; then
    printf '%s\n' "$vcpkg_root"
    exit 0
fi

case "$vcpkg_root" in
    "${build_root}"/*) ;;
    *)
        echo "Refusing to replace vcpkg outside the iOS dependency build root" >&2
        exit 1
        ;;
esac

rm -rf "$vcpkg_root"
mkdir -p "$vcpkg_root"

if [[ "$offline" == 1 ]]; then
    echo "Pinned vcpkg tooling is absent from the preserved offline cache" >&2
    echo "Run one online build before requesting an offline rebuild" >&2
    exit 1
fi

# The independently SHA-256-verified archive above is the recoverable source
# snapshot. Keep the complete ancestry of the immutable vcpkg commit because
# versioned builtin-registry entries reference historical Git tree objects.
# A shallow repository can bootstrap the tool but cannot resolve that graph.
git -C "$vcpkg_root" init >&2
git -C "$vcpkg_root" remote add origin \
    https://github.com/microsoft/vcpkg.git
git -C "$vcpkg_root" fetch --no-tags origin "$revision" >&2
git -C "$vcpkg_root" checkout --detach FETCH_HEAD >&2
if [[ "$(git -C "$vcpkg_root" rev-parse HEAD)" != "$revision" ]]; then
    echo "The checked-out vcpkg revision does not match the dependency lock" >&2
    exit 1
fi
if [[ "$(git -C "$vcpkg_root" rev-parse --is-shallow-repository)" != false ]]; then
    echo "The pinned vcpkg checkout must contain complete Git history" >&2
    exit 1
fi
git -C "$vcpkg_root" remote set-url origin DISABLED

(
    cd "$vcpkg_root"
    ./bootstrap-vcpkg.sh -disableMetrics
) >&2
printf '%s\n' "$revision" >"$stamp"
printf '%s\n' "$vcpkg_root"
