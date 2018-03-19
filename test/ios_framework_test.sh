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

# Creates framework and app targets with common resources with the given
# value for the dedupe_unbundled_resources attribute on ios_application.
function create_app_and_framework_with_common_resources() {
  dedupe_unbundled_resources="$1"; shift
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_extension",
     "ios_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    structured_resources = [
        ":AppResources",
        ":FrameworkResources",
    ],
)

filegroup(
    name = "AppResources",
    srcs = glob(["Images/app.png"]),
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    dedupe_unbundled_resources = ${dedupe_unbundled_resources},
    extensions = [":ext"],
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    dedupe_unbundled_resources = ${dedupe_unbundled_resources},
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
    extension_safe = 1,
    families = ["iphone"],
    infoplists = ["Info-Framework.plist"],
    minimum_os_version = "9.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    structured_resources = [":FrameworkResources"],
    bundles = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle",
        "@build_bazel_rules_apple//test/testdata/resources:bundle_library",
    ],
    alwayslink = 1,
)

filegroup(
    name = "FrameworkResources",
    srcs = glob(["Images/framework.png"]),
)
EOF


  mkdir -p app/Images
  cat > app/Images/app.png <<EOF
This is fake image for the app
EOF

  cat > app/Images/framework.png <<EOF
This is fake image for the framework
EOF

  cat > app/Info-Framework.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/Info-Ext.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
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

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > app/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF
}

# Usage: create_minimal_ios_framework_with_params [extension_safe] [minimum_os_version]
#
# Creates the targets for a minimal iOS dynamic framework with
# the given values for extension_safe and minimum_os_version.
function create_minimal_ios_framework_with_params() {
  extension_safe="$1"; shift
  minimum_os_version="$1"; shift

  cat > framework/BUILD <<EOF
package(default_visibility = ["//app:__pkg__"])

load("@build_bazel_rules_apple//apple:ios.bzl", "ios_framework")

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.framework.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    extension_safe = ${extension_safe},
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
    structured_resources = [":Resources"],
    alwayslink = 1,
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
cat > framework/Images/foo.png <<EOF
This is fake image
EOF

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

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > framework/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  cat > framework/FrameworkDependent.m <<EOF
#import <Foundation/Foundation.h>

void frameworkDependent() {
  NSLog(@"frameworkDependent() called");
}
EOF
}


# Creates the targets for a minimal iOS dynamic framework.
function create_minimal_ios_framework() {
  create_minimal_ios_framework_with_params True "9.0"
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
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF
}

# Usage: verify_resource_bundle_deduping [application_minimum_os] [framework_minimum_os]
#
# Verifies that resource bundles that are dependencies of a framework are
# bundled with the framework if no deduplication is happening.
function verify_resource_bundle_deduping() {
  application_minimum_os="$1"; shift
  framework_minimum_os="$1"; shift

  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [":framework_lib"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "${application_minimum_os}",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
    families = ["iphone"],
    infoplists = ["Info-Framework.plist"],
    linkopts = ["-application_extension"],
    minimum_os_version = "${framework_minimum_os}",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    bundles = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle",
        "@build_bazel_rules_apple//test/testdata/resources:bundle_library",
    ],
    alwayslink = 1,
)
EOF

  cat > app/Info-Framework.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
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

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > app/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  do_build ios //app:app || fail "Should build"
  # Assert that the framework contains the bundled files...
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/basic.bundle/basic_bundle.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/bundle_library.bundle/Assets.car"
  # ...and that the application doesn't.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library.bundle/"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/"
}

# Tests that the bundled .framework contains the expected files.
function test_framework_contains_expected_files() {
  create_minimal_ios_framework
  do_build ios //framework:framework || fail "Should build"

  assert_zip_contains "test-bin/framework/framework.zip" \
      "framework.framework/framework"
  assert_zip_contains "test-bin/framework/framework.zip" \
      "framework.framework/Info.plist"
  assert_zip_contains "test-bin/framework/framework.zip" \
      "framework.framework/Headers/Framework.h"
}

# Tests that an ios_framework builds fine without any version info
# since it isn't required.
function test_framework_no_versions() {
  create_minimal_ios_framework
  create_whole_dump_plist "//framework:framework" \
      "framework.framework/Info.plist"

  cat > framework/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
}
EOF

  do_build ios //framework:dump_whole_plist || fail "Should build"

  assert_not_contains "CFBundleVersion" \
      "test-genfiles/framework/dump_whole_plist.txt"
  assert_not_contains "CFBundleShortVersionString" \
      "test-genfiles/framework/dump_whole_plist.txt"
}

