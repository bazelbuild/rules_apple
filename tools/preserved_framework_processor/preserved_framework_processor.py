# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
"""Copies the runtime subset of a framework without mutating it."""

from __future__ import annotations

import argparse
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import datetime
import os
from pathlib import Path
import re
import shutil
import subprocess

_FRAMEWORK_VERSION_RE = re.compile(r"@rpath/.*\.framework/Versions/([^/]+)/")
_ZIP_EPOCH_YEAR = 2000


@dataclass(frozen=True, slots=True)
class ProcessorConfig:
    framework_binary: Path
    framework_files: tuple[Path, ...]
    temp_path: Path
    output_zip: Path


def _find_framework_root(path: Path) -> Path:
    """Returns the .framework root for a path inside a framework bundle."""
    for candidate in (path, *path.parents):
        if candidate.suffix == ".framework":
            return candidate
    raise ValueError(f"Could not determine framework directory for {path}")


def _relative_to_framework(path: Path) -> Path:
    """Returns a path relative to the root of the framework bundle."""
    return path.relative_to(_find_framework_root(path))


def _is_versioned_file(path: Path, version: str | None = None) -> bool:
    """Returns True if the file belongs to a versioned framework path."""
    relative_path = _relative_to_framework(path)
    parts = relative_path.parts
    if len(parts) < 2 or parts[0] != "Versions":
        return False
    return version is None or parts[1] == version


def _get_install_path_for_binary(binary: Path) -> str:
    """Returns the Mach-O install path for a dylib/framework binary."""
    result = subprocess.run(
        ["otool", "-D", "-X", os.fspath(binary)],
        check=True,
        capture_output=True,
        text=True,
    )
    install_path = result.stdout.strip()
    if not install_path.startswith("@rpath/"):
        raise ValueError(
            "Could not find framework binary install path with otool:\n"
            f"Framework binary: {binary}\n"
        )
    return install_path


def _get_framework_version_from_install_path(binary: Path) -> str:
    """Returns the framework version inferred from the binary install path."""
    install_path = _get_install_path_for_binary(binary)
    match = _FRAMEWORK_VERSION_RE.match(install_path)
    if match is None:
        raise ValueError(
            "Framework binary install path does not match regular expression:\n"
            f"Framework binary: {binary}\n"
            f"Binary install path: {install_path}\n"
            f"Expected to match regular expression: {_FRAMEWORK_VERSION_RE.pattern}"
        )
    return match.group(1)


def _try_get_framework_version_from_structure(framework_directory: Path) -> str | None:
    """Returns the framework version when the bundle structure contains one."""
    versions = [
        child.name
        for child in (framework_directory / "Versions").iterdir()
        if child.name != "Current"
    ]
    if len(versions) != 1:
        return None
    return versions[0]


def _zip_timestamp() -> float:
    """Returns the local ZIP epoch timestamp used for deterministic archives."""
    local_tz = datetime.now().astimezone().tzinfo
    if local_tz is None:
        raise ValueError("Could not determine local timezone")
    return datetime(_ZIP_EPOCH_YEAR, 1, 1, tzinfo=local_tz).timestamp()


def _update_modified_timestamps(framework_temp_path: Path) -> None:
    """Normalizes modified times before zipping for deterministic output."""
    if not framework_temp_path.exists():
        return

    timestamp = _zip_timestamp()
    for root, dirs, files in os.walk(framework_temp_path, topdown=False):
        root_path = Path(root)
        for entry_name in [*dirs, *files]:
            entry_path = root_path / entry_name
            os.utime(
                entry_path,
                (timestamp, timestamp),
                follow_symlinks=not entry_path.is_symlink(),
            )
    os.utime(framework_temp_path, (timestamp, timestamp))


def _copy_framework_file(
    source: Path,
    output_path: Path,
    *,
    relative_path: Path | None = None,
) -> Path:
    """Copies a framework file while preserving file mode."""
    destination_relative_path = (
        relative_path if relative_path is not None else _relative_to_framework(source)
    )
    destination = output_path / destination_relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    shutil.copymode(source, destination)
    return destination


def _versioned_symlink_target(entry: str) -> Path:
    """Returns the canonical top-level symlink target for a versioned framework."""
    return Path("Versions") / "Current" / entry


