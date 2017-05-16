#!/bin/bash

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

set -eu

if [[ "%(test_type)s" = "XCUITEST" ]]; then
  echo "This runner only works with ios_unit_test."
  exit 1
fi

# Returns the name of the file without the leading path and trailing extension.
basename_without_extension() {
  local full_path="$1"
  local filename=$(basename "$full_path")
  echo "${filename%.*}"
}

# Unpack the output IPA into a tmp folder
TEST_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tests.XXXXXX")"
trap 'rm -rf "${TEST_TMP_DIR}"' ERR EXIT

TEST_BUNDLE_PATH="%(test_bundle_path)s"
TEST_BUNDLE_NAME=$(basename_without_extension "$TEST_BUNDLE_PATH")

unzip -qq "$TEST_BUNDLE_PATH" 'Payload/*' -d "$TEST_TMP_DIR"
TEST_BUNDLE="$TEST_TMP_DIR/Payload/$TEST_BUNDLE_NAME.xctest"

# Create a simulator with a random name and the iOS SDK provided by the
# Xcode currently selected with xcode-select.
RANDOM_NAME="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)"
SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"

NEW_SIM_ID=$(xcrun simctl create "$RANDOM_NAME" "iPhone 6" "$SDK_VERSION")

# Clean our simulator up even if we fail along the way
function cleanup {
    xcrun simctl delete $"$NEW_SIM_ID"
}
trap cleanup EXIT

# Wait a bit so that the newly created simulator can pass from the Creating
# state to the Shutdown state.
sleep 2

# Figure out the path to the xctest agent for library based tests.
XCODE_PATH=$(xcrun xcode-select -p)
XCTEST_PATH="$XCODE_PATH/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Agents/xctest"

# Spawn xctest with the test bundle which runs the tests.
xcrun simctl spawn "$NEW_SIM_ID" "$XCTEST_PATH" "$TEST_BUNDLE"
EXIT_CODE=$?

# Bazel detects the exit code from this script as the status of whether the
# tests succeeded or failed. Any exit code other than 0 means tests failed.
exit $EXIT_CODE
