#!/bin/bash

# Copyright 2020 The Bazel Authors. All rights reserved.
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

set -eu

WORKDIR="$1"
readonly CODESIGN_FMWKS_OUTPUT_FILE="codesign_v_fmwks_output.txt"

if [[ -n "${TREE_ARTIFACT_OUTPUT:-}" ]]; then
  APPDIR="$TREE_ARTIFACT_OUTPUT"
else
  case "$APPLE_SDK_PLATFORM" in
    "MacOSX"|"WatchSimulator"|"WatchOS")
      APPDIR="$WORKDIR"
      ;;
    *)
      if [[ -d "$WORKDIR/Payload" ]]; then
        APPDIR="$WORKDIR/Payload"
      else
        APPDIR="$WORKDIR"
      fi
      ;;
  esac
fi

if [[ ! -d "$APPDIR" ]]; then
  echo "Internal Error: Failed to find bundle root directory at $APPDIR" >&2
  exit 1
fi

# Save all codesigning output for each framework to verify later that they are
# not being re-signed.
if [[ -n "${TREE_ARTIFACT_OUTPUT:-}" ]]; then
  bundle_roots=("$APPDIR")
else
  bundle_roots=()
  while IFS= read -r -d "" app; do
    bundle_roots+=("$app")
  done < <(find "$APPDIR" -type d -maxdepth 1 -mindepth 1 -print0)
fi

for app in "${bundle_roots[@]}"; do
  if [ "$APPLE_SDK_PLATFORM" != "MacOSX" ]; then
    FRAMEWORK_DIR="$app/Frameworks"
    CODESIGN_FMWKS_OUTPUT="$app/$CODESIGN_FMWKS_OUTPUT_FILE"
  else
    # macOS has a different bundle structure, and will fail codesigning if files
    # such as text files are not placed in the Resources directory. Create a
    # Resources directory in Contents if one does not exist.
    FRAMEWORK_DIR="$app/Contents/Frameworks"
    CODESIGN_FMWKS_OUTPUT="$app/Contents/Resources/$CODESIGN_FMWKS_OUTPUT_FILE"
  fi

  if [ ! -d "$FRAMEWORK_DIR" ]; then
    continue
  fi

  mkdir -p "$(dirname "$CODESIGN_FMWKS_OUTPUT")"
  : > "$CODESIGN_FMWKS_OUTPUT"

  for fmwk in \
      $(find "$FRAMEWORK_DIR" -type d -maxdepth 1 -mindepth 1); do
    # codesign writes all output to stderr; redirect to stdout and egrep to
    # filter problematic outputs.
    /usr/bin/codesign --display --verbose=3 "$fmwk" 2>&1 | egrep -v "^Executable=" >> "$CODESIGN_FMWKS_OUTPUT"
  done
  if [ ! -f "$CODESIGN_FMWKS_OUTPUT" ]; then
      echo "Internal Error: Failed to create codesign output file at $CODESIGN_FMWKS_OUTPUT" >&2
      exit 1
  fi
done
