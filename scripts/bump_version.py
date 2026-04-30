#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def replace_one(text: str, pattern: str, replacement: str, path: Path) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Expected to update exactly one match in {path}, got {count}")
    return updated


def update_file(path: Path, version: str) -> bool:
    original = path.read_text()
    updated = original

    if path.name == "Version.swift":
        updated = replace_one(
            updated,
            r'static let version = "\d+\.\d+\.\d+"',
            f'static let version = "{version}"',
            path,
        )
    elif path.name == "theme.json":
        data = json.loads(original)
        data["version"] = version
        updated = json.dumps(data, indent=2) + "\n"
    else:
        raise SystemExit(f"No update rule for {path}")

    if updated != original:
        path.write_text(updated)
        return True
    return False


def parse_version(version: str) -> tuple[int, int, int]:
    if not SEMVER_RE.fullmatch(version):
        raise SystemExit(f"Version must be X.Y.Z, got: {version}")
    major, minor, patch = version.split(".")
    return int(major), int(minor), int(patch)


def format_version(parts: tuple[int, int, int]) -> str:
    return ".".join(str(p) for p in parts)


def read_current_version(repo_root: Path) -> str:
    text = (repo_root / "Sources/BlogCLI/Version.swift").read_text()
    match = re.search(r'static let version = "(\d+\.\d+\.\d+)"', text)
    if not match:
        raise SystemExit("Could not find current version in Sources/BlogCLI/Version.swift")
    return match.group(1)


def increment_version(current_version: str, part: str) -> str:
    major, minor, patch = parse_version(current_version)
    if part == "major":
        return format_version((major + 1, 0, 0))
    if part == "minor":
        return format_version((major, minor + 1, 0))
    if part == "patch":
        return format_version((major, minor, patch + 1))
    raise SystemExit(f"Unsupported part: {part}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Bump the inkwell release version.")
    parser.add_argument("version", nargs="?", help="New version, e.g. 0.2.0")
    parser.add_argument(
        "--part",
        choices=["major", "minor", "patch"],
        help="Increment current version by one semantic version part.",
    )
    args = parser.parse_args()

    if args.version and args.part:
        raise SystemExit("Specify either an explicit version or --part, not both")
    if not args.version and not args.part:
        raise SystemExit("Provide either an explicit version or --part {major,minor,patch}")

    repo_root = Path(__file__).resolve().parent.parent
    managed_files = [
        repo_root / "Sources/BlogCLI/Version.swift",
        repo_root / "themes/default/theme.json",
        repo_root / "Sources/BlogThemes/Resources/themes/default/theme.json",
        repo_root / "Sources/BlogThemes/Resources/themes/quiet/theme.json",
    ]

    current_version = read_current_version(repo_root)
    target_version = args.version if args.version else increment_version(current_version, args.part)
    parse_version(target_version)

    changed_files: list[Path] = []
    for path in managed_files:
        if update_file(path, target_version):
            changed_files.append(path)

    if changed_files:
        print(f"Bumped {current_version} → {target_version} in:")
        for path in changed_files:
            print(f"  {path.relative_to(repo_root)}")
    else:
        print(f"No changes needed; already at {target_version}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
