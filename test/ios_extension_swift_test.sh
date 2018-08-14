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

# Integration tests for bundling iOS extensions that use Swift.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}
# Creates the targets for a minimal iOS application written in Objective-C that
# uses Swift in an app extension.
function create_minimal_ios_application_with_swift_extension() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_extension")
load("@build_bazel_rules_swift//swift:swift.bzl",
     "swift_library")

swift_library(
    name = "swiftlib",
    srcs = ["ExtensionClass.swift"],
)

objc_library(
    name = "objclib",
    srcs = ["main.m"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":objclib"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":swiftlib"],
)
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  # The extension shouldn't use UIApplicationMain, but something seems to be
  # stripping the class (and thus the import it needs) out if I don't use
  # something like this to force it to be exported.
  cat > app/ExtensionClass.swift <<EOF
import UIKit

@UIApplicationMain
class ExtensionClass: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
}
EOF

  cat > app/Info-App.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF
}

# Creates the targets for a minimal iOS application written in Swift that also
# uses Swift in an app extension, but where the extension.
function create_minimal_swift_ios_application_with_swift_extension() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_extension")
load("@build_bazel_rules_swift//swift:swift.bzl",
     "swift_library")

swift_library(
    name = "app_swiftlib",
    srcs = ["AppDelegate.swift"],
)

swift_library(
    name = "ext_swiftlib",
    srcs = ["ExtensionClass.swift"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":app_swiftlib"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":ext_swiftlib"],
)
EOF

  cat > app/AppDelegate.swift <<EOF
import AVFoundation
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  var asset: AVAsset?
}
EOF

  # The extension shouldn't use UIApplicationMain, but something seems to be
  # stripping the class (and thus the import it needs) out if I don't use
  # something like this to force it to be exported.
  cat > app/ExtensionClass.swift <<EOF
import CoreLocation
import UIKit

@UIApplicationMain
class ExtensionClass: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  var locationManager: CLLocationManager?
}
EOF

  cat > app/Info-App.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF
}

# Tests that the bundler includes the Swift dylibs when only an extension uses
# Swift.
#
# We look for three dylibs based on what is used in the scratch AppDelegate
# class above: Core, Foundation, and UIKit.
function test_swift_dylibs_present() {
  create_minimal_ios_application_with_swift_extension
  do_build ios //app:app || fail "Should build"

  # Verify that the Swift dylibs are packaged with the *application*, not with
  # the extension, as Xcode would do.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftFoundation.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftUIKit.dylib"

  # And to be safe, verify that they *aren't* packaged with the extension.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Frameworks/libswiftCore.dylib"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Frameworks/libswiftFoundation.dylib"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Frameworks/libswiftUIKit.dylib"

  # Ignore the following checks for simulator builds.
  is_device_build ios || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftCore.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftFoundation.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftUIKit.dylib"
}

# Tests that the bundler includes the union of Swift libraries used by the
# application and the extension. Only the application created by this test
# uses AVFoundation and only the extension uses CoreLocation; both should be
# present in the Frameworks folder and, for release builds, the SwiftSupport
# folder.
function test_union_of_swift_dylibs_present_for_app_and_extension() {
  create_minimal_swift_ios_application_with_swift_extension
  do_build ios //app:app || fail "Should build"

  # Verify that the Swift dylibs are packaged with the *application*, not with
  # the extension, as Xcode would do.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftAVFoundation.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftCoreLocation.dylib"

  # And to be safe, verify that they *aren't* packaged with the extension.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Frameworks/libswiftAVFoundation.dylib"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Frameworks/libswiftCoreLocation.dylib"

  # Ignore the following checks for simulator builds.
  is_device_build ios || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftAVFoundation.dylib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/iphoneos/libswiftCoreLocation.dylib"
}

run_suite "ios_extension with Swift bundling tests"
