#!/usr/bin/env bash

set -euo pipefail

[[ $# -eq 3 ]] || {
    echo "Usage: $0 <device|simulator> <path-to-OpenMW.app> <path-to-OpenMW.app.dSYM>" >&2
    exit 64
}

platform="$1"
app="$2"
dsym="$3"

plist="${app}/Info.plist"
[[ -f "$plist" ]] || {
    echo "Info.plist not found in $app" >&2
    exit 1
}

executable_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist")
binary="${app}/${executable_name}"
dsym_binary="${dsym}/Contents/Resources/DWARF/${executable_name}"

[[ -f "$binary" ]] || {
    echo "Bundle executable not found: $binary" >&2
    exit 1
}
[[ -f "$dsym_binary" ]] || {
    echo "dSYM executable not found: $dsym_binary" >&2
    exit 1
}

binary_uuid=$(xcrun dwarfdump --uuid "$binary" | awk 'NR == 1 { print $2 }')
dsym_uuid=$(xcrun dwarfdump --uuid "$dsym_binary" | awk 'NR == 1 { print $2 }')

if [[ -z "$binary_uuid" || "$binary_uuid" != "$dsym_uuid" ]]; then
    echo "dSYM UUID mismatch for ${platform}: binary=${binary_uuid:-missing}, dSYM=${dsym_uuid:-missing}" >&2
    exit 1
fi

if ! nm -gj "$dsym_binary" | c++filt | grep -F "OpenMW::IOS::bootstrapStatus" >/dev/null; then
    echo "C++ bootstrapStatus symbol was not found in the ${platform} dSYM" >&2
    exit 1
fi

lldb_log=$(mktemp)
trap 'rm -f "$lldb_log"' EXIT

xcrun lldb --batch \
    -o "target create \"$binary\"" \
    -o "breakpoint set --func-regex bootstrapStatus" \
    -o "breakpoint list" \
    >"$lldb_log" 2>&1

cat "$lldb_log"

if ! grep -Eq '([1-9][0-9]* locations?|where = .*bootstrapStatus)' "$lldb_log"; then
    echo "LLDB did not resolve a C++ breakpoint for ${platform}" >&2
    exit 1
fi

echo "${platform} dSYM matches ${binary_uuid}; C++ symbol and LLDB breakpoint resolved"
