#!/usr/bin/env python3

"""Scans Xcode developer frameworks and emits Bazel import targets."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Iterable

_BUILD_HEADER = """\
load("@rules_apple//apple:apple.bzl", "xcode_developer_framework_import")

package(default_visibility = ["//visibility:public"])

# Companion static archives that ship with this Xcode under usr/lib. Some
# Xcode developer frameworks need a usr/lib/*.a force-loaded for their runtime
# registrations to work (e.g. XcodeKit needs libXcodeExtension.a so
# XCExtensionSubsystem is registered). Apple does not publish this mapping;
# consumers wire the archives they need by wrapping the generated target with
# their own xcode_developer_framework_import that sets `linker_imports`. See
# the rule's documentation for an example.
exports_files(
    glob(
        ["usr/lib/**"],
        allow_empty = True,
        exclude_directories = 1,
    ),
)
"""


def _framework_target(framework_name: str) -> str:
    return f"""\

filegroup(
    name = "{framework_name}_framework_files",
    srcs = glob([
        "{framework_name}.framework/**",
    ], allow_empty = False),
)

xcode_developer_framework_import(
    name = "{framework_name}",
    framework_name = "{framework_name}",
    framework_imports = [":{framework_name}_framework_files"],
    dsym_imports = glob([
        "{framework_name}.framework.dSYM/**",
    ], allow_empty = True),
)
"""


def discover_frameworks(frameworks_dir: Path) -> list[str]:
    """Returns discovered framework basenames under a Developer/Library/Frameworks dir."""
    if not frameworks_dir.exists():
        raise FileNotFoundError(
            f"Developer frameworks directory does not exist: {frameworks_dir}"
        )
    if not frameworks_dir.is_dir():
        raise NotADirectoryError(
            f"Developer frameworks path is not a directory: {frameworks_dir}"
        )

    frameworks = []
    for child in frameworks_dir.iterdir():
        if child.is_dir() and child.suffix == ".framework":
            frameworks.append(child.stem)
    return sorted(frameworks)


def discover_usr_lib_files(usr_lib_dir: Path) -> list[str]:
    """Returns relative paths (under the repo root) for files in $DEVELOPER_DIR/usr/lib.

    Only regular files are reported; subdirectories are descended. Paths are
    returned with the `usr/lib/` prefix so they match the labels exported by the
    generated BUILD file.
    """
    if not usr_lib_dir.exists() or not usr_lib_dir.is_dir():
        return []

    files: list[str] = []
    for path in usr_lib_dir.rglob("*"):
        if not path.is_file():
            continue
        files.append(str(Path("usr/lib") / path.relative_to(usr_lib_dir)))
    return sorted(files)


def render_build(framework_names: Iterable[str]) -> str:
    framework_names = list(framework_names)
    return _BUILD_HEADER + "".join(
        _framework_target(framework_name) for framework_name in framework_names
    )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Scan Xcode developer frameworks under Developer/Library/Frameworks "
            "and generate apple_dynamic_framework_import targets."
        ),
    )
    parser.add_argument(
        "--output",
        "-o",
        required=True,
        type=Path,
        help="Path to write the generated BUILD file.",
    )
    parser.add_argument(
        "--framework-names",
        required=True,
        type=Path,
        help="Path to write a JSON manifest of generated framework target names.",
    )
    parser.add_argument(
        "--usr-lib-files",
        required=True,
        type=Path,
        help="Path to write a JSON manifest of usr/lib relative file paths.",
    )
    parser.add_argument(
        "--developer-dir",
        type=Path,
        default=None,
        help=(
            "Path to Xcode's Developer directory. If omitted, DEVELOPER_DIR is " "used."
        ),
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()

    developer_dir = args.developer_dir
    if developer_dir is None:
        developer_dir_env = os.environ.get("DEVELOPER_DIR")
        if not developer_dir_env:
            raise SystemExit(
                "error: --developer-dir was not provided and DEVELOPER_DIR is unset"
            )
        developer_dir = Path(developer_dir_env)

    frameworks_dir = developer_dir / "Library/Frameworks"
    framework_names = discover_frameworks(frameworks_dir)

    usr_lib_dir = developer_dir / "usr/lib"
    usr_lib_files = discover_usr_lib_files(usr_lib_dir)

    args.output.write_text(render_build(framework_names))
    args.framework_names.write_text(json.dumps(framework_names))
    args.usr_lib_files.write_text(json.dumps(usr_lib_files))


if __name__ == "__main__":
    main()
