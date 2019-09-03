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

# Integration tests for dtrace.

function set_up() {
  mkdir -p dtrace/folder1
  mkdir -p dtrace/folder2
}

function tear_down() {
  rm -rf dtrace
}

# Verify that the dtrace compiler creates headers with the expected contents.
# Also verifies that files with the same name in different directories
# do not stomp on one another.
function test_dtrace_compiles() {
  cat >dtrace/folder1/probes.d <<EOF
provider providerA {
  probe myFunc(int);
};
EOF

  cat >dtrace/folder2/probes.d <<EOF
provider providerB {
  probe myFunc(int);
};
EOF

  cat >dtrace/BUILD <<EOF
load("@build_bazel_rules_apple//apple:dtrace.bzl", "dtrace_compile")

dtrace_compile(name = "CompileTest",
               srcs = ["folder1/probes.d", "folder2/probes.d"])
EOF

  do_build dtrace //dtrace:CompileTest || fail "should build"
  assert_contains "PROVIDERA_MYFUNC" \
      test-bin/dtrace/CompileTest/folder1/probes.h
  assert_contains "PROVIDERB_MYFUNC" \
      test-bin/dtrace/CompileTest/folder2/probes.h
}

run_suite "dtrace tests"
