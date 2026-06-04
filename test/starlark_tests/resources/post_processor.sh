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

set -eu

WORKDIR="$1"
case "${APPLE_SDK_PLATFORM:-}" in
  "MacOSX"|"WatchSimulator"|"WatchOS")
    APPDIR="$WORKDIR"
    ;;
  *)
    APPDIR="$WORKDIR/Payload"
    ;;
esac

while IFS= read -r -d '' app; do
  if [[ -d "$app/Contents" ]]; then
    mkdir -p "$app/Contents/Resources"
    echo "post-processed" > "$app/Contents/Resources/post_processed.txt"
  else
    echo "post-processed" > "$app/post_processed.txt"
  fi
done < <(find "$APPDIR" -type d -maxdepth 1 -mindepth 1 -print0)
