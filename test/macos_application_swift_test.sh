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

# Integration tests for bundling simple macOS applications that use Swift.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates a minimal macOS application target.
function create_minimal_macos_application() {
  cat > app/BUILD <<EOF
load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_application",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.11",
    deps = [":lib"],
)
EOF

  cat > app/AppDelegate.swift <<EOF
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {}
EOF

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF
}

# Tests that the bundler includes the Swift dylibs in the application bundle.
function test_swift_dylibs_present() {
  create_minimal_macos_application

  do_build macos //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Frameworks/libswiftAppKit.dylib"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Frameworks/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Frameworks/libswiftFoundation.dylib"

  # This should be implied by the previous check, but we also check that Swift
  # symbols are not found in the TEXT section (which would imply static
  # linkage).
  nm test-bin/app/app | grep "T _swift_slowAlloc" > /dev/null \
      && fail "Should not have found _swift_slowAlloc in TEXT section but did" \
      || :
}

run_suite "macos_application with Swift bundling tests"
