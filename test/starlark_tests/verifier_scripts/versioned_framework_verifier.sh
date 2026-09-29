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

# Checks that a macOS framework has the versioned layout: its contents in
# Versions/A, a Versions/Current link to A, and a top-level link to
# Versions/Current/<entry> for each top-level entry of Versions/A.
#
# The verifier uses the following environment variable:
#
#   EXPECTED_TOP_LEVEL_LINKS: The top-level links the bundle must have, besides
#       the one to the binary.

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

assert_link() {
  local link="$1"
  local expected_target="$2"
  [[ -L "$link" ]] || fail "Expected '$link' to be a symbolic link."
  local actual_target
  actual_target="$(readlink "$link")"
  [[ "$actual_target" == "$expected_target" ]] || \
      fail "Expected '$link' to point to '$expected_target', not '$actual_target'."
  [[ -e "$link" ]] || fail "'$link' is a dangling link."
}

version_root="$BUNDLE_ROOT/Versions/A"
[[ -d "$version_root" && ! -L "$version_root" ]] || \
    fail "Expected '$version_root' to be a directory."

assert_link "$BUNDLE_ROOT/Versions/Current" "A"

binary_name="$(basename "$BINARY")"
[[ -f "$version_root/$binary_name" && ! -L "$version_root/$binary_name" ]] || \
    fail "Expected the binary at '$version_root/$binary_name'."
assert_link "$BUNDLE_ROOT/$binary_name" "Versions/Current/$binary_name"

[[ -f "$version_root/Resources/Info.plist" ]] || \
    fail "Expected the Info.plist at '$version_root/Resources/Info.plist'."
[[ ! -e "$version_root/Info.plist" ]] || \
    fail "Expected no Info.plist in '$version_root'."

for entry in "${EXPECTED_TOP_LEVEL_LINKS[@]}"; do
  assert_link "$BUNDLE_ROOT/$entry" "Versions/Current/$entry"
done

# Everything at the top level but Versions is a link into Versions/Current.
for path in "$BUNDLE_ROOT"/*; do
  entry="$(basename "$path")"
  [[ "$entry" == "Versions" ]] && continue
  assert_link "$path" "Versions/Current/$entry"
done
