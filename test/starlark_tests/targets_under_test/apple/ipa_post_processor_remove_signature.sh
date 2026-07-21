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
case "$APPLE_SDK_PLATFORM" in
  "MacOSX"|"WatchSimulator"|"WatchOS")
    APPDIR="$WORKDIR"
    ;;
  *)
    APPDIR="$WORKDIR/Payload"
    ;;
esac

# Remove the signature from each framework to simulate a post-processor that
# modifies a framework binary after it was signed, invalidating its signature.
# The codesigning tool should detect the invalid signature and re-sign the
# framework instead of skipping it.
for app in \
    $(find "$APPDIR" -type d -maxdepth 1 -mindepth 1); do

  if [ "$APPLE_SDK_PLATFORM" != "MacOSX" ]; then
    FRAMEWORK_DIR="$app/Frameworks"
  else
    FRAMEWORK_DIR="$app/Contents/Frameworks"
  fi

  if [[ -d "$FRAMEWORK_DIR" ]]; then
    for fmwk in \
        $(find "$FRAMEWORK_DIR" -type d -maxdepth 1 -mindepth 1); do
      /usr/bin/codesign --remove-signature "$fmwk"
    done
  fi
done