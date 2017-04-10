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

# Integration tests for bundling iOS applications that use Swift.

function set_up() {
  rm -rf app
  mkdir -p app
}

# Creates common source, targets, and basic plist for iOS applications.
#
# This creates everything but the "lib" target, which must be created by the
# individual tests (so that they can exercise different dependency structures).
function create_minimal_ios_application() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application")
load("@build_bazel_rules_apple//apple:swift.bzl",
     "swift_library")

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
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
  is_device_build ios || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftFoundation.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftUIKit.dylib"
}

# Tests that the bundler includes the Swift dylibs both in the application
# bundle and in the top-level support directory of the IPA.
function test_swift_dylibs_present() {
  create_minimal_ios_application

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

  do_build ios 9.0 //app:app || fail "Should build"
  assert_ipa_contains_swift_dylibs
}

# Tests that the bundler includes the Swift dylibs even when Swift is an
# indirect dependency (that is, none of the direct deps of the application
# are swift_libraries, but a transitive dependency is). This verifies that
# the `uses_swift` property is propagated correctly.
function test_swift_dylibs_present_with_only_indirect_swift_deps() {
  create_minimal_ios_application

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

  do_build ios 9.0 //app:app || fail "Should build"
  assert_ipa_contains_swift_dylibs
}

# For device builds, tests that the Swift dylibs and the app are signed with
# the same certificate.
#
# This test does not work for ad hoc signed builds. To test it, make sure you
# specify a real certificate using the --ios_signing_cert_name command line
# flag.
function test_swift_dylibs_are_signed_with_same_certificate_as_app() {
  is_device_build ios || return 0
  ! is_ad_hoc_signed_build || return 0

  create_minimal_ios_application

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

  create_dump_codesign_count "//app:app.ipa" \
      "Payload/app.app/app" \
      "Payload/app.app/Frameworks/libswiftCore.dylib"
  do_build ios 9.0 //app:dump_codesign_count || fail "Should build"

  # We checked two files, but there should be exactly one unique certificate.
  assert_equals "1" "$(cat "test-genfiles/app/codesign_count_output")"
}

run_suite "ios_application with Swift bundling tests"