# Tests that the bundled application contains the framework but that the
# extension inside it does *not* contain another copy.
function test_application_contains_expected_files() {
  create_minimal_ios_framework
  create_minimal_ios_application_and_extension
  do_build ios //app:app || fail "Should build"

  expect_not_log "not marked extension-safe"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Info.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Headers/Framework.h"

  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/extension.appex/Frameworks/"
}

# Verifies that apps with frameworks are still signed at the root.
function test_framework_bundle_codesigning() {
  create_minimal_ios_framework
  create_minimal_ios_application_and_extension
  create_dump_codesign "//app:app.ipa" \
      "Payload/app.app/Frameworks/framework.framework" -vv

  do_build ios //app:dump_codesign || fail "Should build"
  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Verifies that apps with frameworks are still signed at the root.
function test_app_with_framework_bundle_codesigning() {
  create_minimal_ios_framework
  create_minimal_ios_application_and_extension
  create_dump_codesign "//app:app.ipa" "Payload/app.app" -vv
  do_build ios //app:dump_codesign || fail "Should build"
  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that resources that both apps and frameworks depend on are present
# in the .framework directory and that the symbols are only present in the
# framework binary.
function test_framework_resources() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [":lib_with_resources"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
    families = ["iphone"],
    infoplists = ["Info-Framework.plist"],
    linkopts = ["-application_extension"],
    minimum_os_version = "9.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    deps = [":lib_with_resources"],
    alwayslink = 1,
)

objc_library(
    name = "lib_with_resources",
    srcs = ["foo.m"],
    structured_resources = [":Resources"],
)

filegroup(
    name = "Resources",
    srcs = glob(["Images/*.png"]),
)
EOF

mkdir -p app/Images
cat > app/Images/foo.png <<EOF
This is fake image
EOF

  cat > app/Info-Framework.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
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

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > app/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  cat > app/foo.m <<EOF
#import <Foundation/Foundation.h>

@interface Foo : NSObject
@end

@implementation Foo
- (void)fooFunction {
}
@end
EOF

  do_build ios //app:app || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/foo.png"
  assert_binary_not_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/app" "fooFunction"
  assert_binary_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework" "fooFunction"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/foo.png"
}

# Tests that a framework is present in the top level application
# bundle in the case that only extensions depend on the framework
# and the application itself does not.
function test_extension_propagates_framework_bundle() {
  create_minimal_ios_framework

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
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF

  do_build ios //app:app || fail "Should build"
  # The main bundle should contain the framework...
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Info.plist"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Headers/Framework.h"
  # The extension bundle should be intact, but have no inner framework.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/ext"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Frameworks/framework.framework/framework"
}

# Tests that root-level resources depended on by both an application and its
# framework end up in both if deduping isn't explicitly enabled.
function test_root_level_resource_deduping_off() {
  create_app_and_framework_with_common_resources False

  do_build ios //app:app || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/framework.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/framework.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Images/framework.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/app.png"
}


# Tests that root-level resources depended on by both an application and its
# framework end up in the framework only if resource dedupng is on.
function test_root_level_resource_deduping_on() {
  create_app_and_framework_with_common_resources True

  do_build ios //app:app || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/framework.png"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/framework.png"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Images/framework.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/app.png"
}

# Tests that different root-level resources with the same name are not
# deduped between framework and app.
function test_common_root_level_resource_name() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    structured_resources = [
        ":AppResources",
    ],
)

filegroup(
    name = "AppResources",
    srcs = glob(["Images/common.png"]),
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    frameworks = ["//framework:framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)
EOF

cat > framework/BUILD <<EOF
package(default_visibility = ["//app:__pkg__"])

load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_framework"
    )

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
    families = ["iphone"],
    infoplists = ["Info-Framework.plist"],
    linkopts = ["-application_extension"],
    minimum_os_version = "9.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    structured_resources = [":FrameworkResources"],
    alwayslink = 1,
)

filegroup(
    name = "FrameworkResources",
    srcs = glob(["Images/common.png"]),
)
EOF

  mkdir -p app/Images
  cat > app/Images/common.png <<EOF
This is fake image for the app
EOF

  mkdir -p framework/Images
  cat > framework/Images/common.png <<EOF
This is fake image for the framework
EOF

  cat > framework/Info-Framework.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
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

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > framework/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > framework/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  do_build ios //app:app || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/common.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/common.png"
}


