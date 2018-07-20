#!/bin/bash

# Copyright 2018 The Bazel Authors. All rights reserved.
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

# Integration tests for smart resource deduplication.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

function create_basic_project() {
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

  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application", "ios_framework")
objc_library(
    name = "shared_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    asset_catalogs = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
    ],
    bundles = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle",
    ],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.plist",
        "@build_bazel_rules_apple//test/testdata/resources:sample.png",
    ],
    strings = [
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
    ],
)

objc_library(
    name = "app_lib",
    srcs = ["main.m"],
    asset_catalogs = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
    ],
    bundles = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle",
    ],
    resources = [
        "@build_bazel_rules_apple//test/testdata/resources:sample.png",
    ],
    deps = [":shared_lib"],
)
EOF
}

function test_resources_only_in_framework() {
  create_basic_project

  cat >> app/BUILD <<EOF
ios_framework(
    name = "framework",
    bundle_id = "com.framework",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "8",
    deps = [":shared_lib"],
)

ios_application(
    name = "app",
    bundle_id = "com.app",
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info.plist"],
    minimum_os_version = "8",
    deps = [":app_lib"],
)
EOF

  do_build ios //app:app || fail "Should build"

  # This test makes sure that without smart deduplication, the naive duplication
  # method is preserved. When smart deduplication is enabled by default, this
  # test should be removed.

  # Verify framework has resources
  assert_assets_contains "test-bin/app/framework.zip" \
      "framework.framework/Assets.car" "star.png"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/nonlocalized.plist"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/nonlocalized.strings"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/sample.png"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/basic.bundle/basic_bundle.txt"

  # These resources are referenced by app_lib, but naive deduplication removes
  # them from the app bundle.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Assets.car"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/sample.png"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/basic_bundle.txt"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.plist"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.strings"
}

function test_resources_in_app_and_framework() {
  create_basic_project

  cat >> app/BUILD <<EOF
ios_framework(
    name = "framework",
    bundle_id = "com.framework",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "8",
    deps = [":shared_lib"],
)

ios_application(
    name = "app",
    bundle_id = "com.app",
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info.plist"],
    minimum_os_version = "8",
    deps = [":app_lib"],
)
EOF

  do_build ios //app:app --define=apple.experimental.smart_dedupe=1 \
      || fail "Should build"

  # Verify framework has resources
  assert_assets_contains "test-bin/app/framework.zip" \
      "framework.framework/Assets.car" "star.png"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/nonlocalized.plist"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/nonlocalized.strings"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/sample.png"
  assert_zip_contains "test-bin/app/framework.zip" \
      "framework.framework/basic.bundle/basic_bundle.txt"

  # Because app_lib directly references these assets, smart dedupe ensures that
  # they are present in the same bundle as the binary that has app_lib, which
  # in this case it's app.app.
  assert_assets_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Assets.car" "star.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/sample.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/basic_bundle.txt"

  # These resources are not referenced by app_lib, so they should not appear in
  # the app bundle
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.plist"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/nonlocalized.strings"
}

run_suite "smart resource deduplication tests"
