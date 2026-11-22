#!/usr/bin/env python3

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

"""Builds an exported-symbol list for a closed-world Apple framework.

The framework is assembled from static libraries, so every public definition
would normally be eligible for the Mach-O export trie and symbol table. This
tool keeps Swift definitions imported by declared clients, plus conservative
roots for symbols whose runtime uses cannot be proven from static references.
"""

import argparse
import json
import subprocess
from pathlib import Path

_NM_BATCH_SIZE = 128
_SWIFT_SYMBOL_PREFIX = "_$s"


def parse_nm_output(output: str) -> set[str]:
    """Returns externally visible Mach-O symbols from Darwin-format llvm-nm."""
    result = set()
    for line in output.splitlines():
        if " private external " in line or " external " not in line:
            continue

        # The symbol is always the final token. Native Swift objects may insert
        # annotations such as `[no dead strip]` after `external`.
        symbol = line.split()[-1]
        # Mach-O external names have a leading underscore. This also filters
        # archive headings and LLVM names that are not linkable symbols.
        if symbol.startswith("_"):
            result.add(symbol)
    return result


def _manifest_inputs(input_manifest: Path) -> list[str]:
    return [
        line
        for line in input_manifest.read_text(encoding="utf8").splitlines()
        if line
    ]


def symbols(
    nm_command: list[str], input_manifest: Path, *, defined: bool
) -> set[str]:
    """Collects defined or undefined externals from static link inputs."""
    inputs = _manifest_inputs(input_manifest)
    result = set()
    mode = "--defined-only" if defined else "--undefined-only"
    # Batch inputs to stay below the platform command-line length limit.
    for start in range(0, len(inputs), _NM_BATCH_SIZE):
        command = [
            *nm_command,
            "--extern-only",
            "--format=darwin",
            mode,
            *inputs[start : start + _NM_BATCH_SIZE],
        ]
        try:
            nm = subprocess.run(
                command,
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as error:
            raise RuntimeError(
                "llvm-nm failed for framework export analysis:\n"
                f"{error.stderr}"
            ) from error
        result.update(parse_nm_output(nm.stdout))
    return result


def read_additional_exports(paths: list[Path]) -> set[str]:
    """Reads authored runtime roots, ignoring blank and comment lines."""
    result = set()
    for path in paths:
        for line in path.read_text(encoding="utf8").splitlines():
            symbol = line.strip()
            if symbol and not symbol.startswith("#"):
                result.add(symbol)
    return result


def select_exports(
    defined_exports: set[str],
    client_imports: set[str],
    additional_exports: set[str],
    *,
    preserve_all_non_swift_exports: bool,
) -> tuple[set[str], set[str], set[str]]:
    """Applies the closed-world framework export policy.

    Returns the statically referenced exports, the conservatively retained
    non-Swift exports, and their union with authored runtime roots that are
    defined by the framework.
    """
    statically_used = defined_exports & client_imports
    non_swift_exports = set()
    if preserve_all_non_swift_exports:
        non_swift_exports = {
            symbol
            for symbol in defined_exports
            if not symbol.startswith(_SWIFT_SYMBOL_PREFIX)
        }
    defined_additional_exports = defined_exports & additional_exports
    return (
        statically_used,
        non_swift_exports,
        statically_used | non_swift_exports | defined_additional_exports,
    )


def export_report(
    *,
    additional_exports: set[str],
    allowlist: list[str],
    client_imports: set[str],
    client_input_count: int,
    defined_exports: set[str],
    framework_input_count: int,
    non_swift_exports: set[str],
    preserve_all_non_swift_exports: bool,
    statically_used: set[str],
) -> dict[str, object]:
    """Returns deterministic audit data for the selected export surface."""
    defined_additional_exports = additional_exports & defined_exports
    return {
        "additional_exports": len(additional_exports),
        "additional_export_symbols": sorted(defined_additional_exports),
        "allowlist_exports": len(allowlist),
        "allowlist_symbols": allowlist,
        "client_imports": len(client_imports),
        "client_inputs": client_input_count,
        "defined_exports": len(defined_exports),
        "framework_inputs": framework_input_count,
        "missing_additional_exports": sorted(
            additional_exports - defined_exports
        ),
        "non_swift_exports": len(non_swift_exports),
        "non_swift_export_symbols": sorted(non_swift_exports),
        "preserve_all_non_swift_exports": preserve_all_non_swift_exports,
        "statically_used_exports": len(statically_used),
        "statically_used_export_symbols": sorted(statically_used),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--framework-inputs", required=True, type=Path)
    parser.add_argument("--client-inputs", required=True, type=Path)
    parser.add_argument(
        "--additional-exported-symbols",
        action="append",
        default=[],
        type=Path,
    )
    parser.add_argument("--nm", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--preserve-all-non-swift-exports",
        action="store_true",
    )
    parser.add_argument("--report", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    nm_command = [str(args.nm)] if args.nm else ["/usr/bin/xcrun", "llvm-nm"]

    # Framework definitions are the maximum possible export surface. Undefined
    # references from client-only inputs prove which Swift symbols must cross
    # the framework boundary at runtime.
    defined_exports = symbols(nm_command, args.framework_inputs, defined=True)
    client_imports = symbols(nm_command, args.client_inputs, defined=False)
    additional_exports = read_additional_exports(args.additional_exported_symbols)
    statically_used, non_swift_exports, selected_exports = select_exports(
        defined_exports,
        client_imports,
        additional_exports,
        preserve_all_non_swift_exports=args.preserve_all_non_swift_exports,
    )
    allowlist = sorted(selected_exports)

    # Sorting makes the output deterministic. The report exposes each policy
    # bucket so adopters can audit why symbols were retained.
    output_text = "\n".join(allowlist)
    args.output.write_text(
        output_text + ("\n" if output_text else ""),
        encoding="utf8",
    )
    args.report.write_text(
        json.dumps(
            export_report(
                additional_exports=additional_exports,
                allowlist=allowlist,
                client_imports=client_imports,
                client_input_count=len(_manifest_inputs(args.client_inputs)),
                defined_exports=defined_exports,
                framework_input_count=len(
                    _manifest_inputs(args.framework_inputs)
                ),
                non_swift_exports=non_swift_exports,
                preserve_all_non_swift_exports=(
                    args.preserve_all_non_swift_exports
                ),
                statically_used=statically_used,
            ),
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf8",
    )


if __name__ == "__main__":
    main()
