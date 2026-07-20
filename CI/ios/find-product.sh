#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 <device|simulator> <app|dsym> [search-root]" >&2
    exit 64
}

[[ $# -ge 2 && $# -le 3 ]] || usage

platform="$1"
product_type="$2"
search_root="${3:-.}"

case "$platform" in
    device)
        expected_platform="IOS"
        ;;
    simulator)
        expected_platform="IOSSIMULATOR"
        ;;
    *)
        usage
        ;;
esac

case "$product_type" in
    app)
        find_pattern="OpenMW.app"
        ;;
    dsym)
        find_pattern="OpenMW.app.dSYM"
        ;;
    *)
        usage
        ;;
esac

matches=()

while IFS= read -r -d '' candidate; do
    case "$product_type" in
        app)
            plist="${candidate}/Info.plist"
            [[ -f "$plist" ]] || continue
            executable_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist" 2>/dev/null || true)
            [[ -n "$executable_name" ]] || continue
            binary="${candidate}/${executable_name}"
            ;;
        dsym)
            binary="${candidate}/Contents/Resources/DWARF/OpenMW"
            ;;
    esac

    [[ -f "$binary" ]] || continue

    build_info=$(xcrun vtool -show-build "$binary" 2>/dev/null || true)
    if grep -Eq "platform[[:space:]]+${expected_platform}([[:space:]]|$)" <<<"$build_info"; then
        matches+=("$candidate")
    fi
done < <(
    find "$search_root" \
        \( -path "${search_root}/.git" -o -path "${search_root}/artifacts" \) -prune -o \
        -type d -name "$find_pattern" -print0
)

if [[ ${#matches[@]} -eq 0 ]]; then
    echo "No ${product_type} product for ${platform} (${expected_platform}) found under ${search_root}" >&2
    exit 1
fi

if [[ ${#matches[@]} -gt 1 ]]; then
    echo "Multiple ${product_type} products for ${platform} found; refusing an ambiguous package:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    exit 1
fi

cd "$(dirname "${matches[0]}")"
printf '%s/%s\n' "$PWD" "$(basename "${matches[0]}")"
