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

# Integration tests for bundling simple watchOS applications that use Swift.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates watchOS application and extension targets along with a
# companion iOS app. The iOS application depends on a library named
# ":phone_lib" and the watchOS extension depends on a library named
# ":watch_lib". These targets must be created by the individual test cases
# (so that they can test Obj-C vs. Swift as needed).
function create_app_and_extension_targets() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application")
load("@build_bazel_rules_apple//apple:watchos.bzl",
     "watchos_application",
     "watchos_extension")
load("@build_bazel_rules_swift//swift:swift.bzl",
     "swift_library")

ios_application(
    name = "phone_app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info-PhoneApp.plist"],
    minimum_os_version = "8.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    watch_application = ":watch_app",
    deps = [":phone_lib"],
)

watchos_application(
    name = "watch_app",
    bundle_id = "my.bundle.id.watch-app",
    extension = ":watch_ext",
    infoplists = ["Info-WatchApp.plist"],
    minimum_os_version = "2.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
)

watchos_extension(
    name = "watch_ext",
    bundle_id = "my.bundle.id.watch-app.watch-ext",
    infoplists = ["Info-WatchExt.plist"],
    minimum_os_version = "2.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":watch_lib"],
)
EOF

  cat > app/main.swift <<EOF
import Foundation

class SomeObject: NSObject {}
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/Info-PhoneApp.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/Info-WatchApp.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  WKCompanionAppBundleIdentifier = "my.bundle.id";
  WKWatchKitApp = true;
}
EOF

  cat > app/Info-WatchExt.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionAttributes = {
      WKAppBundleIdentifier = "my.bundle.id.watch-app";
    };
    NSExtensionPointIdentifier = "com.apple.watchkit";
  };
}
EOF
}

# Tests that if the iOS app uses Swift and the watchOS extension does not, then
# Swift libraries are only bundled in the iOS app and only iOS Swift libraries
# are in the SwiftSupport folder for release builds.
function test_only_ios_swift_libs_present() {
  create_app_and_extension_targets

  cat >> app/BUILD <<EOF
swift_library(
    name = "phone_lib",
    srcs = ["main.swift"],
)

objc_library(
    name = "watch_lib",
    srcs = ["main.m"],
)
EOF

  do_build watchos //app:phone_app || fail "Should build"

  # Make sure we do have Swift dylibs in the iOS application.
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Frameworks/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Frameworks/libswiftFoundation.dylib"

  # Make sure we don't have a Swift dylib in the watchOS extension.
  assert_zip_not_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Watch/watch_app.app/PlugIns/watch_ext.appex/Frameworks/libswiftCore.dylib"

  # Ignore the following checks for simulator builds.
  # Support bundles are only present on device builds, since those are
  # configured for opt compilation model.
  is_device_build watchos || return 0

  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/iphoneos/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/iphoneos/libswiftFoundation.dylib"
}

# Tests that if the watchOS extension uses Swift and the iOS app does not, then
# Swift libraries are only bundled in the watchOS app (not the extension) and
# only watchOS Swift libraries are in the SwiftSupport folder for release
# builds.
function test_only_watchos_swift_libs_present() {
  create_app_and_extension_targets

  cat >> app/BUILD <<EOF
objc_library(
    name = "phone_lib",
    srcs = ["main.m"],
)

swift_library(
    name = "watch_lib",
    srcs = ["main.swift"],
)
EOF

  do_build watchos //app:phone_app || fail "Should build"

  # Make sure we don't have a Swift dylib in the iOS application.
  assert_zip_not_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Frameworks/libswiftCore.dylib"

  # Make sure we do have Swift dylibs in the watchOS extension.
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Watch/watch_app.app/Frameworks/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Watch/watch_app.app/Frameworks/libswiftFoundation.dylib"

  # Ignore the following checks for simulator builds.
  # Support bundles are only present on device builds, since those are
  # configured for opt compilation model.
  is_device_build watchos || return 0

  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/watchos/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/watchos/libswiftFoundation.dylib"
}

# Tests that if both the iOS app and the watchOS extension use Swift, then the
# iOS app and watchOS app (not the extension) have Swift libraries bundled, and
# that Swift libraries for both platforms are in the SwiftSupport folder for
# release builds.
function test_both_ios_and_watchos_swift_libs_present() {
  create_app_and_extension_targets

  cat >> app/BUILD <<EOF
swift_library(
    name = "phone_lib",
    srcs = ["main.swift"],
)

swift_library(
    name = "watch_lib",
    srcs = ["main.swift"],
)
EOF

  do_build watchos //app:phone_app || fail "Should build"

  # Make sure we do have Swift dylibs in the iOS application.
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Frameworks/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Frameworks/libswiftFoundation.dylib"

  # Make sure we do have Swift dylibs in the watchOS extension.
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Watch/watch_app.app/Frameworks/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "Payload/phone_app.app/Watch/watch_app.app/Frameworks/libswiftFoundation.dylib"

  # Ignore the following checks for simulator builds.
  # Support bundles are only present on device builds, since those are
  # configured for opt compilation model.
  is_device_build watchos || return 0

  # Make sure iOS and watchOS Swift libraries are in SwiftSupport.
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/iphoneos/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/iphoneos/libswiftFoundation.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/watchos/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/phone_app.ipa" \
      "SwiftSupport/watchos/libswiftFoundation.dylib"
}

run_suite "watchos_application with Swift bundling tests"
