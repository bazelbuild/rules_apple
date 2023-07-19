#!/bin/bash

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

set -eux

if [[ "$(uname)" != Darwin ]]; then
  echo "Cannot run macOS targets on a non-mac machine."
  exit 1
fi

if [ -d '%app_path%' ]; then
  # App bundles are directories with the .app extension
  readonly APP_DIR="%app_path%"
  readonly DSYM_PATH="%app_path%.dSYM"
else
  readonly TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bazel_temp.XXXXXX")
  trap 'rm -rf "${TEMP_DIR}"' EXIT
  # The app bundle is contained within an compressed archive (zip)
  # Unpack the archive
  unzip -qq '%app_path%' -d "${TEMP_DIR}"
  readonly APP_DIR="${TEMP_DIR}/%app_name%.app"

  # Copy the dsym if there is one
  readonly DSYM_NAME='%app_name%.app.dSYM'
  readonly DSYM_DIR="$(dirname %app_path%)"
  readonly DSYM_PATH="${DSYM_DIR}/${DSYM_NAME}"
  if [ -d "${DSYM_PATH}" ]; then
    pushd "${DSYM_DIR}"
    # pax does a much faster copy than cp and is more dependable than cp -c
    # https://github.com/nico/hack/blob/main/notes/copydir.md
    pax -rwl "${DSYM_NAME}" "${TEMP_DIR}"
    popd
  fi
fi

if [ -d "${DSYM_PATH}" ]; then
  # This adds the symbols to the CoreSymbolication so they can be easily found
  # without having spotlight index them.
  # Tagged with "bazel" for easy deletions of all bazel symbols should we want
  # to add a cleanup mechanism.
  # Not cleaning up as part of the trap because the symbols may be accessed
  # after the trap has run in the case of a crash.
  symbolscache add --tag Bazel "${APP_DIR}.dSYM/Contents/Resources/DWARF/"*
 fi

# Get the bundle executable name of the app. Read this from the plist in case it
# differs from the app name.
readonly BUNDLE_INFO_PLIST="${APP_DIR}/Contents/Info.plist"
readonly BUNDLE_EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${BUNDLE_INFO_PLIST}")

# Launch the app binary
# Do *not* use exec here because we want the trap above to execute after the
# executable has run.
"${APP_DIR}/Contents/MacOS/${BUNDLE_EXECUTABLE}" "$@"
