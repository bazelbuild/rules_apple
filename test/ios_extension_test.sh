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

# Integration tests for bundling iOS apps with extensions.

function set_up() {
  rm -rf app
  mkdir -p app
}

# Creates common source, targets, and basic plist for iOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "apple_product_type",
     "ios_application",
     "ios_extension",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
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
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
}
EOF

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF
}

# Usage: create_minimal_ios_application_with_extension [product type]
#
# Creates a minimal iOS application target. The optional product type is
# the Skylark constant that should be set on the extension using the
# `product_type` attribute.
function create_minimal_ios_application_with_extension() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  product_type="${1:-}"

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
EOF

  if [[ -n "$product_type" ]]; then
  cat >> app/BUILD <<EOF
    product_type = $product_type,
EOF
  fi

  cat >> app/BUILD <<EOF
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF
}

# Usage: create_minimal_ios_application_and_extension_with_objc_framework <dynamic>
#
# Creates minimal iOS application and extension targets that depends on an
# `objc_framework`. The `dynamic` argument should be `True` or `False` and will
# be used to populate the framework's `is_dynamic` attribute.
function create_minimal_ios_application_and_extension_with_objc_framework() {
  readonly framework_type="$1"

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [
        ":frameworkDependingLib",
        ":lib",
    ],
)

ios_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)

objc_library(
    name = "frameworkDependingLib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    deps = [":fmwk"],
)

objc_framework(
    name = "fmwk",
    framework_imports = glob(["fmwk.framework/**"]),
    is_dynamic = $([[ "$framework_type" == dynamic ]] && echo True || echo False),
)
EOF

  mkdir -p app/fmwk.framework
  if [[ $framework_type == dynamic ]]; then
    cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_dylib_lipobin) \
        app/fmwk.framework/fmwk
  else
    cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_staticlib_lipo.a) \
        app/fmwk.framework/fmwk
  fi

  cat > app/fmwk.framework/Info.plist <<EOF
Dummy plist
EOF

  cat > app/fmwk.framework/resource.txt <<EOF
Dummy resource
EOF

  mkdir -p app/fmwk.framework/Headers
  cat > app/fmwk.framework/Headers/fmwk.h <<EOF
This shouldn't get included
EOF

  mkdir -p app/fmwk.framework/Modules
  cat > app/fmwk.framework/Headers/module.modulemap <<EOF
This shouldn't get included
EOF
}

# Tests that the Info.plist in the extension has the correct content.
function test_extension_plist_contents() {
  create_common_files
  create_minimal_ios_application_with_extension
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
  do_build ios //app:dump_plist \
      || fail "Should build"

  # Verify the values injected by the Skylark rule.
  assert_equals "ext" "$(cat "test-genfiles/app/CFBundleExecutable")"
  assert_equals "my.bundle.id.extension" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "ext" "$(cat "test-genfiles/app/CFBundleName")"
  assert_equals "10.0" "$(cat "test-genfiles/app/MinimumOSVersion")"
  assert_equals "1" "$(cat "test-genfiles/app/UIDeviceFamily.0")"

  if is_device_build ios ; then
    assert_equals "iPhoneOS" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "iphoneos" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "iphoneos.*" \
        "test-genfiles/app/DTSDKName"
  else
    assert_equals "iPhoneSimulator" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "iphonesimulator" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "iphonesimulator.*" "test-genfiles/app/DTSDKName"
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

# Tests that the extension inside the app bundle is properly signed.
function test_extension_is_signed() {
  create_common_files
  create_minimal_ios_application_with_extension
  create_dump_codesign "//app:app.ipa" \
      "Payload/app.app/PlugIns/ext.appex" -vv
  do_build ios //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the provisioning profile is present when built for device.
function test_contains_provisioning_profile() {
  # Ignore the test for simulator builds.
  is_device_build ios || return 0

  create_common_files
  create_minimal_ios_application_with_extension
  do_build ios //app:app || fail "Should build"

  # Verify that the IPA contains the provisioning profile.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/embedded.mobileprovision"
}

# Tests that a sticker pack application contains the correct stub executable
# and automatically-injected plist entries.
function test_sticker_pack_extension() {
  create_common_files
  create_minimal_ios_application_with_extension \
      "apple_product_type.messages_sticker_pack_extension"
  create_dump_plist "//app:app.ipa" "Payload/app.app/PlugIns/ext.appex/Info.plist" \
      LSApplicationIsStickerPack

  do_build ios //app:dump_plist || fail "Should build"

  assert_equals "true" "$(cat "test-genfiles/app/LSApplicationIsStickerPack")"

  # Ignore the check for simulator builds.
  is_device_build ios || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "MessagesApplicationExtensionSupport/MessagesApplicationExtensionSupportStub"
}

# Tests that a sticker pack application builds correctly when its app icons are
# in an asset directory named ".stickersiconset".
function test_sticker_pack_builds_with_stickersiconset() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)

ios_extension(
    name = "ext",
    app_icons = ["@build_bazel_rules_apple//test/testdata/resources:sticker_pack_ios"],
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    product_type = apple_product_type.messages_sticker_pack_extension,
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  do_build ios //app:app || fail "Should build"
}

# Tests that a sticker pack application fails to build and emits a reasonable
# error message if its app icons are in an asset directory named ".appiconset".
function test_sticker_pack_fails_with_appiconset() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)

