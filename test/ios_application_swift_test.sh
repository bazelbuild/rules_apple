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
  mkdir -p app
}

function tear_down() {
  rm -rf app
}
# Creates common source, targets, and basic plist for iOS applications.
#
# This creates everything but the "lib" target, which must be created by the
# individual tests (so that they can exercise different dependency structures).
function create_minimal_ios_application() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application")
load("@build_bazel_rules_swift//swift:swift.bzl",
     "swift_library")

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
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
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF
}

# Asserts that app.ipa contains the Swift runtime in both the application
# bundle and in the top-level support directory if the build was for device,
# otherwise assert they're not in the top level SwiftSupport directory.
function assert_ipa_contains_swift_dylibs_for_device() {
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftCore.dylib"

  if is_device_build ios; then
    assert_zip_contains "test-bin/app/app.ipa" \
        "SwiftSupport/iphoneos/libswiftCore.dylib"
  else
    assert_zip_not_contains "test-bin/app/app.ipa" \
        "SwiftSupport/iphonesimulator/libswiftCore.dylib"
  fi
}

# Tests that the bundler includes the Swift runtime both in the application
# bundle and in the top-level support directory of the IPA.
function test_swift_dylibs_present() {
  create_minimal_ios_application

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

  do_build ios //app:app || fail "Should build"
  assert_ipa_contains_swift_dylibs_for_device
}

# Tests that if the Swift dylib feature is set to false, they don't exist
# in final device build ipas
function test_swift_dylibs_not_present_for_feature() {
  if is_device_build ios; then
    create_minimal_ios_application

    cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

    do_build ios //app:app --define=apple.package_swift_support=no \
      || fail "Should build"
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libswiftCore.dylib"
    assert_zip_not_contains "test-bin/app/app.ipa" \
        "SwiftSupport/iphoneos/libswiftCore.dylib"
  fi
}

# Tests that the bundler includes the Swift runtime even when Swift is an
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

  do_build ios //app:app || fail "Should build"
  assert_ipa_contains_swift_dylibs_for_device
}

# Tests that swift_library build with ASAN enabled and that the ASAN
# library is packaged into the IPA when enabled.
function disabled_test_swift_builds_with_asan() {  # Blocked on b/73547309
  create_minimal_ios_application

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

  do_build ios //app:app --features=asan || fail "Should build"

  if is_device_build ios ; then
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.asan_ios_dynamic.dylib"
  else
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.asan_iossim_dynamic.dylib"
  fi
}

# Tests that swift_library build with TSAN enabled and that the TSAN
# library is packaged into the IPA when enabled.
function disabled_test_swift_builds_with_tsan() {  # Blocked on b/73547309
  # Skip the device version as tsan is not supported on devices.
  if ! is_device_build ios ; then
    create_minimal_ios_application

    cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

    do_build ios //app:app --features=tsan \
        || fail "Should build"
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib"
  fi
}

run_suite "ios_application with Swift bundling tests"
