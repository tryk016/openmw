#!/usr/bin/env bash
set -euo pipefail

lock_file=
installed_json=
profile=
target_triplet=
host_triplet=

usage() {
    cat <<'EOF'
Usage: validate-installed-closure.sh --lock FILE --installed-json FILE --profile NAME
       --target-triplet TRIPLET --host-triplet TRIPLET

Validates the exact installed target/host port and non-core feature closure.
Profiles without expected_vcpkg_transitive_ports retain legacy target-only
behaviour and ignore host-only installed-package records.
EOF
}

while (($#)); do
    case "$1" in
        --lock)
            lock_file="$2"
            shift 2
            ;;
        --installed-json)
            installed_json="$2"
            shift 2
            ;;
        --profile)
            profile="$2"
            shift 2
            ;;
        --target-triplet)
            target_triplet="$2"
            shift 2
            ;;
        --host-triplet)
            host_triplet="$2"
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

if [[ -z "$lock_file" || -z "$installed_json" || -z "$profile" ||
        -z "$target_triplet" || -z "$host_triplet" ]]; then
    usage >&2
    exit 2
fi
if [[ ! -f "$lock_file" ]]; then
    echo "Dependency lock does not exist: $lock_file" >&2
    exit 1
fi
if [[ ! -f "$installed_json" ]]; then
    echo "vcpkg installed-package JSON does not exist: $installed_json" >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "Required command is unavailable: jq" >&2
    exit 1
fi

strict=0
if jq -e --arg profile "$profile" \
        '(.expected_vcpkg_transitive_ports? // {}) | has($profile)' \
        "$lock_file" >/dev/null; then
    strict=1
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/openmw-ios-closure.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT
expected_raw="${temporary_root}/expected.raw"
expected_sorted="${temporary_root}/expected.sorted"
actual_raw="${temporary_root}/actual.raw"
actual_with_duplicates="${temporary_root}/actual.with-duplicates"
actual_sorted="${temporary_root}/actual.sorted"

jq -er --arg profile "$profile" '
    . as $lock
    | $lock.build_profiles[$profile][] as $dependency_name
    | first($lock.dependencies[] | select(.name == $dependency_name))
    | . as $dependency
    | "target|\($dependency.vcpkg_port)|@core",
      ($dependency.vcpkg_features[]? as $feature
        | "target|\($dependency.vcpkg_port)|\($feature)")
' "$lock_file" >"$expected_raw"

if ((strict)); then
    for scope in target host; do
        jq -r --arg profile "$profile" --arg scope "$scope" '
            .expected_vcpkg_transitive_ports[$profile][$scope][]
            | . as $entry
            | "\($scope)|\($entry.port)|@core",
              (($entry.features // [])[] as $feature
                | "\($scope)|\($entry.port)|\($feature)")
        ' "$lock_file" >>"$expected_raw"
    done
fi

LC_ALL=C sort "$expected_raw" >"$expected_sorted"
expected_duplicates="$(uniq -d "$expected_sorted")"
if [[ -n "$expected_duplicates" ]]; then
    echo "Dependency lock produces duplicate closure tuples:" >&2
    printf '%s\n' "$expected_duplicates" >&2
    exit 1
fi

if ! jq -er --arg target "$target_triplet" --arg host "$host_triplet" \
        --argjson strict "$strict" '
    to_entries[]
    | .value
    | if ((.package_name | type) != "string" or
          (.triplet | type) != "string" or
          (.version | type) != "string" or
          (.port_version | type) != "number" or
          (.features | type) != "array" or
          .port_version < 0 or
          .port_version != (.port_version | floor) or
          any(.features[]; type != "string")) then
        error("Malformed vcpkg list --x-json record")
      else . end
    | if .triplet == $target then
        "target"
      elif $strict == 1 and .triplet == $host then
        "host"
      elif $strict == 1 then
        error("Unexpected installed vcpkg triplet: \(.triplet)")
      else
        empty
      end as $scope
    | . as $package
    | "\($scope)|\($package.package_name)|@core",
      ($package.features[] as $feature
        | "\($scope)|\($package.package_name)|\($feature)")
' "$installed_json" >"$actual_raw"; then
    exit 1
fi

LC_ALL=C sort "$actual_raw" >"$actual_with_duplicates"
actual_duplicates="$(uniq -d "$actual_with_duplicates")"
if [[ -n "$actual_duplicates" ]]; then
    echo "vcpkg status contains duplicate installed closure tuples:" >&2
    printf '%s\n' "$actual_duplicates" >&2
    exit 1
fi
LC_ALL=C sort -u "$actual_raw" >"$actual_sorted"

if ! cmp -s "$expected_sorted" "$actual_sorted"; then
    echo "Unexpected installed vcpkg closure for profile '$profile'" >&2
    echo "Expected scope|port|feature tuples:" >&2
    sed 's/^/  /' "$expected_sorted" >&2
    echo "Installed scope|port|feature tuples:" >&2
    sed 's/^/  /' "$actual_sorted" >&2
    exit 1
fi
