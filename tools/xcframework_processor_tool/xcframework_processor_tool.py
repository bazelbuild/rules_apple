# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""Execution-phase XCFramework processing tool.

The XCFramework processor tool is an execution-phase time tool inspecting an
XCFramework bundle defined by the embedded Info.plist file containing
XCFramework library definitions.

This script takes an analysis time defined target triplet (platform,
architecture, and environment), and paths to an Info.plist file to validate
assumptions made at analysis time against.

An XCFramework Info.plist file defines each XCFramework library with the
following information:

  - LibraryIdentifier:
      References relative directory containing an Apple framework or library.
  - LibraryPath:
      References relative path to a framework bundle, or library.
  - HeadersPath:
      References (if available) a relative directory containing
      Objective-C(++)/Swift interface files.
  - BitcodeSymbolMapsPath:
      References (if available) a relative directory containing bitcode symbol
      map files.
  - SupportedArchitectures:
      List of supported architectures by library.
  - SupportedPlatforms:
      List of supported platforms by the library.
  - SupportedPlatformVariant:
      List of supported platform variants (e.g. simulator) if available.
"""

import argparse
import json
import plistlib
import sys
from typing import Any, Dict


def _create_args_parser() -> argparse.ArgumentParser:
  """Create parser and return parsed arguments."""
  parser = argparse.ArgumentParser(description="xcframework tool")

  value_args = {
      "architecture": "Target Apple architecture (e.g. x864_64, arm64).",
      "bundle_name": "The XCFramework bundle name (i.e. name.xcframework).",
      "environment": "Target Apple environment (e.g. device, simulator).",
      "library_identifier": "Assumed identifier for the platform we need.",
      "info_plist": "XCFramework Info.plist file.",
      "output_path": "Location to write the output file to on success.",
      "platform": "Target Apple platform (e.g. macos, ios).",
  }
  for arg_name, arg_help in value_args.items():
    parser.add_argument(
        f"--{arg_name}",
        type=str,
        required=True,
        action="store",
        help=arg_help)

  return parser


def _get_plist_dict(info_plist_path: str) -> Dict[str, Any]:
  """Returns dictionary from XCFramework Info.plist file content.

  Args:
    info_plist_path: XCFramework Info.plist file path to read from.
  Returns:
    Dictionary of parsed Info.plist contents.
  Raises:
    ValueError - if file does not contain XCFrameworkFormatVersion key.
  """
  with open(info_plist_path, "rb") as info_plist_file:
    info_plist_dict = plistlib.load(info_plist_file)
    if "XCFrameworkFormatVersion" not in info_plist_dict:
      raise ValueError(f"""
Info.plist file does not contain key: 'XCFrameworkFormatVersion'. Contents:

{info_plist_dict}

Is it an XCFramework Info.plist file?
""")

    return info_plist_dict


def _get_library_from_plist(
    *,
    architecture: str,
    environment: str,
    info_plist: Dict[str, Any],
    platform: str) -> Dict[str, Any]:
  """Returns an XCFramework library definition from XCFramework Info.plist file.

  Traverse XCFramework Info.plist libraries definitions to find a supported
  library for the given target triplet (platform, architecture, environment).

  Args:
    architecture: Target Apple architecture (e.g. x864_64, arm64).
    environment: Target Apple environment (e.g. device, simulator).
    info_plist: Parsed XCFramework Info.plist file contents.
    platform: Target Apple platform (e.g. macos, ios).
  Returns:
    Info.plist dictionary referencing target XCFramework library.
  Raises:
    ValueError - if no XCFramework library supporting target triplet is found.
  """
  available_libraries = info_plist.get("AvailableLibraries", [])
  for library in available_libraries:
    supported_platform = library.get("SupportedPlatform", [])
    if platform != supported_platform:
      continue

    supported_environment = library.get("SupportedPlatformVariant", [])
    if environment == "device" and supported_environment:
      continue
    if (environment != "device"
        and environment != supported_environment):
      continue

    supported_architectures = library.get("SupportedArchitectures", [])
    if architecture not in supported_architectures:
      continue

    return library

  library_identifiers = [
      library.get("LibraryIdentifier")
      for library in available_libraries
  ]
  raise ValueError(f"""
Imported XCFramework does not support the following platform:
  - platform: {platform}
  - architecture: {architecture}
  - environment: {environment}

Supported platforms: {library_identifiers}
""")


def main() -> int:
  args_parser = _create_args_parser()
  args = args_parser.parse_args()

  bundle_name = args.bundle_name
  info_plist = _get_plist_dict(args.info_plist)
  xcframework_library = _get_library_from_plist(
      architecture=args.architecture,
      environment=args.environment,
      info_plist=info_plist,
      platform=args.platform,
  )

  library_identifier = xcframework_library.get("LibraryIdentifier")
  if library_identifier != args.library_identifier:
    raise ValueError(f"""
Internal Error: Assumed library identifier for XCFramework {bundle_name} of \
{args.library_identifer} does not match the actual library identifier of \
{library_identifier}.

Please file a bug against the Apple BUILD Rules.
""")

  with open(args.output_path, "w+") as f:
    f.write("Success!")

  return 0

if __name__ == "__main__":
  sys.exit(main())
