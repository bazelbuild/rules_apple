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
load("@build_bazel_rules_apple//apple:resources.bzl",
     "apple_resource_group")
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

apple_resource_group(
    name = "structured_resources",
    structured_resources = [
        "@build_bazel_rules_apple//test/testdata/resources:structured",
    ],
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

# Tests that the bundler includes resources propagated by swift_library using
# the AppleResource provider.
function test_app_contains_resources_from_swift_library() {
  create_minimal_ios_application

  readonly module_name=EasyToSearchForModuleName

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
    data = [
        ":structured_resources",
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_generic_resources",
        "@build_bazel_rules_apple//test/testdata/resources:localized_storyboards_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_strings",
        "@build_bazel_rules_apple//test/testdata/resources:localized_xibs_ios",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized_resource.txt",
        "@build_bazel_rules_apple//test/testdata/resources:storyboard_ios.storyboard",
        "@build_bazel_rules_apple//test/testdata/resources:unversioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:versioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:view_ios.xib",
    ],
    module_name = "$module_name",
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
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/view_ios.nib/\?"

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
      "Payload/app.app/it.lproj/view_ios.nib/\?"

  # Verify localized unprocessed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  # TODO(b/131684083): We previously had other assertions that poked at the
  # individual compiled resources, but they became extremely fragile as of
  # Xcode 11 (the assumptions about the file structure no longer held).
  # Instead, we should test (with analysis time tests) that we pass the
  # correct module name to ibtool when we register the action.
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
    data = [
        ":structured_resources",
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_generic_resources",
        "@build_bazel_rules_apple//test/testdata/resources:localized_storyboards_ios",
        "@build_bazel_rules_apple//test/testdata/resources:localized_strings",
        "@build_bazel_rules_apple//test/testdata/resources:localized_xibs_ios",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized_resource.txt",
        "@build_bazel_rules_apple//test/testdata/resources:storyboard_ios.storyboard",
        "@build_bazel_rules_apple//test/testdata/resources:unversioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:versioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:view_ios.xib",
    ],
    module_name = "$module_name",
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that nonlocalized processed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/Assets.car"
  # Verify that one of the image names shows up in the asset catalog. (The file
  # format is a black box to us, but we can at a minimum grep the name out
  # because it's visible in the raw bytes).
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/Assets.car" | \
      grep "star_iphone" > /dev/null || \
      fail "Did not find star_iphone in Assets.car"
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
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/view_ios.nib/\?"

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
      "Payload/app.app/it.lproj/view_ios.nib/\?"

  # Verify localized unprocessed resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  # TODO(b/131684083): We previously had other assertions that poked at the
  # individual compiled resources, but they became extremely fragile as of
  # Xcode 11 (the assumptions about the file structure no longer held).
  # Instead, we should test (with analysis time tests) that we pass the
  # correct module name to ibtool when we register the action.
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
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_storyboards_ios",
    ],
    deps = [":lib_with_resources"],
)

swift_library(
    name = "lib_with_resources",
    srcs = ["Dummy.swift"],
    data = [
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
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
    ],
    deps = [":lib2"],
)

swift_library(
    name = "lib2",
    srcs = ["Dummy.swift"],
    data = [
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
      grep "star_iphone" > /dev/null || \
      fail "Did not find star_iphone in Assets.car"
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/Assets.car" | \
      grep "star2_iphone" > /dev/null || \
      fail "Did not find star2_iphone in Assets.car"
}

function test_can_compile_multiple_storyboards_in_bundle_root_from_multiple_swift_libraries() {
  create_minimal_ios_application

  cat > app/Dummy.swift <<EOF
struct Dummy {}
EOF

  # Make a local copy of the storyboards with other names, so they're treated as
  # different ones.
  cp -rf \
      $(rlocation build_bazel_rules_apple/test/testdata/resources/storyboard_ios.storyboard) \
      app/lib.storyboard
  cp -rf \
      $(rlocation build_bazel_rules_apple/test/testdata/resources/storyboard_ios.storyboard) \
      app/other.storyboard

  cat >> app/BUILD <<EOF
swift_library(
    name = "lib",
    srcs = ["AppDelegate.swift"],
    data = [
        "lib.storyboard",
    ],
    deps = [":other_lib"],
)

swift_library(
    name = "other_lib",
    srcs = ["Dummy.swift"],
    data = [
        "other.storyboard",
    ],
)
EOF

  do_build ios //app:app || fail "Should build"
}

run_suite "ios_application bundling resources with Swift bundling tests"