function test_resource_bundle_is_in_framework_same_min_os() {
  verify_resource_bundle_deduping "9.0" "9.0"
}

function test_resource_bundle_is_in_framework_different_min_os() {
  verify_resource_bundle_deduping "8.0" "9.0"
}

# Tests that resource bundles that are dependencies of a framework are
# bundled with the framework if no deduplication is happening.
function test_resource_bundle_is_in_framework() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
    families = ["iphone"],
    infoplists = ["Info-Framework.plist"],
    linkopts = ["-application_extension"],
    minimum_os_version = "9.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    bundles = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle",
        "@build_bazel_rules_apple//test/testdata/resources:bundle_library",
    ],
    alwayslink = 1,
)
EOF

  cat > app/Info-Framework.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
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

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > app/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  create_dump_plist "//app:app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/bundle_library.bundle/Info.plist" \
      CFBundleIdentifier CFBundleName
  do_build ios //app:dump_plist || fail "Should build"

  # Verify the values injected by the Skylark rule for bundle_library's
  # info.plist
  assert_equals "org.bazel.bundle-library" \
      "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "bundle_library.bundle" \
      "$(cat "test-genfiles/app/CFBundleName")"

  # Assert that the framework contains the bundled files...
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/basic.bundle/basic_bundle.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/bundle_library.bundle/Assets.car"
  # ...and that the application doesn't.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/bundle_library.bundle/Assets.car"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle/basic_bundle.txt"
}

# Test that if an ios_framework target depends on a prebuilt framework (i.e.,
# objc_framework), that the inner framework is propagated up to the application
# and not nested in the outer framework.
function test_framework_depends_on_prebuilt_framework() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    frameworks = [":outer_framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_framework(
    name = "outer_framework",
    hdrs = ["OuterFramework.h"],
    bundle_id = "my.bundle.id.framework",
    families = ["iphone"],
    infoplists = ["Info-Framework.plist"],
    linkopts = ["-application_extension"],
    minimum_os_version = "9.0",
    deps = [
        ":inner_framework",
        ":outer_framework_lib",
    ],
)

objc_library(
    name = "outer_framework_lib",
    srcs = [
        "OuterFramework.h",
        "OuterFramework.m",
    ],
    alwayslink = 1,
)

objc_framework(
    name = "inner_framework",
    framework_imports = glob(["inner_framework.framework/**"]),
    is_dynamic = True,
)
EOF

  mkdir -p app/inner_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_dylib_lipobin) \
      app/inner_framework.framework/inner_framework

  cat > app/inner_framework.framework/Info.plist <<EOF
Dummy plist
EOF

  cat > app/inner_framework.framework/resource.txt <<EOF
Dummy resource
EOF

  mkdir -p app/inner_framework.framework/Headers
  cat > app/inner_framework.framework/Headers/fmwk.h <<EOF
This shouldn't get included
EOF

  mkdir -p app/inner_framework.framework/Modules
  cat > app/inner_framework.framework/Headers/module.modulemap <<EOF
This shouldn't get included
EOF

  cat > app/Info-Framework.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
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

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/OuterFramework.h <<EOF
#ifndef OUTER_FRAMEWORK_OUTER_FRAMEWORK_H_
#define OUTER_FRAMEWORK_OUTER_FRAMEWORK_H_

void outer();

#endif  // OUTER_FRAMEWORK_OUTER_FRAMEWORK_H_
EOF

  cat > app/OuterFramework.m <<EOF
#import <Foundation/Foundation.h>

void outer() {
  NSLog(@"Outer framework method called\n");
}
EOF

  cat > app/InnerFramework.h <<EOF
#ifndef INNER_FRAMEWORK_INNER_FRAMEWORK_H_
#define INNER_FRAMEWORK_INNER_FRAMEWORK_H_

void inner();

#endif  // INNER_FRAMEWORK_INNER_FRAMEWORK_H_
EOF

  cat > app/InnerFramework.m <<EOF
#import <Foundation/Foundation.h>

void inner() {
  NSLog(@"Inner framework method called\n");
}
EOF

  do_build ios //app:app || fail "Should build"

  # Assert that the inner framework was propagated to the application...
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/inner_framework.framework/inner_framework"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/inner_framework.framework/resource.txt"

  # ...and they aren't in the outer framework.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/outer_framework.framework/Frameworks/inner_framework.framework/inner_framework"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/outer_framework.framework/Frameworks/inner_framework.framework/resource.txt"
}

