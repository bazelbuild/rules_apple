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

# Integration tests for bundling iOS dynamic frameworks.

function set_up() {
  mkdir -p app
  mkdir -p framework
}

function tear_down() {
  rm -rf app
  rm -rf framework
}

# Usage: create_minimal_ios_framework_with_params [extension_safe] [minimum_os_version] [exported_symbols_lists]
#
# Creates the targets for a minimal iOS dynamic framework with
# the given values for extension_safe and minimum_os_version.
function create_minimal_ios_framework_with_params() {
  extension_safe="$1"; shift
  minimum_os_version="$1"; shift
  exported_symbols_lists="$1"; shift

  cat > framework/BUILD <<EOF
package(default_visibility = ["//app:__pkg__"])

load("@build_bazel_rules_apple//apple:ios.bzl", "ios_framework")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.framework.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    extension_safe = ${extension_safe},
    exported_symbols_lists = [":ExportDoStuff.exp"] + ${exported_symbols_lists},
    minimum_os_version = "${minimum_os_version}",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    deps = [":framework_dependent_lib"],
    data = [":structured_resources"],
)

apple_resource_group(
    name = "structured_resources",
    structured_resources = [":Resources"],
)

objc_library(
    name = "framework_dependent_lib",
    srcs = ["FrameworkDependent.m"],
)

filegroup(
    name = "Resources",
    srcs = glob(["Images/*.png"]),
)
EOF

  mkdir -p framework/Images
  cp -f $(rlocation build_bazel_rules_apple/test/testdata/resources/sample.png) \
      framework/Images/foo.png

  cat > framework/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > framework/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doStuff();
void dontCallMe();
void anotherFunction();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > framework/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}

void dontCallMe() {
  int *foo = NULL;
  *foo = 0;
}

void anotherFunction() {
  int *foo = NULL;
  *foo = 0;
}

EOF

  cat > framework/FrameworkDependent.m <<EOF
#import <Foundation/Foundation.h>

void frameworkDependent() {
  NSLog(@"frameworkDependent() called");
}
EOF

  cat > framework/ExportDoStuff.exp << EOF
_doStuff

EOF

  cat > framework/ExportDontCallMe.exp << EOF
_dontCallMe

EOF

}

# Creates the targets for a minimal iOS application and extension that both use
# the framework.
function create_minimal_ios_application_and_extension() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_extension"
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
    frameworks = ["//framework:framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    families = ["iphone"],
    frameworks = ["//framework:framework"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
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

# Tests that a warning is shown when an extension depends on a framework which
# is not marked extension_safe.
# TODO(cparsons): This should eventually cause failure instead of merely a
# warning.
function test_extension_depends_on_unsafe_framework() {
  create_minimal_ios_framework_with_params False "9.0" "[]"
  create_minimal_ios_application_and_extension
  do_build ios //app:app || fail "Should build"

  expect_log "not marked extension-safe"

  # Verify the application still builds, however.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Info.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Headers/Framework.h"

  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/extension.appex/Frameworks/"
}

run_suite "ios_framework bundling tests"
