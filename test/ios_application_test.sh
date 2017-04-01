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

# Integration tests for bundling simple iOS applications.

function set_up() {
  rm -rf app
  mkdir -p app
}

# Creates common source, targets, and basic plist for iOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "apple_product_type",
     "ios_application"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
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

# Usage: create_minimal_ios_application [product type]
#
# Creates a minimal iOS application target. The optional product type is
# the Skylark constant that should be set on the application using the
# `product_type` attribute.
function create_minimal_ios_application() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  product_type="${1:-}"

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
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

# Creates a minimal iOS application target that depends on an objc_framework.
#
# This function takes a required parameter denoting whether the framework is
# static or dynamic (corresponding to the framework's is_dynamic attribute).
function create_minimal_ios_application_with_objc_framework() {
  readonly framework_type="$1"

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [
        ":frameworkDependingLib",
        ":lib",
    ],
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

# Tests that the Info.plist in the packaged application has the correct content.
function test_plist_contents() {
  create_common_files
  create_minimal_ios_application
  create_dump_plist "//app:app.ipa" "Payload/app.app/Info.plist" \
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
  do_build ios 9.0 --ios_minimum_os=9.0 //app:dump_plist || fail "Should build"

  # Verify the values injected by the Skylark rule.
  assert_equals "app" "$(cat "test-genfiles/app/CFBundleExecutable")"
  assert_equals "my.bundle.id" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "app" "$(cat "test-genfiles/app/CFBundleName")"
  assert_equals "9.0" "$(cat "test-genfiles/app/MinimumOSVersion")"
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

# Tests that multiple infoplists are merged properly.
function test_multiple_plist_merging() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist", "Another.plist"],
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/Another.plist <<EOF
{
  AnotherKey = "AnotherValue";
}
EOF

  create_dump_plist "//app:app.ipa" "Payload/app.app/Info.plist" \
      CFBundleIdentifier \
      AnotherKey
  do_build ios 9.0 //app:dump_plist || fail "Should build"

  # Verify that we have keys from both plists.
  assert_equals "my.bundle.id" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "AnotherValue" "$(cat "test-genfiles/app/AnotherKey")"
}

# Tests that the dSYM outputs are produced when --apple_generate_dsym is
# present.
function test_dsyms_generated() {
  create_common_files
  create_minimal_ios_application
  do_build ios 9.0 --apple_generate_dsym //app:app || fail "Should build"

  assert_exists "test-bin/app/app.app.dSYM/Contents/Info.plist"

  declare -a archs=( $(current_archs ios) )
  for arch in "${archs[@]}"; do
    assert_exists \
        "test-bin/app/app.app.dSYM/Contents/Resources/DWARF/app_${arch}"
  done
}

# Tests that the IPA contains a valid signed application.
function test_application_is_signed() {
  create_common_files
  create_minimal_ios_application
  create_dump_codesign "//app:app.ipa" "Payload/app.app" -vv
  do_build ios 9.0 //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the provisioning profile is present when built for device.
function test_contains_provisioning_profile() {
  # Ignore the test for simulator builds.
  is_device_build ios || return 0

  create_common_files
  create_minimal_ios_application
  do_build ios 9.0 //app:app || fail "Should build"

  # Verify that the IPA contains the provisioning profile.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/embedded.mobileprovision"
}

# Tests that the IPA post-processor is executed and can modify the bundle.
function test_ipa_post_processor() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    ipa_post_processor = "post_processor.sh",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/post_processor.sh <<EOF
#!/bin/bash
WORKDIR="\$1"
echo "foo" > "\$WORKDIR/Payload/app.app/inserted_by_post_processor.txt"
EOF
  chmod +x app/post_processor.sh

  do_build ios 9.0 //app:app || fail "Should build"
  assert_equals "foo" "$(unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/inserted_by_post_processor.txt")"
}

# Tests that linkopts get passed to the underlying apple_binary target.
function test_linkopts_passed_to_binary() {
  # Bail out early if this is a Bitcode build; the -alias flag we use to test
  # this isn't compatible with Bitcode. That's ok; as long as the test passes
  # for non-Bitcode builds, we're good.
  is_bitcode_build && return 0

  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    linkopts = ["-alias", "_main", "_linkopts_test_main"],
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  do_build ios 9.0 //app:app || fail "Should build"

  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/app" |
      nm -j - | grep _linkopts_test_main \
      || fail "Could not find -alias symbol in binary; " \
              "linkopts may have not propagated"
}