def _versioned_runtime_entries(
    framework_files: Iterable[Path],
    version: str,
) -> set[str]:
    """Returns top-level runtime entries represented by versioned files."""
    entries: set[str] = set()

    for framework_file in framework_files:
        relative_path = _relative_to_framework(framework_file)
        parts = relative_path.parts
        if len(parts) < 3 or parts[0] != "Versions" or parts[1] != version:
            continue

        entry = parts[2]
        if entry == "_CodeSignature":
            continue

        entries.add(entry)

    return entries


def _copy_versioned_framework(
    config: ProcessorConfig,
    framework_directory: Path,
    framework_name: str,
) -> None:
    """Copies the effective version of a versioned framework."""
    version = _try_get_framework_version_from_structure(framework_directory)
    if version is None:
        version = _get_framework_version_from_install_path(config.framework_binary)

    version_relative_dir = Path("Versions") / version
    _copy_framework_file(
        config.framework_binary,
        config.temp_path,
        relative_path=version_relative_dir / framework_name,
    )

    for framework_file in config.framework_files:
        if _is_versioned_file(framework_file, version):
            _copy_framework_file(framework_file, config.temp_path)

    versions_dir = config.temp_path / "Versions"
    versions_dir.mkdir(parents=True, exist_ok=True)
    (versions_dir / "Current").symlink_to(version)

    version_output_dir = config.temp_path / version_relative_dir
    runtime_entries = _versioned_runtime_entries(config.framework_files, version)
    runtime_entries.add(framework_name)

    for entry in sorted(runtime_entries):
        if not (version_output_dir / entry).exists():
            continue
        top_level_entry = config.temp_path / entry
        if top_level_entry.exists() or top_level_entry.is_symlink():
            continue
        top_level_entry.symlink_to(_versioned_symlink_target(entry))


def _get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="preserved framework processor")
    parser.add_argument(
        "--framework_binary",
        type=str,
        required=True,
        help="path to the framework binary",
    )
    parser.add_argument(
        "--framework_file",
        type=str,
        default=[],
        action="append",
        help="path to a runtime framework file",
    )
    parser.add_argument(
        "--temp_path",
        type=str,
        required=True,
        help="temporary directory to copy framework files to",
    )
    parser.add_argument(
        "--output_zip",
        type=str,
        required=True,
        help="path to save the zip file containing the preserved framework",
    )
    return parser


def _parse_args(argv: Sequence[str] | None = None) -> ProcessorConfig:
    args = _get_parser().parse_args(argv)
    return ProcessorConfig(
        framework_binary=Path(args.framework_binary),
        framework_files=tuple(Path(path) for path in args.framework_file),
        temp_path=Path(args.temp_path),
        output_zip=Path(args.output_zip),
    )


def _prepare_output_paths(config: ProcessorConfig) -> None:
    """Removes stale output paths and prepares the temp directory."""
    if config.temp_path.exists():
        shutil.rmtree(config.temp_path)
    if config.output_zip.exists():
        config.output_zip.unlink()
    config.temp_path.mkdir(parents=True)


def _create_output_zip(config: ProcessorConfig) -> None:
    """Archives the preserved framework into the expected output zip."""
    subprocess.run(
        [
            "/usr/bin/ditto",
            "-c",
            "-k",
            "--keepParent",
            "--norsrc",
            "--noextattr",
            os.fspath(config.temp_path),
            os.fspath(config.output_zip),
        ],
        check=True,
    )


def main(argv: Sequence[str] | None = None) -> int:
    config = _parse_args(argv)
    _prepare_output_paths(config)

    framework_inputs = (*config.framework_files, config.framework_binary)
    framework_directory = _find_framework_root(config.framework_binary)
    framework_name = framework_directory.stem
    is_versioned = any(_is_versioned_file(path) for path in framework_inputs)

    if is_versioned:
        _copy_versioned_framework(config, framework_directory, framework_name)
    else:
        _copy_framework_file(config.framework_binary, config.temp_path)
        for framework_file in config.framework_files:
            _copy_framework_file(framework_file, config.temp_path)

    _update_modified_timestamps(config.temp_path)
    _create_output_zip(config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
