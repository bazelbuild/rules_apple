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

# Integration tests for bundling simple iOS applications with resources.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for iOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

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
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF
}

# Tests that various nonlocalized resource types are bundled correctly with
# the application (at the top-level, rather than inside an .lproj directory).
function test_nonlocalized_processed_resources() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    asset_catalogs = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
    ],
    datamodels = [
        "@build_bazel_rules_apple//test/testdata/resources:unversioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:versioned_datamodel",
    ],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:mapping_model",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.plist",
        "@build_bazel_rules_apple//test/testdata/resources:sample.png",
    ],
    storyboards = [
        "@build_bazel_rules_apple//test/testdata/resources:storyboard_ios.storyboard",
    ],
    strings = [
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
    ],
    xibs = [
        "@build_bazel_rules_apple//test/testdata/resources:view_ios.xib",
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that at least one name shows up in the asset catalog. (The file
  # format is a black box to us, but we can at a minimum grep the name out
  # because it's visible in the raw bytes).
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/Assets.car"
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/Assets.car" | \
      grep "star_iphone" > /dev/null || \
      fail "Did not find star_iphone in Assets.car"

  # Verify Core Data models.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/unversioned_datamodel.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v1.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/v2.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/versioned_datamodel.momd/VersionInfo.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/mapping_model.cdm"

  # Verify compiled storyboards.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/storyboard_ios.storyboardc/"

  # Verify png copied.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/sample.png"

  # Verify strings and plists (that they exist and that they are in binary
  # format).
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.plist"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.plist" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  # Verify compiled NIBs. Note that NIB folders might have different structures
  # depending on the minimum OS version passed to ibtool (in fact, they can
  # vary between directories to simple files). In this case, we verify the
  # format for a minimum OS version of 9.0, as passed above.
  assert_zip_contains "test-bin/app/app.ipa" "Payload/app.app/view_ios.nib"
}

# Tests that empty strings files can be processed.
function test_empty_strings_files() {
  create_common_files

  touch app/empty.strings

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    strings = [
        "empty.strings",
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify strings and plists (that they exist and that they are in binary
  # format).
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/empty.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/empty.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."
}

# Tests bundling a Resources folder as top level would fail with a nicer message.
function test_invalid_top_level_directory() {
  create_common_files
  mkdir -p app/Resources

  touch app/Resources/some.file

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    structured_resources = [
        "Resources/some.file",
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app && fail "Should fail"
  expect_log "For ios bundles, the following top level directories are invalid: Resources."
}

# Tests that various localized resource types are bundled correctly with the
# application (preserving their parent .lproj directory).
function test_localized_processed_resources() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    asset_catalogs = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_assets_ios",
    ],
    datamodels = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_datamodel",
    ],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_plists",
    ],
    storyboards = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_storyboards_ios",
    ],
    strings = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_strings",
    ],
    xibs = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_xibs_ios",
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios --define "apple.locales_to_include=all" //app:app || fail "Should build"

  # Verify compiled storyboards.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/storyboard_ios.storyboardc/"

  # Verify strings and plists.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.plist"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.plist" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  # Verify compiled NIBs.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/view_ios.nib"

  # Verify compiled Assets.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/Assets.car"

  # Verify compiled Datamodel.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.mom"
}

# Tests that generic flattened but unprocessed resources are bundled correctly
# (preserving their .lproj directory). Structured resources do not apply here,
# because they are never treated as localizable.
function test_localized_unprocessed_resources() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_generic_resources"
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  # Localized resource stripping only occurs on
  do_build ios //app:app -c opt || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c dbg || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c fastbuild || fail "Should build"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c opt --define "apple.locales_to_include=fr" || fail "Should build"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c dbg --define "apple.locales_to_include=fr" || fail "Should build"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c fastbuild --define "apple.locales_to_include=fr" || fail "Should build"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c opt --define "apple.locales_to_include=it" || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c dbg --define "apple.locales_to_include=it" || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c fastbuild --define "apple.locales_to_include=it" || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c opt --define "apple.locales_to_include=all" || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c dbg --define "apple.locales_to_include=all" || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

  do_build ios //app:app -c fastbuild --define "apple.locales_to_include=all" || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/it.lproj/localized.txt"

}

