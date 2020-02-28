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

# Save all codesigning output for each framework to verify later that they are
# not being re-signed.
for app in \
    $(find "$WORKDIR/Payload" -type d -maxdepth 1 -mindepth 1); do

  CODESIGN_FMWKS_OUTPUT="$app/codesign_v_fmwks_output.txt"

  for fmwk in \
      $(find "$app/Frameworks" -type d -maxdepth 1 -mindepth 1); do
    # codesign writes all output to stderr; redirect to stdout and egrep to
    # filter problematic outputs.
    /usr/bin/codesign --display --verbose=3 "$fmwk" 2>&1 | egrep "^[^Executable=]" >> "$CODESIGN_FMWKS_OUTPUT"
  done
  if [ ! -f "$CODESIGN_FMWKS_OUTPUT" ]; then
      echo "Internal Error: Failed to create codesign output file at $CODESIGN_FMWKS_OUTPUT" >&2
      exit 1
  fi
done