# Tests that a warning is shown when an extension depends on a framework which
# is not marked extension_safe.
# TODO(cparsons): This should eventually cause failure instead of merely a
# warning.
function test_extension_depends_on_unsafe_framework() {
  create_minimal_ios_framework_with_params False "9.0"
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

# Tests that an App->Framework->Framework dependency is handled properly. (That
# a framework that is not directly depended on by the app is still pulled into
# the app, and symbols end up in the correct binaries.)
function test_indirect_framework() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_framework",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [":framework_dependent_lib"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    frameworks = [":framework"],
    infoplists = ["Info-App.plist", "Info-Common.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_framework(
    name = "depframework",
    hdrs = ["DepFramework.h"],
    bundle_id = "my.depframework.id",
    families = ["iphone"],
    infoplists = ["Framework-Info.plist", "Info-Common.plist"],
    minimum_os_version = "9.0",
    deps = [":dep_framework_lib"],
    dedupe_unbundled_resources = True,
)

ios_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.framework.id",
    frameworks = [":depframework"],
    families = ["iphone"],
    infoplists = ["Framework-Info.plist", "Info-Common.plist"],
    minimum_os_version = "9.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    deps = [":framework_dependent_lib"],
    alwayslink = 1,
)

objc_library(
    name = "dep_framework_lib",
    srcs = [
        "DepFramework.h",
        "DepFramework.m",
    ],
    deps = [":framework_dependent_lib"],
    alwayslink = 1,
)

objc_library(
    name = "framework_dependent_lib",
    srcs = ["FrameworkDependent.m"],
    structured_resources = [":Resources"],
    alwayslink = 1,
)

filegroup(
    name = "Resources",
    srcs = glob(["Images/*.png"]),
)
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/Info-Common.plist <<EOF
{
  "CommonKey" = "CommonValue";
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

mkdir -p app/Images
cat > app/Images/foo.png <<EOF
This is fake image
EOF

  cat > app/Framework-Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/Framework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > app/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  cat > app/DepFramework.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_H_
#define FRAMEWORK_FRAMEWORK_H_

void doDepStuff();

#endif  // FRAMEWORK_FRAMEWORK_H_
EOF

  cat > app/DepFramework.m <<EOF
#import <Foundation/Foundation.h>

void doDepStuff() {
  NSLog(@"Framework method called\n");
}
EOF
  cat > app/FrameworkDependent.m <<EOF
#ifndef FRAMEWORK_FRAMEWORK_DEPENDENT_H_
#define FRAMEWORK_FRAMEWORK_DEPENDENT_H_

void frameworkDependent();
EOF
  cat > app/FrameworkDependent.m <<EOF
#import <Foundation/Foundation.h>

void frameworkDependent() {
  NSLog(@"frameworkDependent() called");
}
EOF
  create_dump_plist --suffix app "//app:app.ipa" \
      "Payload/app.app/Info.plist" \
      CFBundleIdentifier CommonKey
  create_dump_plist --suffix framework "//app:app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Info.plist" \
      CFBundleIdentifier CommonKey
  create_dump_plist --suffix depframework "//app:app.ipa" \
      "Payload/app.app/Frameworks/depframework.framework/Info.plist" \
      CFBundleIdentifier CommonKey

  do_build ios //app:dump_plist_app //app:dump_plist_framework \
      //app:dump_plist_depframework || fail "Should build"

  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/foo.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/depframework.framework/Images/foo.png"

  assert_binary_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/depframework.framework/depframework" \
      "frameworkDependent"
  assert_binary_not_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework" \
      "frameworkDependent"
  assert_binary_not_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/app" "frameworkDependent"

  # They all have Info.plists with the right bundle ids (even though the
  # frameworks share a comment infoplists entry for it).
  assert_equals "my.bundle.id" \
      "$(cat "test-genfiles/app/CFBundleIdentifier_app")"
  assert_equals "my.framework.id" \
      "$(cat "test-genfiles/app/CFBundleIdentifier_framework")"
  assert_equals "my.depframework.id" \
      "$(cat "test-genfiles/app/CFBundleIdentifier_depframework")"

  # They also all share a common file to add a custom key, ensure that
  # isn't duped away because of the overlap.
  assert_equals "CommonValue" \
      "$(cat "test-genfiles/app/CommonKey_app")"
  assert_equals "CommonValue" \
      "$(cat "test-genfiles/app/CommonKey_framework")"
  assert_equals "CommonValue" \
      "$(cat "test-genfiles/app/CommonKey_depframework")"
}

