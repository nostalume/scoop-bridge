#!/usr/bin/env bash
# Update package manifests and create the matching annotated Git tag.
# Usage: ./scripts/release.sh 0.1.7
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 VERSION" >&2
    exit 2
fi

version="${1#v}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "release version must be MAJOR.MINOR.PATCH" >&2
    exit 2
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "release requires a clean working tree" >&2
    exit 1
fi

branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
    echo "release must run from the main branch" >&2
    exit 1
fi

python3 - "$version" <<'PY'
import re
import sys
from pathlib import Path

version = sys.argv[1]

cargo = Path("Cargo.toml")
text = cargo.read_text()
updated, count = re.subn(
    r'(?m)^(version[ \t]*=[ \t]*")[^"]+("[ \t]*)$',
    rf'\g<1>{version}\g<2>',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Cargo.toml package version was not found")
cargo.write_text(updated)

lock = Path("Cargo.lock")
text = lock.read_text()
updated, count = re.subn(
    r'(?ms)(\[\[package\]\][ \t]*\r?\nname = "shed"[ \t]*\r?\nversion = ")[^"]+("[ \t]*)',
    rf'\g<1>{version}\g<2>',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Cargo.lock shed package version was not found")
lock.write_text(updated)

nix_file = Path("nix/shed.nix")
text = nix_file.read_text()
updated, count = re.subn(
    r'(?m)^([ \t]*version[ \t]*=[ \t]*")[^"]+("[ \t]*;[ \t]*\r?)$',
    rf'\g<1>{version}\g<2>',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("nix/shed.nix version was not found")
nix_file.write_text(updated)
PY

cargo check --locked
git add Cargo.toml Cargo.lock nix/shed.nix
if ! git diff --cached --quiet; then
    git commit -m "chore: release v${version}"
fi

git tag -a "v${version}" -m "Release v${version}"
git push --atomic origin "HEAD:${branch}" "v${version}"
echo "released v${version}"
