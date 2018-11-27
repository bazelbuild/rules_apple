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

# Integration tests for building macOS dylibs.

function set_up() {
  mkdir -p dylib
}

function tear_down() {
  rm -rf dylib
}

# Creates common source, targets, and basic plist for macOS dylibs.
function create_common_files() {
  cat > dylib/BUILD <<EOF
load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_dylib",
)

objc_library(
    name = "lib",
    srcs = ["tester.m"],
)
EOF

  cat > dylib/tester.m <<EOF
int test_function(int a, int b) {
  return 0;
}
EOF
}

# Tests that a bare-bones dylib builds.
function test_basic_build() {
  create_common_files

  cat >> dylib/BUILD <<EOF
macos_dylib(
    name = "dylib",
    minimum_os_version = "10.11",
    deps = [":lib"],
)
EOF

  do_build macos //dylib:dylib || fail "Should build"

  # Make sure that an Info.plist did *not* get embedded in this case.
  otool -s __TEXT __info_plist test-bin/dylib/dylib.dylib \
      > $TEST_TMPDIR/otool.out
  assert_not_contains "__TEXT,__info_plist" $TEST_TMPDIR/otool.out
}

# Tests that a bare-bones dylib builds and embeds an info plist.
function test_info_plist_embedding() {
  create_common_files

  cat >> dylib/BUILD <<EOF
macos_dylib(
    name = "dylib",
    bundle_id = "com.test.bundle",
    infoplists = [
        "Info.plist",
        "Another.plist",
    ],
    minimum_os_version = "10.11",
    deps = [":lib"],
)
EOF

  cat > dylib/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
}
EOF

  cat > dylib/Another.plist <<EOF
{
  AnotherKey = "AnotherValue";
}
EOF

  do_build macos //dylib:dylib || fail "Should build"

  # Make sure that an Info.plist did get embedded.
  otool -s __TEXT __info_plist test-bin/dylib/dylib.dylib \
      > $TEST_TMPDIR/otool.out
  assert_contains "__TEXT,__info_plist" $TEST_TMPDIR/otool.out
}

# Tests that a dSYM bundle is generated alongside the apple_binary target.
function test_dsym_bundle_generated() {
  create_common_files

  cat >> dylib/BUILD <<EOF
macos_dylib(
    name = "dylib",
    minimum_os_version = "10.11",
    deps = [":lib"],
)
EOF

  do_build macos \
      --apple_generate_dsym \
      //dylib:dylib || fail "Should build"

  # Make sure that a dSYM bundle was generated.
  assert_exists "test-bin/dylib/dylib.dSYM/Contents/Info.plist"

  declare -a archs=( $(current_archs macos) )
  for arch in "${archs[@]}"; do
    assert_exists \
        "test-bin/dylib/dylib.dSYM/Contents/Resources/DWARF/dylib_${arch}"
  done
}

run_suite "macos_dylib tests"
