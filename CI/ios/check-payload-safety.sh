#!/usr/bin/env bash

set -euo pipefail

[[ $# -ge 1 ]] || {
    echo "Usage: $0 <bundle-or-directory> [...]" >&2
    exit 64
}

failed=0

for root in "$@"; do
    [[ -e "$root" ]] || {
        echo "Safety scan root does not exist: $root" >&2
        exit 1
    }

    echo "Scanning payload safety: $root"

    while IFS= read -r path; do
        echo "Forbidden game-data or secret-like file: $path" >&2
        failed=1
    done < <(
        find "$root" -type f \( \
            -iname '*.esm' -o \
            -iname '*.esp' -o \
            -iname '*.bsa' -o \
            -iname '*.omwgame' -o \
            -iname '*.omwaddon' -o \
            -iname '*.p12' -o \
            -iname '*.mobileprovision' -o \
            -iname '*.p8' -o \
            -iname '*.pem' -o \
            -iname '*.key' -o \
            -iname '.env' -o \
            -iname '.env.*' \
        \) -print
    )

    if LC_ALL=C grep -R -I -n -E \
        '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{30,}' \
        "$root"; then
        echo "A high-confidence secret pattern was found under $root" >&2
        failed=1
    fi
done

while IFS= read -r tracked_path; do
    echo "Forbidden tracked game-data or secret-like file: $tracked_path" >&2
    failed=1
done < <(
    git ls-files | grep -Ei \
        '(^|/)([^/]+\.(esm|esp|bsa|omwgame|omwaddon|p12|mobileprovision|p8|pem|key)|\.env(\..*)?)$' \
        || true
)

if git grep -I -n -E \
    -e '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{30,}' \
    -- . ':(exclude)CI/ios/check-payload-safety.sh'; then
    echo "A high-confidence secret pattern was found in tracked files" >&2
    failed=1
fi

if [[ "$failed" -ne 0 ]]; then
    exit 1
fi

echo "No game data, provisioning profiles, private keys, or high-confidence secret patterns found"
