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
    minimum_os_version = "9.0",
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

  do_build ios //app:app || fail "Should build"
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

  do_build ios //app:app || fail "Should build"
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
  do_build ios //app:dump_codesign_count || fail "Should build"

  # We checked two files, but there should be exactly one unique certificate.
  assert_equals "1" "$(cat "test-genfiles/app/codesign_count_output")"
}

# Tests that the bundler includes resources propagated by swift_library using
# the AppleResource provider.
function test_app_contains_resources_from_swift_library() {
  create_minimal_ios_application

  readonly module_name=EasyToSearchForModuleName

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
    module_name = "$module_name",
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_generic_resources",
        "@build_bazel_rules_apple//test/testdata/resources:localized_storyboards_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_strings_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_xibs_ios",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized_resource.txt",
        "@build_bazel_rules_apple//test/testdata/resources:storyboard_ios.storyboard",
        "@build_bazel_rules_apple//test/testdata/resources:unversioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:versioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:view_ios.xib",
    ],
    structured_resources = [
        "@build_bazel_rules_apple//test/testdata/resources:structured",
    ],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that nonlocalized processed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/Assets.car"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/unversioned_datamodel.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v1.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v2.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/VersionInfo.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/storyboard_ios.storyboardc/"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.strings"
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/view_ios.nib"

  # Verify nonlocalized unprocessed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized_resource.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/structured/nested.txt"

  # Verify localized resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/storyboard_ios.storyboardc/"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.strings"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/view_ios.nib"

  # Verify localized unprocessed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  # Verify that the module name is mentioned in the file. We can predict the
  # name of the .nib file inside the compiled storyboard based on its object
  # identifier and the fact that we're compiling with a particular minimum
  # iOS version.
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/storyboard_ios.storyboardc/UIViewController-mdN-da-fi0.nib" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/view_ios.nib" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/unversioned_datamodel.mom" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v1.mom" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v2.mom" \
      | grep "$module_name"
}

# Tests that swift_library properly propagates resources from transitive
# dependencies to the bundler.
function test_app_contains_resources_from_transitive_swift_library() {
  create_minimal_ios_application

  readonly module_name=EasyToSearchForModuleName

  cat > app/Dummy.swift <<EOF
struct Dummy {}
EOF

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
    deps = [":lib_with_resources"],
)

swift_library(
    name = "lib_with_resources",
    srcs = ["Dummy.swift"],
    module_name = "$module_name",
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_generic_resources",
        "@build_bazel_rules_apple//test/testdata/resources:localized_storyboards_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_strings_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_xibs_ios",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized_resource.txt",
        "@build_bazel_rules_apple//test/testdata/resources:storyboard_ios.storyboard",
        "@build_bazel_rules_apple//test/testdata/resources:unversioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:versioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:view_ios.xib",
    ],
    structured_resources = [
        "@build_bazel_rules_apple//test/testdata/resources:structured",
    ],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that nonlocalized processed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/Assets.car"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/unversioned_datamodel.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v1.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v2.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/VersionInfo.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/storyboard_ios.storyboardc/"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.strings"
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/view_ios.nib"

  # Verify nonlocalized unprocessed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized_resource.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/structured/nested.txt"

  # Verify localized resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/storyboard_ios.storyboardc/"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.strings"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/view_ios.nib"

  # Verify localized unprocessed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  # Verify that the module name is mentioned in the file. We can predict the
  # name of the .nib file inside the compiled storyboard based on its object
  # identifier and the fact that we're compiling with a particular minimum
  # iOS version.
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/storyboard_ios.storyboardc/UIViewController-mdN-da-fi0.nib" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/view_ios.nib" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/unversioned_datamodel.mom" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v1.mom" \
      | grep "$module_name"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v2.mom" \
      | grep "$module_name"
}

# Tests that swift_library targets have their intermediate compiled storyboards
# distinguished by module so that multiple link actions don't try to generate
# the same output.
function test_storyboard_intermediates_are_unique() {
  create_minimal_ios_application

  cat > app/Dummy.swift <<EOF
struct Dummy {}
EOF

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_storyboards_ios",
    ],
    deps = [":lib_with_resources"],
)

swift_library(
    name = "lib_with_resources",
    srcs = ["Dummy.swift"],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:storyboard_ios.storyboard",
    ],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that nonlocalized processed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/storyboard_ios.storyboardc/"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/storyboard_ios.storyboardc/"
}

# Tests that multiple swift_library targets can propagate asset catalogs and
# that they are all merged into a single Assets.car without conflicts.
function test_multiple_swift_libraries_can_propagate_asset_catalogs() {
  create_minimal_ios_application

  cat > app/Dummy.swift <<EOF
struct Dummy {}
EOF

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
    ],
    deps = [":lib2"],
)

swift_library(
    name = "lib2",
    srcs = ["Dummy.swift"],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:assets2_ios",
    ],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that a single Assets.car file is present.
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/Assets.car"

  # Verify that both image set names show up in the asset catalog. (The file
  # format is a black box to us, but we can at a minimum grep the name out
  # because it's visible in the raw bytes).
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/Assets.car" | \
      grep "star_iphone" || fail "Did not find star_iphone in Assets.car"
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/Assets.car" | \
      grep "star2_iphone" || fail "Did not find star2_iphone in Assets.car"
}

# Tests that swift_library build with sanitizer enabled.
# TODO(b/38455074): Also test that the asan dylib is packaged with the app.
function test_swift_builds_with_asan() {
  create_minimal_ios_application

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
)
EOF

  do_build ios //app:app \
      --experimental_objc_crosstool=all \
      --features=asan \
      --define=apple_swift_sanitize=address || fail "Should build"
}

run_suite "ios_application with Swift bundling tests"
