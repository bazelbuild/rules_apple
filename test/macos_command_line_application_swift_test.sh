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

# Integration tests for building macOS command line applications with Swift.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for macOS applications that
# use Swift.
function create_common_files() {
  cat > app/BUILD <<EOF
load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_command_line_application",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

swift_library(
    name = "lib",
    srcs = ["main.swift"],
)
EOF

  cat > app/main.swift <<EOF
print("hello world")
EOF
}

# Tests that a bare-bones command line app builds.
function test_basic_build() {
  create_common_files

  cat >> app/BUILD <<EOF
macos_command_line_application(
    name = "app",
    minimum_os_version = "10.11",
    deps = [":lib"],
)
EOF

  do_build macos //app:app || fail "Should build"

  # Make sure that an Info.plist did *not* get embedded in this case.
  otool -s __TEXT __info_plist test-bin/app/app > $TEST_TMPDIR/otool.out
  assert_not_contains "__TEXT,__info_plist" $TEST_TMPDIR/otool.out
}

run_suite "macos_command_line_application with Swift tests"
