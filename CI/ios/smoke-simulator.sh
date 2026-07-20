#!/usr/bin/env bash

set -euo pipefail

[[ $# -eq 2 ]] || {
    echo "Usage: $0 <path-to-OpenMW.app> <log-directory>" >&2
    exit 64
}

app="$1"
log_dir="$2"
mkdir -p "$log_dir"

plist="${app}/Info.plist"
bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist")
executable_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist")
devices_json="${log_dir}/available-simulators.json"
xcrun simctl list devices available --json >"$devices_json"

read -r udid initial_state device_name < <(
    python3 - "$devices_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    devices_by_runtime = json.load(handle)["devices"]

candidates = []
for runtime, devices in devices_by_runtime.items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            priority = 0 if device.get("state") == "Booted" else 1
            candidates.append((priority, runtime, device["name"], device["udid"], device["state"]))

if not candidates:
    raise SystemExit("No available iPhone Simulator was found")

_, _, name, udid, state = sorted(candidates)[0]
print(udid, state, name.replace(" ", "_"))
PY
)

device_name="${device_name//_/ }"
echo "Selected simulator: ${device_name} (${udid}), initial state: ${initial_state}"

booted_here=0
bootstatus_pid=0
cleanup() {
    if [[ "$bootstatus_pid" -ne 0 ]]; then
        kill "$bootstatus_pid" >/dev/null 2>&1 || true
        wait "$bootstatus_pid" >/dev/null 2>&1 || true
    fi
    xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
    if [[ "$booted_here" -eq 1 ]]; then
        xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

if [[ "$initial_state" != "Booted" ]]; then
    xcrun simctl boot "$udid"
    booted_here=1
fi

bootstatus_log="${log_dir}/simulator-bootstatus.log"
xcrun simctl bootstatus "$udid" -b >"$bootstatus_log" 2>&1 &
bootstatus_pid=$!
boot_deadline=$((SECONDS + 300))

while kill -0 "$bootstatus_pid" >/dev/null 2>&1; do
    if ((SECONDS >= boot_deadline)); then
        echo "Simulator did not finish booting within 300 seconds" >&2
        cat "$bootstatus_log" >&2
        exit 1
    fi
    sleep 5
done

if ! wait "$bootstatus_pid"; then
    echo "simctl bootstatus failed" >&2
    cat "$bootstatus_log" >&2
    exit 1
fi
bootstatus_pid=0
cat "$bootstatus_log"

xcrun simctl install "$udid" "$app"
xcrun simctl get_app_container "$udid" "$bundle_id" app \
    | tee "${log_dir}/installed-app-container.log"

launch_output="${log_dir}/simctl-launch.log"
if ! xcrun simctl launch --terminate-running-process "$udid" "$bundle_id" \
    2>&1 | tee "$launch_output"; then
    echo "simctl failed to launch ${bundle_id}" >&2
    exit 1
fi

sleep 10

xcrun simctl spawn "$udid" log show \
    --last 2m \
    --info \
    --style compact \
    --predicate "subsystem == \"org.openmw.ios.bootstrap\"" \
    >"${log_dir}/openmw-unified.log" 2>&1

if ! grep -Fq "G0 bootstrap view is visible" "${log_dir}/openmw-unified.log"; then
    echo "Expected OpenMW unified-log marker was not captured" >&2
    cat "${log_dir}/openmw-unified.log" >&2
    exit 1
fi

xcrun simctl io "$udid" screenshot "${log_dir}/openmw-simulator.png"

if ! xcrun simctl spawn "$udid" launchctl list \
    | grep -F "$bundle_id" \
    >"${log_dir}/launchctl-openmw.log"; then
    echo "OpenMW did not remain running for the 10-second smoke window" >&2
    exit 1
fi

echo "Simulator smoke passed for ${bundle_id}"