ios_extension(
    name = "ext",
    app_icons = ["@build_bazel_rules_apple//test/testdata/resources:app_icons_ios"],
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    product_type = apple_product_type.messages_sticker_pack_extension,
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  ! do_build ios //app:app \
    || fail "Should fail build"

  expect_log "Message extensions must use Messages Extensions Icon Sets (named .stickersiconset)"
}

# Tests that if an application contains an extension with a bundle ID that is
# not the app's ID followed by at least another component, the build fails.
function test_extension_with_mismatched_bundle_id_fails_to_build() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "apple_product_type",
     "ios_application",
     "ios_extension",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.extension.bundle.id",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/Info-App.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
}
EOF

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF

  ! do_build ios //app:app || fail "Should not build"
  expect_log 'While processing target "//app:app"; the CFBundleIdentifier of ' \
      'the child target "//app:ext" should have "my.bundle.id." as its ' \
      'prefix, but found "my.extension.bundle.id".'
}

# Tests that a prebuilt static framework (i.e., objc_framework with is_dynamic
# set to False) is not bundled with the application or extension.
function test_prebuilt_static_framework_dependency() {
  create_common_files
  create_minimal_ios_application_and_extension_with_objc_framework static

  do_build ios //app:app || fail "Should build"

  # Verify that it's not bundled.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/fmwk"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/Info.plist"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/resource.txt"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/Headers/fmwk.h"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/Modules/module.modulemap"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appex/Frameworks/fmwk.framework/fmwk"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appex/Frameworks/fmwk.framework/Info.plist"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appex/Frameworks/fmwk.framework/resource.txt"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appexFrameworks/fmwk.framework/Headers/fmwk.h"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appexFrameworks/fmwk.framework/Modules/module.modulemap"
}

# Tests that a prebuilt dynamic framework (i.e., objc_framework with is_dynamic
# set to True) is bundled properly with the application.
function test_prebuilt_dynamic_framework_dependency() {
  create_common_files
  create_minimal_ios_application_and_extension_with_objc_framework dynamic

  do_build ios //app:app || fail "Should build"

  # Verify that the framework is bundled with the application and that the
  # binary, plist, and resources are included.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/fmwk"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/Info.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/resource.txt"

  # Verify that Headers and Modules directories are excluded.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/Headers/fmwk.h"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/fmwk.framework/Modules/module.modulemap"

  # Verify that the framework is not bundled with the extension.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appex/Frameworks/fmwk.framework/fmwk"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appex/Frameworks/fmwk.framework/Info.plist"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appex/Frameworks/fmwk.framework/resource.txt"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appexFrameworks/fmwk.framework/Headers/fmwk.h"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Plugins/ext.appexFrameworks/fmwk.framework/Modules/module.modulemap"
}

# Tests that the IPA contains bitcode symbols when bitcode is embedded.
function test_bitcode_symbol_maps_packaging() {
  # Bitcode is only availabe on device. Ignore the test for simulator builds.
  is_device_build ios || return 0

  create_common_files
  create_minimal_ios_application_with_extension

  do_build ios --apple_bitcode=embedded \
       //app:app || fail "Should build"

  assert_ipa_contains_bitcode_maps ios "test-bin/app/app.ipa" \
      "Payload/app.app/app"
  assert_ipa_contains_bitcode_maps ios "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/ext"
}

# Tests that the linkmap outputs are produced when --objc_generate_linkmap is
# present.
function test_linkmaps_generated() {
  create_common_files
  create_minimal_ios_application_with_extension
  do_build ios --objc_generate_linkmap \
      //app:ext || fail "Should build"

  declare -a archs=( $(current_archs ios) )
  for arch in "${archs[@]}"; do
    assert_exists "test-bin/app/ext_${arch}.linkmap"
  done
}

# Tests that ios_extension cannot be a depenency of objc_library.
function test_extension_under_library() {
cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_extension",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

objc_library(
    name = "upperlib",
    srcs = ["upperlib.m"],
    deps = [":ext"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.extension.bundle.id",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/upperlib.m <<EOF
int foo() { return 0; }
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) { return 0; }
EOF

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleSignature = "????";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF

  ! do_build ios //app:upperlib || fail "Should not build"
  expect_log 'does not have mandatory providers'
}


function test_application_and_extension_different_minimum_os() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "8.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  do_build ios //app:app || fail "Should build"
}

# Tests that the dSYM outputs are produced when --apple_generate_dsym is
# present and that the dSYM outputs of the extension are also propagated when
# the flag is set.
function test_all_dsyms_propagated() {
  create_common_files
  create_minimal_ios_application_with_extension
  do_build ios \
      --apple_generate_dsym \
      --define=bazel_rules_apple.propagate_embedded_extra_outputs=1 \
      //app:app || fail "Should build"

  assert_exists "test-bin/app/app.app.dSYM/Contents/Info.plist"
  assert_exists "test-bin/app/ext.appex.dSYM/Contents/Info.plist"

  declare -a archs=( $(current_archs ios) )
  for arch in "${archs[@]}"; do
    assert_exists \
        "test-bin/app/app.app.dSYM/Contents/Resources/DWARF/app_${arch}"
    assert_exists \
        "test-bin/app/ext.appex.dSYM/Contents/Resources/DWARF/ext_${arch}"
  done
}

run_suite "ios_extension bundling tests"