# Tests that the PkgInfo file exists in the bundle and has the expected
# content.
function test_pkginfo_contents() {
  create_common_files
  create_minimal_ios_application
  do_build ios 9.0 //app:app || fail "Should build"

  assert_equals "APPL????" "$(unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/PkgInfo")"
}

# Tests that entitlements are added to the application correctly. For debug
# builds, we make sure that the appropriate Mach-O section is present; for
# release builds, we check the code signing.
function test_entitlements() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    entitlements = "entitlements.plist",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/entitlements.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>test-an-entitlement</key>
  <false/>
</dict>
</plist>
EOF

  if is_device_build ios ; then
    # For device builds, we verify that the entitlements are in the codesign
    # output.
    create_dump_codesign "//app:app.ipa" "Payload/app.app" -d --entitlements :-
    do_build ios 9.0 //app:dump_codesign || fail "Should build"

    assert_contains "<key>test-an-entitlement</key>" \
        "test-genfiles/app/codesign_output"
  else
    # For simulator builds, the entitlements are added as a Mach-O section in
    # the binary.
    do_build ios 9.0 //app:app || fail "Should build"

    unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/app" | \
        print_debug_entitlements - | \
        assert_contains "<key>test-an-entitlement</key>" -
  fi
}

# Tests that an iMessage application contains the appropriate stub executable
# and auto-injected plist keys.
function test_message_application() {
  create_common_files
  create_minimal_ios_application "apple_product_type.messages_application"
  create_dump_plist "//app:app.ipa" "Payload/app.app/Info.plist" \
      LSApplicationLaunchProhibited

  do_build ios 10.0 --ios_minimum_os=10.0 //app:dump_plist || fail "Should build"

  # Ignore the following checks for simulator builds.
  is_device_build ios || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "MessagesApplicationSupport/MessagesApplicationSupportStub"
  assert_equals "true" "$(cat "test-genfiles/app/LSApplicationLaunchProhibited")"
}

# Tests that applications can transitively depend on objc_bundle_library, and
# that the bundle library resources for the appropriate architecture are
# used in a multi-arch build.
function test_bundle_library_dependency() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [
        ":lib",
        ":resLib",
    ],
)

objc_library(
    name = "resLib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    bundles = [":appResources"],
)

objc_bundle_library(
    name = "appResources",
    resources = select({
        "@build_bazel_rules_apple//apple:ios_cpu_x86_64": ["foo_sim.txt"],
        "@build_bazel_rules_apple//apple:ios_cpu_i386": ["foo_sim.txt"],
        "@build_bazel_rules_apple//apple:ios_cpu_armv7": ["foo_device.txt"],
        "@build_bazel_rules_apple//apple:ios_cpu_arm64": ["foo_device.txt"],
    }),
)
EOF

  cat > app/foo_sim.txt <<EOF
foo_sim
EOF
  cat > app/foo_device.txt <<EOF
foo_device
EOF

  do_build ios 10.0 //app:app || fail "Should build"

  if is_device_build ios ; then
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/appResources.bundle/foo_device.txt"
  else
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/appResources.bundle/foo_sim.txt"
  fi
}

# Tests that a prebuilt static framework (i.e., objc_framework with is_dynamic
# set to False) is not bundled with the application.
function test_prebuilt_static_framework_dependency() {
  create_common_files
  create_minimal_ios_application_with_objc_framework static

  do_build ios 10.0 --ios_minimum_os=8.0 //app:app || fail "Should build"

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
}

# Tests that a prebuilt dynamic framework (i.e., objc_framework with is_dynamic
# set to True) is bundled properly with the application.
function test_prebuilt_dynamic_framework_dependency() {
  create_common_files
  create_minimal_ios_application_with_objc_framework dynamic

  do_build ios 10.0 --ios_minimum_os=8.0 //app:app || fail "Should build"

  # Verify that the binary, plist, and resources are included.
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
}

# Tests that the build fails if the user tries to provide their own value for
# the "binary" attribute.
function test_build_fails_if_binary_attribute_used() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    binary = ":ThisShouldNotBeAllowed",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF

  ! do_build ios 10.0 //app:app || fail "Should fail"
  expect_log "Do not provide your own binary"
}

run_suite "ios_application bundling tests"
