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

# Integration tests for bundling tvOS applications that use Swift.

function set_up() {
  rm -rf app
  mkdir -p app
}

# Creates common source, targets, and basic plist for tvOS applications.
#
# This creates everything but the "lib" target, which must be created by the
# individual tests (so that they can exercise different dependency structures).
function create_minimal_tvos_application() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application")
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/AppDelegate.swift <<EOF
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
}
EOF

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleSignature = "????";
}
EOF
}

# Asserts that app.ipa contains the Swift dylibs in both the application
# bundle and in the top-level support directory.
#
# We look for three dylibs based on what is used in the scratch AppDelegate
# class above: Core, Foundation, and UIKit.
function assert_ipa_contains_swift_dylibs() {
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftFoundation.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftUIKit.dylib"

  # Ignore the following checks for simulator builds.
  # Support bundles are only present on device builds, since those are
  # configured for opt compilation model.
  is_device_build tvos || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/appletvos/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/appletvos/libswiftFoundation.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/appletvos/libswiftUIKit.dylib"
}

# Tests that the bundler includes the Swift dylibs both in the application
# bundle and in the top-level support directory of the IPA.
function test_swift_dylibs_present() {
  create_minimal_tvos_application

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

  do_build tvos //app:app || fail "Should build"
  assert_ipa_contains_swift_dylibs
}

# Tests that the bundler includes the Swift dylibs even when Swift is an
# indirect dependency (that is, none of the direct deps of the application
# are swift_libraries, but a transitive dependency is). This verifies that
# the `uses_swift` property is propagated correctly.
function test_swift_dylibs_present_with_only_indirect_swift_deps() {
  create_minimal_tvos_application

  cat >> app/dummy.m <<EOF
static void dummy() {}
EOF

  cat >> app/BUILD <<EOF
objc_library(
    name = "lib",
    srcs = ["dummy.m"],
    deps = [":lib2"],
)

swift_library(
    name = "lib2",
    srcs = ["AppDelegate.swift"],
)
EOF

  do_build tvos //app:app || fail "Should build"
  assert_ipa_contains_swift_dylibs
}

run_suite "tvos_application with Swift bundling tests"
