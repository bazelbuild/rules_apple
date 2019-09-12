#!/bin/bash
#
# Copyright 2018 The Bazel Authors. All rights reserved.
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
# swift_stdlib_tool copies the required Swift StdLib dylibs for the given
# binaries into the specified output path. This tool will also remove any
# architecture slices which are not used by the given binaries, reducing binary
# size.
#
# This script only runs on darwin and you must have Xcode installed.
#
# --output_path <path>       - the path to where the dylibs should be placed.
# --platform <platform>      - the target platform, e.g. 'iphoneos'
# --realpath <realpath_path> - the path to the realpath binary used to resolve
#                              symlinks.
# <positional_args>          - any positional argument is considered to be a
#                              path to a binary to be processed for Swift StdLib
#                              dylibs

set -eu

BINARIES+=()
while [[ $# -gt 0 ]]; do
  arg="$1"
  case $arg in
      --platform)
      readonly PLATFORM="$2"
      shift
      ;;
      --swift_dylibs_path)
      readonly SWIFT_DYLIBS_PATH="$2"
      shift
      ;;
      --output_path)
      readonly OUTPUT_PATH="$2"
      shift
      ;;
      --realpath)
      readonly REALPATH="$2"
      shift
      ;;
      *)
      BINARIES+=("$1")
      ;;
  esac
  shift
done

# Usage: get_binary_archs <binary_path>
#
# Inspects the given binary and returns the available architecture slices.
function get_binary_archs {
  lipo -info "$1" | \
      sed -En -e 's/^(Non-|Architectures in the )fat file: .+( is architecture| are): (.*)$/\3/p'
}

# Usage: copy_swift_stdlibs <output_path>
#
# Copies the Swift StdLib dylibs required by the binaries given to this script
# into the given output path.
function copy_swift_stdlibs {
  /usr/bin/xcrun swift-stdlib-tool \
      --copy \
      --source-libraries "$DEVELOPER_DIR/$SWIFT_DYLIBS_PATH/$PLATFORM" \
      --platform "$PLATFORM" \
      ${BINARIES[@]/#/--scan-executable } \
      --destination "$1"
}

# Usage: strip_dylibs <unstripped_dylibs_path> <output_path>
#
# Strips the Swift dylibs from architectures not present in the binaries given
# to this script. If the dylibs only contain a single architecture, they will be
# copied to the output path without stripping.
function strip_dylibs {
  local any_dylib=$(find "$1" -name *.dylib | head -n 1)

  if [[ -z "$any_dylib" ]]; then
    # Exit early if there are no dylibs to process.
    return 0
  fi

  local dylibs_archs=($(get_binary_archs "$any_dylib"))

  # If the dylib contains only 1 architecture, copy them as is, otherwise lipo
  # would complain.
  if [[ "${#dylibs_archs[@]}" == 1 ]]; then
    find "$1" \
        -name *.dylib \
        -execdir cp {} "$("$REALPATH" "$2")" \;
  else
    # Extract the binary architectures for all binaries within the bundle, to
    # get a complete view of the required architectures in the bundle.
    binary_archs=()
    for binary in "${BINARIES[@]}"; do
      for arch in $(get_binary_archs "$binary"); do
        binary_archs+=($arch)
      done
    done

    # Convert the list of architectures into a unique list.
    local unique_binary_archs=(
        $(echo "${binary_archs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    )

    local real_output_path=$("$REALPATH" "$2")
    find "$1" \
        -name *.dylib \
        -execdir \
        lipo ${unique_binary_archs[@]/#/-extract } -output "$real_output_path/{}" {} \;
  fi
}

# Create temporary location for the unstripped dylibs. They will be removed once
# the script ends.
readonly TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/swift_stdlib_tool.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

copy_swift_stdlibs "$TEMP_DIR"
strip_dylibs "$TEMP_DIR" "$OUTPUT_PATH"
