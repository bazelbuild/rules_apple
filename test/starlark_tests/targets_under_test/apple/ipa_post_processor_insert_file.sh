#!/bin/bash

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

set -euo pipefail

WORKDIR="$1"
IOS_APP_DIR="$(find "$WORKDIR/Payload" -maxdepth 1 -mindepth 1 -type d -name "*.app" -print -quit 2>/dev/null || true)"

if [[ -n "$IOS_APP_DIR" ]]; then
  echo "foo" > "$IOS_APP_DIR/inserted_by_post_processor.txt"
  exit 0
fi

CONTENT_BUNDLE_DIR="$(find "$WORKDIR" -maxdepth 1 -mindepth 1 -type d \( -name "*.app" -o -name "*.bundle" -o -name "*.qlgenerator" \) -print -quit)"

if [[ -n "$CONTENT_BUNDLE_DIR" ]]; then
  mkdir -p "$CONTENT_BUNDLE_DIR/Contents/Resources"
  echo "foo" > "$CONTENT_BUNDLE_DIR/Contents/Resources/inserted_by_post_processor.txt"
  exit 0
fi

echo "No supported bundle directory found in $WORKDIR" >&2
exit 1
