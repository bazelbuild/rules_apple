#!/bin/bash
#
# Copyright 2017 The Bazel Authors. All rights reserved.
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
# swiftstdlibtoolwrapper runs swift-stdlib-tool and zips up the output.
# This script only runs on darwin and you must have Xcode installed.
#
# --output_zip_path - the path to place the output zip file.
# --bundle_path - the path inside of the archive to where libs will be copied.

set -eu

source "$0.runfiles/build_bazel_rules_apple/tools/wrapper_common/wrapper_common.sh"
setup_common_tools

CMD_ARGS=("$@")

TOOL_ARGS=()
while [[ "$#" -gt 0 ]]; do
  ARG="$1"
  shift
  case "$ARG" in
    --output_zip_path)
      ARG="$1"
      shift
      OUTZIP="$(realpath "$ARG")"
      ;;
    --bundle_path)
      ARG="$1"
      shift
      PATH_INSIDE_ZIP="$ARG"
      ;;
    # Remaining args are swift-stdlib-tool args
    *)
      TOOL_ARGS+=("$ARG")
      ;;
  esac
done

TEMPDIR="$(create_temp_dir swiftstdlibtoolZippingOutput.XXXXXX)"
FULLPATH="$TEMPDIR/$PATH_INSIDE_ZIP"

XCRUN_ARGS=(swift-stdlib-tool --copy)
XCRUN_ARGS+=(--destination "$FULLPATH")
XCRUN_ARGS+=("${TOOL_ARGS[@]}")

xcrunwrapper "${XCRUN_ARGS[@]}"

finalize_output_as_zip "$TEMPDIR" "$OUTZIP"
