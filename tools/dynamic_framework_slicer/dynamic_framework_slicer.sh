#!/bin/bash
#
# Copyright 2019 The Bazel Authors. All rights reserved.
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
# dynamic_framework_slicer copies the required dylibs for the given
# binaries into the specified output path. This tool will also remove any
# architecture slices which are not used by the given binaries, reducing binary
# size.
#
# This script only runs on darwin and you must have Xcode installed.
#
# --out <file>      - the filename where the resultant binary should be placed.
# --in <file>       - the filename of the input binary
# <positional_args> - any positional argument is considered to be a
#                              path to a binary to be processed

set -euo pipefail

declare -a BINARIES
IN=""
OUT=""
while [[ $# -gt 0 ]]; do
  arg="$1"
  case $arg in
      --in)
      readonly IN="$2"
      shift
      ;;
      --out)
      readonly OUT="$2"
      shift
      ;;
      *)
      BINARIES+=("$1")
      ;;
  esac
  shift
done

if [[ -z "$IN" || -z "$OUT" || "${#BINARIES[@]}" -eq 0 ]]; then
    echo "Usage: $0 --in path/to/infile --out path/to/outfile binaries..."
    exit 1
fi

if [[ ! -f "$IN" ]]; then
    echo "Expected regular file with --in"
    exit 1
fi

# Strip out any unnecessary slices from embedded dynamic frameworks to save space

# Gather all binary slices
all_bin_slices=$(xcrun lipo -info "${BINARIES[@]}" | cut -d: -f3 | tr ' ' '\n' | sort -u)

# Gather the slices in the framework
framework_slices=$(xcrun lipo -info "$IN" | cut -d: -f3 | tr ' ' '\n' | sort -u)

if [[ $(echo -n $framework_slices | wc -w) -eq 1 || "$all_bin_slices" == "$framework_slices" ]]; then
    # If we only have one slice or the slices match exactly, we don't need to do anything
    cp "$IN" "$OUT"
else
    # Figure out what we should strip
    declare -a slices_needed
    for slice in $framework_slices; do
        if echo "$all_bin_slices" | grep -q "$slice" ; then
            slices_needed+=($slice)
        fi
    done

    declare -a lipo_args
    for slice in "${slices_needed[@]}"; do
        lipo_args+=(-extract $slice)
    done
    xcrun lipo "$IN" "${lipo_args[@]}" -output "$OUT"
fi
