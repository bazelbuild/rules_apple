#!/bin/bash

# Copyright 2018 The Bazel Authors. All rights reserved.
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

# Integration tests for apple_framework_relative_headers iOS dynamic frameworks.

function set_up() {
  mkdir -p app
  mkdir -p framework
}

function tear_down() {
  rm -rf app
  rm -rf framework
}

# Test that if an objc_library target depends on another objc_library that has a
# apple_framework_relative_headers dependency that framework-style imports work
# as expected.
function test_library_depends_on_library_with_framework_relative_headers() {
  cat > framework/BUILD <<EOF
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_framework_relative_headers",
    )

apple_framework_relative_headers(
    name = "SomeFrameworkHeaders",
    framework_name = "SomeFramework",
    hdrs = ["Framework.h"],
)

objc_library(
    name = "framework",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    deps = [
        ":SomeFrameworkHeaders",
    ],
    visibility = ["//visibility:public"],
)
EOF

  cat > app/BUILD <<EOF
objc_library(
    name = "app",
    srcs = [
        "main.m",
    ],
    deps = [
        "//framework",
    ],
)
EOF

  cat > framework/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

#import <Foundation/Foundation.h>

void doStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > framework/Framework.m <<EOF
#import "Framework.h"

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  cat > app/main.m <<EOF
#import <SomeFramework/Framework.h>
EOF

  do_build ios //app:app || fail "Should build"
}

run_suite "apple_framework_relative_headers tests"
