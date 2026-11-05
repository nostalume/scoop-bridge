#!/usr/bin/env bash
# Update Cargo manifests and publish an annotated release tag.
# Usage: bash scripts/release.sh 0.1.7
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 VERSION" >&2
    exit 2
fi
version="${1#v}"
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "release version must be MAJOR.MINOR.PATCH" >&2
    exit 2
fi
worktree_status="$(git status --porcelain)"
if [[ -n "$worktree_status" ]]; then
    echo "release requires a clean working tree" >&2
    exit 1
fi
branch="$(git branch --show-current)"
if [[ "$branch" != main ]]; then
    echo "release must run from the main branch" >&2
    exit 1
fi
existing_tag="$(git tag --list "v$version")"
if [[ -n "$existing_tag" ]]; then
    echo "tag v$version already exists" >&2
    exit 1
fi

python3 - "$version" <<'PY'
import re
import sys
from pathlib import Path

patterns = {
    "Cargo.toml": r'(?m)^(version[ \t]*=[ \t]*")[^"]+("[ \t]*)$',
    "Cargo.lock": r'(?ms)(\[\[package\]\][ \t]*\r?\nname = "shed"[ \t]*\r?\nversion = ")[^"]+("[ \t]*)',
}
updates = {}
for name, pattern in patterns.items():
    updated, count = re.subn(pattern, lambda m: m[1] + sys.argv[1] + m[2], Path(name).read_text())
    if count != 1:
        raise SystemExit(f"expected one package version in {name}")
    updates[name] = updated
for name, text in updates.items():
    Path(name).write_text(text)
PY

cargo check --locked
git add Cargo.toml Cargo.lock
if git diff --cached --quiet; then
    :
else
    case $? in
        1) git commit -m "chore: release v${version}";;
        *) echo 'git diff failed' >&2; exit 1;;
    esac
fi
git tag -a "v${version}" -m "Release v${version}"
git push --atomic origin "HEAD:${branch}" "v${version}"
echo "released v${version}"