# Tests that the app icons and launch images are bundled with the application
# and that the partial Info.plist produced by actool is merged into the final
# plist.
function test_app_icons_and_launch_images() {
  create_common_files

  # For brevity, we only check a subset of the app icon and launch image keys.
  create_dump_plist "//app:app.ipa" "Payload/app.app/Info.plist" \
      CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0 \
      UILaunchImages:0:UILaunchImageName \
      UILaunchImages:0:UILaunchImageOrientation \
      UILaunchImages:0:UILaunchImageSize

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    app_icons = ["@build_bazel_rules_apple//test/testdata/resources:app_icons_ios"],
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    launch_images = ["@build_bazel_rules_apple//test/testdata/resources:launch_images_ios"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)
EOF

  do_build ios //app:dump_plist || fail "Should build"

  # Note that the names have been transformed by actool so they are no longer
  # the original filename.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/app_icon29x29@2x.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/launch_image-800-Portrait-736h@3x.png"

  assert_equals "app_icon29x29" \
      "$(cat "test-genfiles/app/CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles.0")"
  assert_equals "launch_image-800-Portrait-736h" \
      "$(cat "test-genfiles/app/UILaunchImages.0.UILaunchImageName")"
  assert_equals "Portrait" \
      "$(cat "test-genfiles/app/UILaunchImages.0.UILaunchImageOrientation")"
  assert_equals "{414, 736}" \
      "$(cat "test-genfiles/app/UILaunchImages.0.UILaunchImageSize")"
}

# Tests that the launch storyboard is bundled with the application and that
# the bundler inserts the correct key/value into Info.plist.
function test_launch_storyboard() {
  create_common_files
  create_dump_plist "//app:app.ipa" "Payload/app.app/Info.plist" \
      UILaunchStoryboardName

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    launch_storyboard = "@build_bazel_rules_apple//test/testdata/resources:launch_screen_ios.storyboard",
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)
EOF

  do_build ios //app:dump_plist || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/launch_screen_ios.storyboardc/"
  assert_equals "launch_screen_ios" \
      "$(cat "test-genfiles/app/UILaunchStoryboardName")"
}

# Tests that objc_bundle files are bundled correctly with the application.
function test_objc_bundle() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    bundles = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle"
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/basic_bundle.txt"

  # Verify strings and plists are in binary format.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/should_be_binary.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/should_be_binary.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/should_be_binary.plist"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/should_be_binary.plist" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  # Verify that a nested file is still nested (the resource processing
  # didn't flatten it).
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/nested/should_be_nested.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/nested/should_be_nested.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."
}

