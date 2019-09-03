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

# Integration tests for bundling simple macOS applications with resources.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for macOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:macos.bzl", "macos_application")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

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
    # TODO: asset_catalogs, storyboards, xibs
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:unversioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:versioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:mapping_model",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.plist",
        "@build_bazel_rules_apple//test/testdata/resources:sample.png",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app || fail "Should build"

  # TODO: Assets.car from asset_catalogs

  # Verify Core Data models.
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/unversioned_datamodel.mom"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/versioned_datamodel.momd/v1.mom"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/versioned_datamodel.momd/v2.mom"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/versioned_datamodel.momd/VersionInfo.plist"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/mapping_model.cdm"

  # TODO: storyboards

  # Verify png copied.
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/sample.png"

  # Verify strings and plists.
  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.strings"

  assert_plist_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.plist"

  # TODO: nibs from xibs.
}

# Tests that empty strings files can be processed.
function test_empty_strings_files() {
  create_common_files

  touch app/empty.strings

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "empty.strings",
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app || fail "Should build"

  # Verify strings.
  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/empty.strings"
}

# Tests that various localized resource types are bundled correctly with the
# application (preserving their parent .lproj directory).
function test_localized_processed_resources() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    # TODO: storyboards, xibs
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_plists",
        "@build_bazel_rules_apple//test/testdata/resources:localized_strings",
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app || fail "Should build"

  # TODO: storyboards

  # Verify strings and plists.
  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/it.lproj/localized.strings"

  assert_plist_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/it.lproj/localized.plist"

  # TODO: nibs from xibs.
}

function create_with_localized_unprocessed_resources() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:localized_generic_resources"
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF
}

# Tests that generic flattened but unprocessed resources are bundled correctly
# (preserving their .lproj directory). Structured resources do not apply here,
# because they are never treated as localizable.
function test_localized_unprocessed_resources() {
  create_with_localized_unprocessed_resources

  do_build macos //app:app || fail "Should build"
  expect_not_log "Please verify apple.locales_to_include is defined properly"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/it.lproj/localized.txt"
}

# Should generate a warning because 'sw'/Swahili doesn't match anything, but
# that things were filtered, so it could have been a typo.
function test_localized_unprocessed_resources_filter_all() {
  create_with_localized_unprocessed_resources

  do_build macos //app:app --define "apple.locales_to_include=sw" \
      || fail "Should build"
  expect_log_once "Please verify apple.locales_to_include is defined properly"
  expect_log_once "\[\"sw\"\]"
  assert_zip_not_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/it.lproj/localized.txt"
}

# Should not generate a warning because although 'fr' doesn't match anything
# nothing was filtered away (i.e. - no harm if it was a typo).
function test_localized_unprocessed_resources_filter_mixed() {
  create_with_localized_unprocessed_resources

  do_build macos //app:app --define "apple.locales_to_include=fr,it" \
      || fail "Should build"
  expect_not_log "Please verify apple.locales_to_include is defined properly"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/it.lproj/localized.txt"
}

# TODO: Something like the ios_application_resources_test.sh's
# test_app_icons_and_launch_images, but for the relevant bits for macOS.

# TODO: Something like the ios_application_resources_test.sh's
# test_launch_storyboard.

# Tests that apple_bundle_import files are bundled correctly with the
# application.
function test_apple_bundle_import() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle"
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/basic.bundle/basic_bundle.txt"

  # Verify strings and plists.
  assert_strings_is_text "test-bin/app/app.zip" \
      "app.app/Contents/Resources/basic.bundle/should_be_binary.strings"

  assert_plist_is_text "test-bin/app/app.zip" \
      "app.app/Contents/Resources/basic.bundle/should_be_binary.plist"

  # Verify that a nested file is still nested (the resource processing
  # didn't flatten it).
  assert_strings_is_text "test-bin/app/app.zip" \
      "app.app/Contents/Resources/basic.bundle/nested/should_be_nested.strings"
}

# Tests that apple_bundle_import files are bundled correctly with the
# application if the files have an owner-relative path that begins with
# something other than the bundle name (for example, "foo/Bar.bundle/..."
# instead of "Bar.bundle/..."). The path inside the bundle should start from the
# .bundle segment, not earlier.
function test_apple_bundle_import_with_extra_prefix_directories() {
  create_common_files

  mkdir -p app/foo/Bar.bundle
  cat >> app/foo/Bar.bundle/baz.txt <<EOF
dummy content
EOF

  cat >> app/BUILD <<EOF
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_bundle_import",
)

apple_bundle_import(
    name = "bundle",
    bundle_imports = glob(["foo/Bar.bundle/**"]),
)

objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [":bundle"],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/Bar.bundle/baz.txt"
  assert_zip_not_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/foo/Bar.bundle/baz.txt"
}