# Verifies that, when an extension depends on a framework with different
# minimum_os, symbol subtraction still occurs.
function test_differing_minimum_os() {
  create_minimal_ios_framework_with_params True "8.0"

cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_extension"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = ["//framework:framework_lib"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    families = ["iphone"],
    frameworks = ["//framework:framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "8.0",
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
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  NSExtension = {
    NSExtensionPrincipalClass = "DummyValue";
    NSExtensionPointIdentifier = "com.apple.widget-extension";
  };
}
EOF

  do_build ios //app:app || fail "Should build"

  assert_binary_not_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/ext" "doStuff"
  assert_binary_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework" "doStuff"
}

# Test that if an ios_framework target depends on a prebuilt static library
# framework (i.e., objc_framework), that the inner framework is propagated up
# to the application and not nested in the outer framework.
function test_framework_depends_on_prebuilt_static_framework() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [
        ":inner_framework",
    ],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    frameworks = [":outer_framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [
        ":lib",
    ],
)

ios_framework(
    name = "outer_framework",
    hdrs = ["OuterFramework.h"],
    bundle_id = "my.bundle.id.framework",
    families = ["iphone"],
    infoplists = ["Info-Framework.plist"],
    linkopts = ["-application_extension"],
    # Verify that deduping happens even for different minimum OS from the app.
    minimum_os_version = "10.0",
    deps = [
        ":outer_framework_lib",
    ],
)

objc_library(
    name = "outer_framework_lib",
    srcs = [
        "OuterFramework.h",
        "OuterFramework.m",
    ],
    deps = [
        ":inner_framework",
    ],
    alwayslink = 1,
)

genrule(
    name = "gen_static_framework",
    srcs = [":inner_framework_pregen"],
    outs = ["InnerFramework.framework/InnerFramework"],
    cmd = "cp \$< \$@",
)

objc_framework(
    name = "inner_framework",
    framework_imports = glob(["InnerFramework.framework/**"]) + ["InnerFramework.framework/InnerFramework"],
)
EOF

  mkdir -p app/InnerFramework.framework
  mkdir -p app/InnerFramework.framework/Headers

  cat > app/InnerFramework.framework/Info.plist <<EOF
Dummy plist
EOF

  cat > app/InnerFramework.framework/Headers/InnerFramework.h <<EOF
#ifndef INNER_FRAMEWORK_INNER_FRAMEWORK_H_
#define INNER_FRAMEWORK_INNER_FRAMEWORK_H_

void doStuff();

#endif  // INNER_FRAMEWORK_INNER_FRAMEWORK_H_
EOF
  cp app/InnerFramework.framework/Headers/InnerFramework.h app/InnerFramework.h

  cat > app/Info-Framework.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
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

  cat > app/main.m <<EOF
#import <InnerFramework/InnerFramework.h>

int main(int argc, char **argv) {
  doStuff();
  return 0;
}
EOF

  cat > app/OuterFramework.h <<EOF
#ifndef OUTER_FRAMEWORK_OUTER_FRAMEWORK_H_
#define OUTER_FRAMEWORK_OUTER_FRAMEWORK_H_

void outer();

#endif  // OUTER_FRAMEWORK_OUTER_FRAMEWORK_H_
EOF

  cat > app/OuterFramework.m <<EOF
#import <Foundation/Foundation.h>
#import <InnerFramework/InnerFramework.h>

void outer() {
  doStuff();
  NSLog(@"Outer framework method called\n");
}
EOF

  mkdir -p staticlib

  cat > staticlib/BUILD <<EOF
genrule(
    name = "gen_staticlib",
    srcs = [":dostuff_staticlib_lipo.a"],
    outs = ["staticlib.a"],
    cmd = "cp \$< \$@",
)

apple_static_library(
    name = "dostuff_staticlib",
    platform_type = "ios",
    deps = [":dostuff_lib"],
)

objc_library(
    name = "dostuff_lib",
    srcs = [":dostuff.m"],
)
EOF

  cat > staticlib/dostuff.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"doStuff called\n");
}
EOF

  do_build ios //staticlib:gen_staticlib \
      || fail "Should build static lib"

  cp test-genfiles/staticlib/staticlib.a \
      app/inner_framework_pregen

  do_build ios //app:app -s || fail "Should build"

  assert_binary_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/outer_framework.framework/outer_framework" "doStuff"
  assert_binary_not_contains ios "test-bin/app/app.ipa" \
      "Payload/app.app/app" "doStuff"
}

run_suite "ios_framework bundling tests"
