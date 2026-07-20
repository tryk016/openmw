#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 <device|simulator> <path-to-OpenMW.app>" >&2
    exit 64
}

[[ $# -eq 2 ]] || usage

platform="$1"
app="$2"
deployment_target="16.4"

[[ -d "$app" ]] || {
    echo "App bundle does not exist: $app" >&2
    exit 1
}

plist="${app}/Info.plist"
[[ -f "$plist" ]] || {
    echo "Info.plist not found in $app" >&2
    exit 1
}

executable_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist")
binary="${app}/${executable_name}"
[[ -f "$binary" ]] || {
    echo "Bundle executable not found: $binary" >&2
    exit 1
}

case "$platform" in
    device)
        expected_build_platform="IOS"
        expected_supported_platform="iPhoneOS"
        expected_arch="arm64"
        ;;
    simulator)
        expected_build_platform="IOSSIMULATOR"
        expected_supported_platform="iPhoneSimulator"
        expected_arch="arm64"
        ;;
    *)
        usage
        ;;
esac

echo "Validating ${platform} bundle: ${app}"
file "$binary"

architectures=$(xcrun lipo -archs "$binary")
echo "Architectures: $architectures"
if ! grep -Eq "(^|[[:space:]])${expected_arch}([[:space:]]|$)" <<<"$architectures"; then
    echo "Expected ${expected_arch} architecture, got: ${architectures}" >&2
    exit 1
fi

build_info=$(xcrun vtool -show-build "$binary")
printf '%s\n' "$build_info"

if ! grep -Eq "platform[[:space:]]+${expected_build_platform}([[:space:]]|$)" <<<"$build_info"; then
    echo "Expected Mach-O platform ${expected_build_platform}" >&2
    exit 1
fi

minimum_os=$(awk '/^[[:space:]]*minos[[:space:]]+/ { print $2; exit }' <<<"$build_info")
if [[ "$minimum_os" != "$deployment_target" && "$minimum_os" != "${deployment_target}.0" ]]; then
    echo "Expected deployment target ${deployment_target}, got ${minimum_os:-<missing>}" >&2
    exit 1
fi

supported_platforms=$(/usr/libexec/PlistBuddy -c "Print :CFBundleSupportedPlatforms" "$plist" 2>/dev/null || true)
if [[ -n "$supported_platforms" ]] && ! grep -Fq "$expected_supported_platform" <<<"$supported_platforms"; then
    echo "Info.plist does not declare ${expected_supported_platform}" >&2
    exit 1
fi

plist_minimum_os=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$plist" 2>/dev/null || true)
if [[ -n "$plist_minimum_os" && "$plist_minimum_os" != "$deployment_target" && "$plist_minimum_os" != "${deployment_target}.0" ]]; then
    echo "Info.plist MinimumOSVersion is ${plist_minimum_os}, expected ${deployment_target}" >&2
    exit 1
fi

if [[ -e "${app}/embedded.mobileprovision" || -d "${app}/_CodeSignature" ]]; then
    echo "Signing material unexpectedly present in ${app}" >&2
    exit 1
fi

if [[ "$platform" == "device" ]] && codesign --display "$binary" >/dev/null 2>&1; then
    echo "The device executable is signed; G0 artifacts must be unsigned" >&2
    exit 1
fi

echo "${platform} bundle passed Mach-O, platform, architecture, deployment-target, and signing checks"
