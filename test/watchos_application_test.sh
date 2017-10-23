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

# Integration tests for bundling simple watchOS applications.

function set_up() {
  rm -rf app
  mkdir -p app
}

# Creates minimal watchOS application and extension targets along with a
# companion iOS app.
function create_minimal_watchos_application_with_companion() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")
load("@build_bazel_rules_apple//apple:watchos.bzl",
     "watchos_application",
     "watchos_extension"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info-PhoneApp.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    watch_application = ":watch_app",
    deps = [":lib"],
)

watchos_application(
    name = "watch_app",
    bundle_id = "my.bundle.id.watch-app",
    entitlements = "entitlements.entitlements",
    extension = ":watch_ext",
    infoplists = ["Info-WatchApp.plist"],
    minimum_os_version = "2.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)

watchos_extension(
    name = "watch_ext",
    bundle_id = "my.bundle.id.watch-app.watch-ext",
    entitlements = "entitlements.entitlements",
    infoplists = ["Info-WatchExt.plist"],
    minimum_os_version = "2.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
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
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
}
EOF

  cat > app/Info-WatchApp.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
  WKCompanionAppBundleIdentifier = "my.bundle.id";
  WKWatchKitApp = true;
}
EOF

  cat > app/Info-WatchExt.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
  NSExtension = {
    NSExtensionAttributes = {
      WKAppBundleIdentifier = "my.bundle.id.watch-app";
    };
    NSExtensionPointIdentifier = "com.apple.watchkit";
  };
}
EOF

  cat > app/entitlements.entitlements <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>test-an-entitlement</key>
  <false/>
</dict>
</plist>
EOF
}