# Tests that objc_bundle files are bundled correctly with the application if
# the files have an owner-relative path that begins with something other than
# the bundle name (for example, "foo/Bar.bundle/..." instead of
# "Bar.bundle/..."). The path inside the bundle should start from the .bundle
# segment, not earlier.
function test_objc_bundle_with_extra_prefix_directories() {
  create_common_files

  mkdir -p app/foo/Bar.bundle
  cat >> app/foo/Bar.bundle/baz.txt <<EOF
dummy content
EOF

  cat >> app/BUILD <<EOF
objc_bundle(
    name = "bundle",
    bundle_imports = glob(["foo/Bar.bundle/**/*"]),
)

objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    bundles = [":bundle"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Bar.bundle/baz.txt"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/foo/Bar.bundle/baz.txt"
}

# Tests that objc_bundle_library resources are compiled and bundled correctly
# with the application. This test uses a bundle library with many types of
# resources, both localized and nonlocalized, and also a nested bundle.
function test_objc_bundle_library() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    bundles = [
        "@build_bazel_rules_apple//test/testdata/resources:bundle_library_ios"
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    minimum_os_version = "9.0",
    infoplists = ["Info.plist"],
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  create_dump_plist "//app:app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/Info.plist" \
      CFBundleIdentifier CFBundleName
  do_build ios --define "apple.locales_to_include=all" //app:dump_plist || fail "Should build"

  # Verify the values injected by the Skylark rule for bundle_library's
  # info.plist
  assert_equals "org.bazel.bundle-library-ios" \
      "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "bundle_library_ios.bundle" \
      "$(cat "test-genfiles/app/CFBundleName")"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/Assets.car"
  # Verify that one of the image names shows up in the asset catalog. (The file
  # format is a black box to us, but we can at a minimum grep the name out
  # because it's visible in the raw bytes).
  unzip_single_file "test-bin/app/app.ipa" \
        "Payload/app.app/bundle_library_ios.bundle/Assets.car" | \
      grep "star_iphone" > /dev/null || \
      fail "Did not find star_iphone in bundle_library_ios.bundle/Assets.car"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/basic.bundle/basic_bundle.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/it.lproj/localized.strings"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/it.lproj/localized.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/it.lproj/storyboard_ios.storyboardc/"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/it.lproj/view_ios.nib"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/mapping_model.cdm"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/nonlocalized_resource.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/storyboard_ios.storyboardc/"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/nested.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/unversioned_datamodel.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/versioned_datamodel.momd/v1.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/versioned_datamodel.momd/v2.mom"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/versioned_datamodel.momd/VersionInfo.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/view_ios.nib"

  # Verify that the processed structured resources are present and compiled (if
  # required).
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/nested.txt"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/generated.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/generated.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/should_be_binary.plist"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/should_be_binary.plist" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/should_be_binary.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library_ios.bundle/structured/should_be_binary.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."
}

# Tests that structured resources (both unprocessed ones, and processed ones
# like .strings/.plist) have their paths preserved in the final bundle.
function test_structured_resources() {
  create_common_files

  mkdir -p app/structured

  cat >> app/structured/nested.txt <<EOF
a nested file
EOF

  cat >> app/structured/nested.strings <<EOF
"nested" = "nested";
EOF

  cat >> app/structured/nested.plist <<EOF
{
  "nested" = "nested";
}
EOF

  cat >> app/BUILD <<EOF
genrule(
    name = "generate_structured_strings",
    outs = ["structured/generated.strings"],
    cmd = "echo '\"generated_structured_string\" = \"I like turtles!\";' > \$@",
)

objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    structured_resources = glob(["structured/**"]) + [":generate_structured_strings"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that the unprocessed structured resources are present.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/structured/nested.txt"

  # Verify that the processed structured resources are present and compiled.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/structured/nested.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/structured/nested.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/structured/nested.plist"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/structured/nested.plist" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  # And the generated one...
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/structured/generated.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/structured/generated.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."
}

# Tests that the Settings.bundle is bundled correctly with the application.
function test_settings_bundle() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    settings_bundle = "@build_bazel_rules_apple//test/testdata/resources:settings_bundle_ios",
    deps = [":lib"],
)
EOF

  do_build ios --define "apple.locales_to_include=all" //app:app || fail "Should build"

  # Verify that the files exist and are compiled in binary format.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Settings.bundle/Root.plist"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/Settings.bundle/Root.plist" | \
      grep -sq "^bplist00" || fail "Is not a binary file."

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Settings.bundle/it.lproj/Root.strings"
  unzip_single_file "test-bin/app/app.ipa" \
      "Payload/app.app/Settings.bundle/it.lproj/Root.strings" | \
      grep -sq "^bplist00" || fail "Is not a binary file."
}

# Tests that resources generated by a genrule, which produces a separate copy
# for each split configuration, are properly deduped before being processed.
function test_deduplicate_generated_resources() {
  create_common_files

  cat >> app/BUILD <<EOF
genrule(
    name = "generated_resource",
    srcs = [],
    outs = ["generated_resource.strings"],
    cmd = "echo 'foo = bar;' > \$@",
)

objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    strings = [
        ":generated_resource",
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/generated_resource.strings"
}

# Tests that a bundle can contain both .xcassets and .xcstickers. This verifies
# that resource grouping is working correctly and that the two folders get
# passed to the same actool invocation, despite their differing extensions.
function test_bundle_can_contain_xcassets_and_xcstickers() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
        "@build_bazel_rules_apple//test/testdata/resources:sticker_pack_ios",
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib", ":resources"],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Verify that the asset catalog exists.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Assets.car"

  # Verify that both names show up in the asset catalog. (The file format is a
  # black box to us, but we can at a minimum grep the name out because it's
  # visible in the raw bytes).
  unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/Assets.car" | \
      grep "star_iphone" > /dev/null || \
      fail "Did not find star_iphone in Assets.car"
  # TODO: b/77633270 the check the sticker packs are showing up, they don't
  # appear to be.
  #unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/Assets.car" | \
  #    grep "sequence" > /dev/null || \
  #    fail "Did not find sequence sticker in Assets.car"
}

run_suite "ios_application bundling with resources tests"
