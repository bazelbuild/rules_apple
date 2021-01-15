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

# Integration tests for bundling tvOS extensions that use Swift.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates the targets for a minimal tvOS application written in Objective-C
# that uses Swift in an app extension.
function create_minimal_tvos_application_with_swift_extension() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_extension")
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

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":objclib"],
)

tvos_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
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
  CFBundlePackageType = "XPC!";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF
}

# Tests that the bundler includes the Swift runtime when only an extension uses
# Swift.
function test_swift_dylibs_present() {
  create_minimal_tvos_application_with_swift_extension
  do_build tvos //app:app || fail "Should build"

  # Verify that the Swift dylibs are packaged with the *application*, not with
  # the extension, as Xcode would do.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/libswiftCore.dylib"

  # And to be safe, verify that they *aren't* packaged with the extension.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Frameworks/libswiftCore.dylib"

  # Ignore the following checks for simulator builds.
  is_device_build tvos || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "SwiftSupport/appletvos/libswiftCore.dylib"
}

run_suite "tvos_extension with Swift bundling tests"
