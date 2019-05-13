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

set -eu

TEMP_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/codesign_output.XXXXXX")"

if [[ "$BUILD_TYPE" == "simulator" ]]; then
  xcrun llvm-objdump -macho -section=__TEXT,__entitlements "$BINARY" | \
      sed -e 's/^[0-9a-f][0-9a-f]*[[:space:]][[:space:]]*//' \
      -e 'tx' -e 'd' -e ':x' | xxd -r -p > "$TEMP_OUTPUT"
elif [[ "$BUILD_TYPE" == "device" ]]; then
  codesign -d --entitlements "$TEMP_OUTPUT" "$BUNDLE_ROOT"
else
  fail "Unsupported BUILD_TYPE = $BUILD_TYPE for this test"
fi

# This key comes from the
# third_party/bazel_rules/rules_apple/test/starlark_tests/resources/entitlements.plist
# file. Targets under test need to specify this file in the `entitlements`
# attribute.
assert_contains "<key>test-an-entitlement</key>" "$TEMP_OUTPUT"

rm -rf "$TEMP_OUTPUT"
