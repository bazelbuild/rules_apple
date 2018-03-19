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

# Integration tests for bundling tvOS apps with extensions.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for tvOS applications.
function create_minimal_tvos_application_with_extension() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_extension",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/main.m <<EOF
#import <Foundation/Foundation.h>
// This dummy class is needed to generate code in the extension target,
// which does not take main() from here, rather from an SDK.
@interface Foo: NSObject
@end
@implementation Foo
@end

int main(int argc, char **argv) {
  return 0;
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

# Tests that the Info.plist in the extension has the correct content.
function test_extension_plist_contents() {
  create_minimal_tvos_application_with_extension
  create_dump_plist "//app:app.ipa" "Payload/app.app/PlugIns/ext.appex/Info.plist" \
      BuildMachineOSBuild \
      CFBundleExecutable \
      CFBundleIdentifier \
      CFBundleName \
      CFBundleSupportedPlatforms:0 \
      DTCompiler \
      DTPlatformBuild \
      DTPlatformName \
      DTPlatformVersion \
      DTSDKBuild \
      DTSDKName \
      DTXcode \
      DTXcodeBuild \
      MinimumOSVersion \
      UIDeviceFamily:0
  do_build tvos //app:dump_plist \
      || fail "Should build"

  # Verify the values injected by the Skylark rule.
  assert_equals "ext" "$(cat "test-genfiles/app/CFBundleExecutable")"
  assert_equals "my.bundle.id.extension" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "ext" "$(cat "test-genfiles/app/CFBundleName")"
  assert_equals "10.0" "$(cat "test-genfiles/app/MinimumOSVersion")"
  assert_equals "3" "$(cat "test-genfiles/app/UIDeviceFamily.0")"

  if is_device_build tvos ; then
    assert_equals "AppleTVOS" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "appletvos" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "appletvos.*" \
        "test-genfiles/app/DTSDKName"
  else
    assert_equals "AppleTVSimulator" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "appletvsimulator" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "appletvsimulator.*" "test-genfiles/app/DTSDKName"
  fi

  # Verify the values injected by the environment_plist script. Some of these
  # are dependent on the version of Xcode being used, and since we don't want to
  # force a particular version to always be present, we just make sure that
  # *something* is getting into the plist.
  assert_not_equals "" "$(cat "test-genfiles/app/DTPlatformBuild")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTSDKBuild")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTPlatformVersion")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTXcode")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTXcodeBuild")"
  assert_equals "com.apple.compilers.llvm.clang.1_0" \
      "$(cat "test-genfiles/app/DTCompiler")"
  assert_not_equals "" "$(cat "test-genfiles/app/BuildMachineOSBuild")"
}

# Test missing the CFBundleVersion fails the build.
function test_missing_version_fails() {
  create_minimal_tvos_application_with_extension

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF

  ! do_build ios //app:app \
    || fail "Should fail build"

  expect_log 'Target "//app:ext" is missing CFBundleVersion.'
}

# Test missing the CFBundleShortVersionString fails the build.
function test_missing_short_version_fails() {
  create_minimal_tvos_application_with_extension

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF

  ! do_build ios //app:app \
    || fail "Should fail build"

  expect_log 'Target "//app:ext" is missing CFBundleShortVersionString.'
}

# Tests that the extension inside the app bundle is properly signed.
function test_extension_is_signed() {
  create_minimal_tvos_application_with_extension
  create_dump_codesign "//app:app.ipa" \
      "Payload/app.app/PlugIns/ext.appex" -vv
  do_build tvos //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the provisioning profile is present when built for device.
function test_contains_provisioning_profile() {
  # Ignore the test for simulator builds.
  is_device_build tvos || return 0

  create_minimal_tvos_application_with_extension
  do_build tvos //app:app || fail "Should build"

  # Verify that the IPA contains the provisioning profile.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/embedded.mobileprovision"
}

# Tests that the IPA contains bitcode symbols when bitcode is embedded.
function test_bitcode_symbol_maps_packaging() {
  # Bitcode is only availabe on device. Ignore the test for simulator builds.
  is_device_build tvos || return 0

  create_minimal_tvos_application_with_extension
  do_build tvos //app:app --apple_bitcode=embedded || fail "Should build"

  assert_ipa_contains_bitcode_maps tvos "test-bin/app/app.ipa" \
      "Payload/app.app/app"
  assert_ipa_contains_bitcode_maps tvos "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/ext"
}

run_suite "tvos_extension bundling tests"
