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

# Sourced helper utilities (contains assert_is_codesigned, etc.)
# The runner script should source apple_shell_testutils.sh

# Assert main binary is signed
assert_is_codesigned "$BUNDLE_ROOT"

# Extract signing identity requirement from main binary
# codesign -d -r- outputs: designated => identifier "id" and anchor ...
app_req=$(codesign -d -r- "$BUNDLE_ROOT" 2>/dev/null | sed 's/identifier "[^"]*"//')
[[ -n "$app_req" ]] || fail "Failed to extract designated requirement from $BUNDLE_ROOT"

# Check Swift dylibs
if [[ ! -d "$CONTENT_ROOT/Frameworks" ]]; then
  fail "Frameworks directory does not exist in the bundle"
fi

dylibs=$(find "$CONTENT_ROOT/Frameworks" -type f -name "*.dylib")
if [[ -z "$dylibs" ]]; then
  fail "No nested Swift dylibs found in Frameworks/"
fi

for dylib in $dylibs; do
  assert_is_codesigned "$dylib"
  dylib_req=$(codesign -d -r- "$dylib" 2>/dev/null | sed 's/identifier "[^"]*"//')
  [[ -n "$dylib_req" ]] || fail "Failed to extract designated requirement from $dylib"

  echo "App Requirement: '$app_req'"
  echo "Dylib $dylib Requirement: '$dylib_req'"
  if [[ "$app_req" == *cdhash* && "$dylib_req" == *cdhash* ]]; then
    echo "Both app and dylib are ad-hoc signed. Skipping identity match check."
  elif [[ "$app_req" != "$dylib_req" ]]; then
    fail "Swift dylib $dylib is not signed with the same identity as the app"
  fi
done