# Tests that apple_resource_bundle resources are compiled and bundled correctly
# with the application. This test uses a bundle library with many types of
# resources, both localized and nonlocalized, and also a nested bundle.
function test_apple_resource_bundle() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:bundle_library_macos"
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    minimum_os_version = "10.10",
    infoplists = ["Info.plist"],
    deps = [":lib", ":resources"],
)
EOF

  create_dump_plist "//app:app" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/Info.plist" \
      CFBundleIdentifier CFBundleName
  do_build macos //app:dump_plist || fail "Should build"

  # Verify the values injected by the Skylark rule for bundle_library's
  # info.plist
  assert_equals "org.bazel.bundle-library-macos" \
      "$(cat "test-bin/app/CFBundleIdentifier")"
  assert_equals "bundle_library_macos.bundle" \
      "$(cat "test-bin/app/CFBundleName")"

  do_build macos //app:app || fail "Should build"

  # TODO: Assets.car from asset_catalogs
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/basic.bundle/basic_bundle.txt"
  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/it.lproj/localized.strings"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/it.lproj/localized.txt"
  # TODO: localized storyboards.
  # TODO: localized nibs from xibs.
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/mapping_model.cdm"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/nonlocalized_resource.txt"
  # TODO: storyboards.
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/structured/nested.txt"
  # TODO: See note in testdata/resource/BUILD, objc_bundle_library targeting
  # macOS crashes bazel if given datamodels. Revisit when objc_bundle_library
  # is rewritten in skylark.
  #assert_zip_contains "test-bin/app/app.zip" \
  #    "app.app/Contents/Resources/bundle_library_macos.bundle/unversioned_datamodel.mom"
  #assert_zip_contains "test-bin/app/app.zip" \
  #    "app.app/Contents/Resources/bundle_library_macos.bundle/versioned_datamodel.momd/v1.mom"
  #assert_zip_contains "test-bin/app/app.zip" \
  #    "app.app/Contents/Resources/bundle_library_macos.bundle/versioned_datamodel.momd/v2.mom"
  #assert_zip_contains "test-bin/app/app.zip" \
  #    "app.app/Contents/Resources/bundle_library_macos.bundle/versioned_datamodel.momd/VersionInfo.plist"
  # TODO: nibs from xibs.

  # Verify that the processed structured resources are present and compiled (if
  # required).
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/structured/nested.txt"

  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/structured/generated.strings"

  assert_plist_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/structured/should_be_binary.plist"

  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/structured/should_be_binary.strings"
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
    data = [":structured_resources"],
)

apple_resource_group(
    name = "structured_resources",
    structured_resources = glob(["structured/**"]) + [":generate_structured_strings"],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app || fail "Should build"

  # Verify that the unprocessed structured resources are present.
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/structured/nested.txt"

  # Verify that the processed structured resources are present and compiled.
  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/structured/nested.strings"

  assert_plist_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/structured/nested.plist"

  # And the generated one...
  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/structured/generated.strings"
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
    data = [
        ":generated_resource",
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app || fail "Should build"

  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/generated_resource.strings"
}

# Tests strings and plists aren't compiled in fastbuild and dbg.
function test_compilation_mode_on_strings_and_plist_files() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.plist",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos --compilation_mode=opt //app:app || fail "Should build"

  assert_strings_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.strings"
  assert_plist_is_binary "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.plist"

 do_build macos --compilation_mode=fastbuild //app:app || fail "Should build"

  assert_strings_is_text "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.strings"
  assert_plist_is_text "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.plist"

 do_build macos --compilation_mode=dbg //app:app || fail "Should build"

  assert_strings_is_text "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.strings"
  assert_plist_is_text "test-bin/app/app.zip" \
      "app.app/Contents/Resources/nonlocalized.plist"
}

# Tests that the localizations from the base of the Resource folder are used to
# strip subfolder localizations with apple.trim_lproj_locales=1.
function test_bundle_localization_strip() {
  create_common_files

  mkdir -p app/fr.lproj
  touch app/fr.lproj/localized.strings

  cat >> app/BUILD <<EOF
objc_library(
    name = "resources",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:bundle_library_macos",
        "fr.lproj/localized.strings",
    ],
)

macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.10",
    deps = [":lib", ":resources"],
)
EOF

  do_build macos //app:app --define "apple.trim_lproj_locales=1" \
      || fail "Should build"

  # Verify the app has a `fr` localization and not an `it` localization.
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/fr.lproj/localized.strings"
  assert_zip_not_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/it.lproj/localized.strings"

  # Verify the `it` localization from the bundle is removed.
  assert_zip_not_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/it.lproj/localized.strings"
  assert_zip_contains "test-bin/app/app.zip" \
      "app.app/Contents/Resources/bundle_library_macos.bundle/fr.lproj/localized.strings"
}

run_suite "macos_application bundling with resources tests"
