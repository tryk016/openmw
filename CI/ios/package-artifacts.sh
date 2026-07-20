#!/usr/bin/env bash

set -euo pipefail

[[ $# -eq 6 ]] || {
    echo "Usage: $0 <device-app> <simulator-app> <device-dsym> <simulator-dsym> <log-dir> <output-dir>" >&2
    exit 64
}

device_app="$1"
simulator_app="$2"
device_dsym="$3"
simulator_dsym="$4"
log_dir="$5"
output_dir="$6"

for required_path in "$device_app" "$simulator_app" "$device_dsym" "$simulator_dsym"; do
    [[ -e "$required_path" ]] || {
        echo "Required packaging input does not exist: $required_path" >&2
        exit 1
    }
done

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
staging_dir="${output_dir}/staging"

mkdir -p "${staging_dir}/Payload" "${output_dir}/logs"
ditto "$device_app" "${staging_dir}/Payload/OpenMW.app"

(
    cd "$staging_dir"
    ditto -c -k --sequesterRsrc --keepParent Payload "${output_dir}/OpenMW-iOS-unsigned.ipa"
)

ditto -c -k --sequesterRsrc --keepParent \
    "$simulator_app" "${output_dir}/OpenMW-iOS-Simulator.app.zip"
ditto -c -k --sequesterRsrc --keepParent \
    "$device_dsym" "${output_dir}/OpenMW-iOS-device.dSYM.zip"
ditto -c -k --sequesterRsrc --keepParent \
    "$simulator_dsym" "${output_dir}/OpenMW-iOS-simulator.dSYM.zip"

if [[ -d "$log_dir" ]]; then
    ditto "$log_dir" "${output_dir}/logs"
fi

(
    cd "$output_dir"
    shasum -a 256 \
        OpenMW-iOS-unsigned.ipa \
        OpenMW-iOS-Simulator.app.zip \
        OpenMW-iOS-device.dSYM.zip \
        OpenMW-iOS-simulator.dSYM.zip \
        >SHA256SUMS
)

DEVICE_APP="$device_app" \
SIMULATOR_APP="$simulator_app" \
OUTPUT_DIR="$output_dir" \
python3 <<'PY'
import hashlib
import json
import os
import pathlib
import platform
import plistlib
import subprocess

output_dir = pathlib.Path(os.environ["OUTPUT_DIR"])
device_app = pathlib.Path(os.environ["DEVICE_APP"])
simulator_app = pathlib.Path(os.environ["SIMULATOR_APP"])

def command(*args):
    return subprocess.check_output(args, text=True).strip()

def plist(app):
    with (app / "Info.plist").open("rb") as handle:
        return plistlib.load(handle)

def checksum(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

artifact_names = [
    "OpenMW-iOS-unsigned.ipa",
    "OpenMW-iOS-Simulator.app.zip",
    "OpenMW-iOS-device.dSYM.zip",
    "OpenMW-iOS-simulator.dSYM.zip",
]

device_info = plist(device_app)
simulator_info = plist(simulator_app)
manifest = {
    "schema": 1,
    "source": {
        "repository": os.environ.get("GITHUB_REPOSITORY", ""),
        "commit": os.environ.get("GITHUB_SHA", ""),
        "ref": os.environ.get("GITHUB_REF", ""),
        "run_id": os.environ.get("GITHUB_RUN_ID", ""),
        "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", ""),
    },
    "runner": {
        "image": os.environ.get("ImageOS", "macos-15"),
        "image_version": os.environ.get("ImageVersion", ""),
        "architecture": platform.machine(),
        "xcode": command("xcodebuild", "-version"),
        "iphoneos_sdk": command("xcrun", "--sdk", "iphoneos", "--show-sdk-version"),
        "iphonesimulator_sdk": command("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"),
        "cmake": command("cmake", "--version").splitlines()[0],
    },
    "build": {
        "configuration": "Debug",
        "deployment_target": "16.4",
        "code_signing_allowed": False,
        "smoke_outcome": os.environ.get("SMOKE_OUTCOME", "unknown"),
    },
    "bundle": {
        "identifier": device_info.get("CFBundleIdentifier", ""),
        "version": device_info.get("CFBundleShortVersionString", ""),
        "build": device_info.get("CFBundleVersion", ""),
        "device_supported_platforms": device_info.get("CFBundleSupportedPlatforms", []),
        "simulator_supported_platforms": simulator_info.get("CFBundleSupportedPlatforms", []),
    },
    "artifacts": [
        {
            "name": name,
            "bytes": (output_dir / name).stat().st_size,
            "sha256": checksum(output_dir / name),
        }
        for name in artifact_names
    ],
}

with (output_dir / "manifest.json").open("w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

rm -rf "$staging_dir"
echo "Packaged unsigned IPA, simulator app, dSYMs, logs, checksums, and manifest in ${output_dir}"
