#!/usr/bin/env python3
"""Verify one published asset set, then update Scoop and Nix together."""
import argparse
import base64
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

REPOSITORY = "nostalume/shed"
ARTIFACTS = {
    "x86_64-linux": "shed-linux-x86_64",
    "aarch64-linux": "shed-linux-aarch64",
    "x86_64-darwin": "shed-macos-x86_64",
    "aarch64-darwin": "shed-macos-aarch64",
    "windows": "shed-windows-x86_64.exe",
}


def version_number(value):
    version = value.removeprefix("v")
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("version must be MAJOR.MINOR.PATCH, optionally prefixed by v")
    return version, tuple(map(int, version.split(".")))


def replace_one(text, pattern, replacement):
    updated, count = re.subn(pattern, replacement, text)
    if count != 1:
        raise ValueError(f"expected exactly one catalog field: {pattern}")
    return updated


def update(root, release, read_asset):
    version, number = version_number(release)
    scoop_path = root / "shed.json"
    nix_path = root / "nix/shed.nix"
    scoop = json.loads(scoop_path.read_text(encoding="utf-8"))
    nix = nix_path.read_text(encoding="utf-8")
    versions = re.findall(r'(?m)^[ \t]*version = "([^"]+)";', nix)
    if len(versions) != 1:
        raise ValueError("expected one Nix package version")
    if number < max(version_number(v)[1] for v in [scoop["version"], versions[0]]):
        print(f"Skipping stale release v{version}")
        return False

    hashes = {}
    for platform, name in ARTIFACTS.items():
        checksum = read_asset(name + ".sha256").decode("ascii").strip()
        match = re.fullmatch(r"([0-9a-fA-F]{64}) [ *]" + re.escape(name), checksum)
        if match is None:
            raise ValueError(f"invalid checksum record for {name}")
        digest = hashlib.sha256(read_asset(name)).digest()
        if digest.hex() != match[1].lower():
            raise ValueError(f"checksum mismatch for {name}")
        hashes[platform] = digest

    scoop["version"] = version
    windows = ARTIFACTS["windows"]
    base = f"https://github.com/{REPOSITORY}/releases/download"
    scoop["architecture"]["64bit"].update(
        url=f"{base}/v{version}/{windows}#/shed.exe",
        hash=hashes["windows"].hex(),
    )
    scoop["autoupdate"]["architecture"]["64bit"].update(
        url=f"{base}/v$version/{windows}#/shed.exe",
        hash={"url": f"{base}/v$version/{windows}.sha256"},
    )
    nix = replace_one(nix, r'(?m)^([ \t]*version = ")[^"]+(";)',
                      lambda m: m[1] + version + m[2])
    for platform in ARTIFACTS.keys() - {"windows"}:
        sri = "sha256-" + base64.b64encode(hashes[platform]).decode("ascii")
        pattern = rf'(?m)^([ \t]*"{platform}"[ \t]*=[^\n]*hash = ")[^"]+("[^\n]*)'
        nix = replace_one(nix, pattern, lambda m: m[1] + sri + m[2])

    # Complete all downloads, checks and rendering before either file changes.
    rendered = json.dumps(scoop, ensure_ascii=False, indent=2) + "\n"
    if rendered == scoop_path.read_text(encoding="utf-8") and nix == nix_path.read_text(encoding="utf-8"):
        return False
    for path, text in [(scoop_path, rendered), (nix_path, nix)]:
        with path.open("w", encoding="utf-8", newline="\n") as output:
            output.write(text)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--assets-dir", type=Path, help="verify already downloaded assets")
    args = parser.parse_args()
    version, _ = version_number(args.version)
    base = f"https://github.com/{REPOSITORY}/releases/download/v{version}"

    def read_asset(name):
        if args.assets_dir is not None:
            return (args.assets_dir / name).read_bytes()
        request = urllib.request.Request(f"{base}/{name}", headers={"User-Agent": "shed-package-updater"})
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read()

    changed = update(Path(__file__).resolve().parent.parent, version, read_asset)
    print(f"Catalogs {'updated' if changed else 'unchanged'} for v{version}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        sys.exit(f"package update failed: {error}")
