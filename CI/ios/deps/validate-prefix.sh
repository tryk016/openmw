#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
    echo "Usage: validate-prefix.sh iphoneos|iphonesimulator PREFIX" >&2
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

if [[ ! -d "$prefix" ]]; then
    echo "Prefix does not exist: $prefix" >&2
    exit 1
fi

for command in ar file find lipo xcrun; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command is unavailable: $command" >&2
        exit 1
    fi
done

if find "$prefix" \( -name '*.dylib' -o -name '*.framework' \) -print -quit |
        grep -q .; then
    echo "Static prefix contains a dynamic library or framework:" >&2
    find "$prefix" \( -name '*.dylib' -o -name '*.framework' \) -print >&2
    exit 1
fi

archives=()
while IFS= read -r archive; do
    archives+=("$archive")
done < <(find "$prefix" -type f -name '*.a' -print | sort)

if ((${#archives[@]} == 0)); then
    echo "No static archives found in prefix: $prefix" >&2
    exit 1
fi

if [[ -d "${prefix}/share/libjpeg-turbo" ]]; then
    for jpeg_archive in \
            "${prefix}/lib/libjpeg.a" \
            "${prefix}/lib/libturbojpeg.a"; do
        if [[ ! -f "$jpeg_archive" ]]; then
            echo "libjpeg-turbo package is missing: $jpeg_archive" >&2
            exit 1
        fi
        jpeg_members="$(ar -t "$jpeg_archive")"
        if ! grep -Eq '(^|/)jsimd\.c\.o$' <<<"$jpeg_members"; then
            echo "$jpeg_archive: arm64 SIMD dispatcher is missing" >&2
            exit 1
        fi
        if ! grep -Eq '(^|/)[A-Za-z0-9_-]+-neon\.c\.o$' \
                <<<"$jpeg_members"; then
            echo "$jpeg_archive: NEON implementation objects are missing" >&2
            exit 1
        fi
    done
fi

temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT
object_count=0

for archive in "${archives[@]}"; do
    archive_archs="$(lipo -archs "$archive")"
    if [[ "$archive_archs" != arm64 ]]; then
        echo "${archive}: expected only arm64, got '${archive_archs}'" >&2
        exit 1
    fi

    archive_name="$(basename "$archive" .a)"
    extract_dir="${temporary_root}/${archive_name}-${object_count}"
    mkdir -p "$extract_dir"
    (
        cd "$extract_dir"
        ar -x "$archive"
    )

    objects=()
    while IFS= read -r object; do
        objects+=("$object")
    done < <(
        find "$extract_dir" -type f ! -name '__.SYMDEF*' -print | sort
    )
    if ((${#objects[@]} == 0)); then
        echo "${archive}: archive is empty" >&2
        exit 1
    fi

    for object in "${objects[@]}"; do
        if ! file "$object" | grep -q 'Mach-O 64-bit.*arm64'; then
            echo "${archive}: non-arm64 Mach-O member: $(file "$object")" >&2
            exit 1
        fi
        build_info="$(xcrun vtool -show-build "$object")"
        if ! grep -Eq "platform[[:space:]]+${expected_platform}$" \
                <<<"$build_info"; then
            echo "${archive}: member has the wrong build platform" >&2
            echo "$build_info" >&2
            exit 1
        fi
        if ! grep -Eq 'minos[[:space:]]+16\.4([[:space:]]|$)' \
                <<<"$build_info"; then
            echo "${archive}: member does not declare min iOS 16.4" >&2
            echo "$build_info" >&2
            exit 1
        fi
        ((object_count += 1))
    done
done

echo "Validated ${#archives[@]} static archives and ${object_count} Mach-O members"
echo "platform=${expected_platform}, architecture=arm64, minos=16.4"
