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

# Integration tests for bundling iMessage related targets.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for iOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
    "ios_imessage_application",
    "ios_imessage_extension",
    "ios_sticker_pack_extension",
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

# Usage: create_minimal_ios_application_with_extension
#
# Creates a minimal iOS application target with stickerpack extension.
function create_minimal_ios_application_with_stickerpack() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":stickerpack"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_sticker_pack_extension(
    name = "stickerpack",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    # TODO(b/120618397): Reenable the stickers.
    # sticker_assets = ["@build_bazel_rules_apple//test/testdata/resources:sticker_pack_ios"],
)
EOF
}

# Usage: create_minimal_ios_imessage_application_with_stickerpack
#
# Creates a minimal iOS iMessage application target with stickerpack extension.
function create_minimal_ios_imessage_application_with_stickerpack() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
ios_imessage_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extension = ":stickerpack",
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "8.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
)

ios_sticker_pack_extension(
    name = "stickerpack",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    # TODO(b/120618397): Reenable the stickers.
    # sticker_assets = ["@build_bazel_rules_apple//test/testdata/resources:sticker_pack_ios"],
)
EOF
}

# Tests that a sticker pack application contains the correct stub executable
# and automatically-injected plist entries.
function test_sticker_pack_extension() {
  create_common_files
  create_minimal_ios_application_with_stickerpack

  do_build ios //app:app || fail "Should build"

  # Ignore the check for simulator builds.
  is_device_build ios || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "MessagesApplicationExtensionSupport/MessagesApplicationExtensionSupportStub"
}

# Tests that a sticker pack application builds correctly when its app icons are
# in an asset directory named ".stickersiconset".
function test_sticker_pack_builds_with_stickersiconset() {
  create_common_files

  create_minimal_ios_application_with_stickerpack

  do_build ios //app:app || fail "Should build"

  # TODO(b/120618397): Reenable these assertions.
  # assert_zip_contains "test-bin/app/app.ipa" \
  #     "Payload/app.app/PlugIns/stickerpack.appex/sticker_pack.stickerpack/Info.plist"
  # assert_zip_contains "test-bin/app/app.ipa" \
  #     "Payload/app.app/PlugIns/stickerpack.appex/sticker_pack.stickerpack/sequence.png"
  # assert_zip_contains "test-bin/app/app.ipa" \
  #     "Payload/app.app/PlugIns/stickerpack.appex/sticker_pack.stickerpack/sticker.png"
}

# Tests that a sticker pack application fails to build and emits a reasonable
# error message if its app icons are in an asset directory named ".appiconset".
function test_sticker_pack_fails_with_appiconset() {
  create_common_files

    cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":stickerpack"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_sticker_pack_extension(
    name = "stickerpack",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    sticker_assets = ["@build_bazel_rules_apple//test/testdata/resources:app_icons_ios"],
)
EOF

  ! do_build ios //app:app || fail "Should fail build"

  # Check for the start of the log message
  expect_log "Message StickerPack extensions use an asset catalog named "
  # The 10 icons and the Contents.json should all be listed, so 11 hits.
  expect_log_n "testdata/resources/app_icons_ios.xcassets/app_icon.appiconset/" 11
}

# Tests that a message extension fails to build with *.appiconset assets.
function test_imessage_extension_builds_with_appiconset_fails() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":imessage_ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_imessage_extension(
    name = "imessage_ext",
    app_icons = ["@build_bazel_rules_apple//test/testdata/resources:app_icons_ios"],
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)
EOF

  ! do_build ios //app:app || fail "Should fail build"

  # Check for the start of the log message
  expect_log "Message extensions must use Messages Extensions Icon Sets "
  # The 10 icons and the Contents.json should all be listed, so 11 hits.
  expect_log_n "testdata/resources/app_icons_ios.xcassets/app_icon.appiconset/" 11
}

# Tests that a message extension builds correctly when its app icons are
# in an asset directory named ".stickersiconset".
function test_imessage_extension_builds_with_stickersiconset() {
  create_common_files

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":imessage_ext"],
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_imessage_extension(
    name = "imessage_ext",
    app_icons = ["@build_bazel_rules_apple//test/testdata/resources:message_ext_app_icon_ios"],
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)
EOF

  do_build ios //app:app || fail "Should build"

  # Spot check that a few icons end up correctly there.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/imessage_ext.appex/app_icon27x20@2x.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/imessage_ext.appex/app_icon32x24@2x.png"
}

function test_message_application() {
  create_common_files
  create_minimal_ios_imessage_application_with_stickerpack

  do_build ios //app:app || fail "Should build"

  # Ignore the following checks for simulator builds.
  is_device_build ios || return 0

  assert_zip_contains "test-bin/app/app.ipa" \
      "MessagesApplicationSupport/MessagesApplicationSupportStub"
}

run_suite "imessage bundling resource tests"
