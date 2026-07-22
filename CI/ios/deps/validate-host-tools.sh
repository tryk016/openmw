#!/usr/bin/env bash
set -euo pipefail

if (($# != 5)); then
    echo "Usage: validate-host-tools.sh PROFILE INSTALL_ROOT HOST_TRIPLET TARGET_PREFIX INSTALLED_JSON" >&2
    exit 2
fi

profile="$1"
install_root="$2"
host_triplet="$3"
target_prefix="$4"
installed_json="$5"

case "$profile" in
    language-foundation|ui-foundation|multimedia-foundation) ;;
    *) exit 0 ;;
esac

for command in file find jq sort; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command is unavailable: $command" >&2
        exit 1
    fi
done

host_prefix="${install_root}/${host_triplet}"
host_tool_root="${host_prefix}/tools/icu"
if [[ ! -d "$host_tool_root" ]]; then
    echo "The ICU host tool root is missing: $host_tool_root" >&2
    exit 1
fi
if [[ ! -f "${host_tool_root}/config/icucross.mk" ||
        ! -f "${host_tool_root}/config/icucross.inc" ]]; then
    echo "The ICU host cross-build metadata is incomplete" >&2
    exit 1
fi

expected_tools=(
    genbrk
    genccode
    gencfu
    gencmn
    gencnval
    gendict
    gennorm2
    genrb
    gensprep
    icuexportdata
    icuinfo
    icupkg
    makeconv
    pkgdata
)

actual_tools=()
while IFS= read -r candidate; do
    if file "$candidate" | grep -q 'Mach-O 64-bit.*arm64'; then
        actual_tools+=("$(basename "$candidate")")
    fi
done < <(find "${host_tool_root}/bin" -maxdepth 1 -type f -print | sort)

expected_list="$(printf '%s\n' "${expected_tools[@]}" | sort)"
actual_list="$(printf '%s\n' "${actual_tools[@]}" | sort)"
if [[ "$actual_list" != "$expected_list" ]]; then
    echo "Unexpected ICU host tool set" >&2
    diff -u <(printf '%s\n' "$expected_list") \
        <(printf '%s\n' "$actual_list") >&2 || true
    exit 1
fi

for tool in "${expected_tools[@]}"; do
    tool_path="${host_tool_root}/bin/${tool}"
    if [[ ! -x "$tool_path" ]]; then
        echo "ICU host tool is not executable: $tool_path" >&2
        exit 1
    fi
done
if ! "${host_tool_root}/bin/icuinfo" -v 2>&1 |
        grep -Eq '(^|[^0-9])70\.1([^0-9]|$)'; then
    echo "The ICU host tools do not report version 70.1" >&2
    exit 1
fi

if ! jq -e --arg triplet "$host_triplet" '
        any(to_entries[].value;
            .package_name == "icu" and
            .triplet == $triplet and
            .version == "70.1" and
            .port_version == 1 and
            ((.features // []) | index("tools") != null))
    ' "$installed_json" >/dev/null; then
    echo "The installed-package graph does not contain icu[tools] 70.1#1 for the host" >&2
    exit 1
fi

if find "$target_prefix" -type f \
        \( -path '*/tools/icu/*' -o -path '*/bin/icu*' \
        -o -path '*/bin/gen*' -o -path '*/sbin/*' \) \
        -print -quit | grep -q .; then
    echo "An ICU build tool leaked into the iOS target prefix" >&2
    exit 1
fi

echo "Validated ICU 70.1#1 host tools and target/host separation"