# Asserts that the common OS and environment plist values in the watch
# application and extension have the correct values.
function assert_common_watch_app_and_extension_plist_values() {
  assert_equals "2.0" "$(cat "test-genfiles/app/MinimumOSVersion")"
  assert_equals "4" "$(cat "test-genfiles/app/UIDeviceFamily.0")"

  if is_device_build watchos ; then
    assert_equals "WatchOS" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "watchos" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "watchos.*" "test-genfiles/app/DTSDKName"
  else
    assert_equals "WatchSimulator" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "watchsimulator" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "watchsimulator.*" "test-genfiles/app/DTSDKName"
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

# Tests that the Info.plist in the embedded watch application has the correct
# content.
function test_watch_app_plist_contents() {
  create_minimal_watchos_application_with_companion
  create_dump_plist "//app:app.ipa" \
      "Payload/app.app/Watch/watch_app.app/Info.plist" \
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
  do_build watchos --watchos_minimum_os=2.0 //app:dump_plist \
      || fail "Should build"

  assert_equals "my.bundle.id.watch-app" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "watch_app" "$(cat "test-genfiles/app/CFBundleExecutable")"
  assert_equals "watch_app" "$(cat "test-genfiles/app/CFBundleName")"

  assert_common_watch_app_and_extension_plist_values
}

# Tests that the Info.plist in the embedded watch extension has the correct
# content.
function test_watch_ext_plist_contents() {
  create_minimal_watchos_application_with_companion
  create_dump_plist "//app:app.ipa" \
      "Payload/app.app/Watch/watch_app.app/PlugIns/watch_ext.appex/Info.plist" \
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
  do_build watchos //app:dump_plist \
      || fail "Should build"

  assert_equals "my.bundle.id.watch-app.watch-ext" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "watch_ext" "$(cat "test-genfiles/app/CFBundleExecutable")"
  assert_equals "watch_ext" "$(cat "test-genfiles/app/CFBundleName")"

  assert_common_watch_app_and_extension_plist_values
}

# Tests that the watch application is signed correctly.
function test_watch_application_is_signed() {
  create_minimal_watchos_application_with_companion
  create_dump_codesign "//app:app.ipa" \
      "Payload/app.app/Watch/watch_app.app" -vv
  do_build watchos //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the watch extension is signed correctly.
function test_watch_extension_is_signed() {
  create_minimal_watchos_application_with_companion
  create_dump_codesign "//app:app.ipa" \
      "Payload/app.app/Watch/watch_app.app/PlugIns/watch_ext.appex" -vv
  do_build watchos //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the provisioning profile is present when built for device.
function test_contains_provisioning_profile() {
  # Ignore the test for simulator builds.
  is_device_build watchos || return 0

  create_minimal_watchos_application_with_companion
  do_build watchos //app:app || fail "Should build"

  # Verify that the IPA contains the provisioning profile.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Watch/watch_app.app/PlugIns/watch_ext.appex/embedded.mobileprovision"
}

# Tests that the watch application and IPA contain the WatchKit stub executable
# in the appropriate bundle and top-level support directories.
function test_contains_stub_executable() {
  create_minimal_watchos_application_with_companion
  do_build watchos //app:app || fail "Should build"

  # Verify that the IPA contains the provisioning profile.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Watch/watch_app.app/_WatchKitStub/WK"

  # Ignore the check for simulator builds.
  is_device_build watchos || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
    "WatchKitSupport2/WK"
}

# Tests that the IPA contains bitcode symbols when bitcode is embedded.
function test_bitcode_symbol_maps_packaging() {
  # Bitcode is only availabe on device. Ignore the test for simulator builds.
  is_device_build watchos || return 0

  create_minimal_watchos_application_with_companion

  do_build watchos //app:app \
      --apple_bitcode=embedded || fail "Should build"

  assert_ipa_contains_bitcode_maps ios "test-bin/app/app.ipa" \
      "Payload/app.app/app"
  assert_ipa_contains_bitcode_maps watchos "test-bin/app/app.ipa" \
      "Payload/app.app/Watch/watch_app.app/PlugIns/watch_ext.appex/watch_ext"
}

# Tests that the linkmap outputs are produced when --objc_generate_linkmap is
# present.
function test_linkmaps_generated() {
  create_minimal_watchos_application_with_companion
  do_build watchos --objc_generate_linkmap \
      //app:watch_ext || fail "Should build"

  declare -a archs=( $(current_archs watchos) )
  for arch in "${archs[@]}"; do
    assert_exists "test-bin/app/watch_ext_${arch}.linkmap"
  done
}

# Tests that entitlements are added to the application correctly. This appears
# to matter only for device builds, where the stub binary is signed with the
# entitlements. For simulator builds, which would normally inject the
# entitlements using the linker for traditional apps, Xcode appears to simply
# ignore them.
function test_watch_application_entitlements() {
  create_minimal_watchos_application_with_companion

  if is_device_build watchos ; then
    create_dump_codesign "//app:app.ipa" \
        "Payload/app.app/Watch/watch_app.app" -d --entitlements :-
    do_build watchos //app:dump_codesign || fail "Should build"

    assert_contains "<key>test-an-entitlement</key>" \
        "test-genfiles/app/codesign_output"
  fi
}

# Tests that entitlements are added to the watch extension correctly. For debug
# builds, we make sure that the appropriate Mach-O section is present; for
# release builds, we check the code signing.
function test_watch_extension_entitlements() {
  create_minimal_watchos_application_with_companion

  if is_device_build watchos ; then
    # For device builds, we verify that the entitlements are in the codesign
    # output.
    create_dump_codesign "//app:app.ipa" \
        "Payload/app.app/Watch/watch_app.app/PlugIns/watch_ext.appex" \
        -d --entitlements :-
    do_build watchos //app:dump_codesign || fail "Should build"

    assert_contains "<key>test-an-entitlement</key>" \
        "test-genfiles/app/codesign_output"
  else
    # For simulator builds, the entitlements are added as a Mach-O section in
    # the binary.
    do_build watchos //app:app || fail "Should build"

    unzip_single_file "test-bin/app/app.ipa" \
        "Payload/app.app/Watch/watch_app.app/PlugIns/watch_ext.appex/watch_ext" | \
        print_debug_entitlements - | \
        assert_contains "<key>test-an-entitlement</key>" -
  fi
}

run_suite "watchos_application bundling tests"
