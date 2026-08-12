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

set -ex

# Usage: check_macos_symlinks.sh <path_to_xcframework_archive>
XCFRAMEWORK_DOC="$1"

TEMP_DIR=$(mktemp -d)
unzip -q "$XCFRAMEWORK_DOC" -d "$TEMP_DIR"

FRAMEWORK=$(find "$TEMP_DIR" -name "*.xcframework" -type d | head -n 1)

if [ -z "$FRAMEWORK" ]; then
    echo "Could not find unpacked xcframework in $TEMP_DIR"
    exit 1
fi

MACOS_DIR=$(find "$FRAMEWORK" -name "macos-*" -type d)
if [ -z "$MACOS_DIR" ]; then
    echo "Could not find macos-* directory inside XCFramework"
    exit 1
fi

FW_BUNDLE=$(find "$MACOS_DIR" -name "*.framework" -type d)
if [ -z "$FW_BUNDLE" ]; then
    echo "Could not find .framework bundle inside macos directory"
    exit 1
fi

if [ ! -d "$FW_BUNDLE/Versions/Current" ]; then
    echo "Versions/Current does not exist!"
    exit 1
fi

CURRENT_TARGET=$(readlink "$FW_BUNDLE/Versions/Current")
if [[ "$CURRENT_TARGET" != "A" && "$CURRENT_TARGET" != "A/" ]]; then
    echo "Versions/Current is not a symlink to A. Target: $CURRENT_TARGET"
    exit 1
fi

for item in "$FW_BUNDLE"/*; do
  item_name=$(basename "$item")
  if [ "$item_name" != "Versions" ]; then
    if [ ! -L "$item" ]; then
      echo "$item_name is not a symlink!"
      exit 1
    fi
    target=$(readlink "$item")
    if [[ "$target" != "Versions/Current/$item_name" && "$target" != "Versions/Current/$item_name/" ]]; then
      echo "$item_name is not a symlink to Versions/Current/$item_name. Target: $target"
      exit 1
    fi
  fi
done

echo "macOS framework symlinks verified successfully!"
exit 0
