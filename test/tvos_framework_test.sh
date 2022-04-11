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

# Integration tests for bundling tvOS dynamic frameworks.

function set_up() {
  mkdir -p app
  mkdir -p framework
}

function tear_down() {
  rm -rf app
  rm -rf framework
}

# Creates framework and app targets with common resources.
function create_app_and_framework_with_common_resources() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_extension",
     "tvos_framework"
    )
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

objc_library(
    name = "lib",
    srcs = ["main.m"],
    data = [
        ":lib_structured_resources",
    ],
)

apple_resource_group(
    name = "lib_structured_resources",
    structured_resources = [
        ":AppResources",
        ":FrameworkResources",
    ],
)

filegroup(
    name = "AppResources",
    srcs = glob(["Images/app.png"]),
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    frameworks = [":framework"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
    extension_safe = 1,
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
    data = [":framework_structured_resources"],
    alwayslink = 1,
)

apple_resource_group(
    name = "framework_structured_resources",
    structured_resources = [":FrameworkResources"],
)

filegroup(
    name = "FrameworkResources",
    srcs = glob(["Images/framework.png"]),
)
EOF

  mkdir -p app/Images
  cp -f $(rlocation build_bazel_rules_apple/test/testdata/resources/sample.png) \
      app/Images/app.png

  cp -f $(rlocation build_bazel_rules_apple/test/testdata/resources/sample.png) \
      app/Images/framework.png

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
  CFBundlePackageType = "XPC!";
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

# Usage: create_minimal_tvos_framework_with_params [extension_safe] [minimum_os_version]
#
# Creates the targets for a minimal tvOS dynamic framework with
# the given values for extension_safe and minimum_os_version.
function create_minimal_tvos_framework_with_params() {
  extension_safe="$1"; shift
  minimum_os_version="$1"; shift

  cat > framework/BUILD <<EOF
package(default_visibility = ["//app:__pkg__"])

load("@build_bazel_rules_apple//apple:tvos.bzl", "tvos_framework")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

tvos_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.framework.id",
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
    alwayslink = 1,
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

# Creates the targets for a minimal tvOS dynamic framework.
function create_minimal_tvos_framework() {
  create_minimal_tvos_framework_with_params True "9.0"
}

# Creates the targets for a minimal tvOS application and extension that both use
# the framework.
function create_minimal_tvos_application_and_extension() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_extension"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    frameworks = ["//framework:framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    frameworks = ["//framework:framework"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
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

# Usage: verify_resource_bundle_deduping [application_minimum_os] [framework_minimum_os]
#
# Verifies that resource bundles that are dependencies of a framework are
# bundled with the framework if no deduplication is happening.
#
# NOTE: This does now use xibs, storyboards, xcassets to avoid flake from
# ibtool/actool. See the note in the BUILD file.
function verify_resource_bundle_deduping() {
  application_minimum_os="$1"; shift
  framework_minimum_os="$1"; shift

  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [":framework_lib"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "${application_minimum_os}",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
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
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle",
        "@build_bazel_rules_apple//test/testdata/resources:simple_bundle_library",
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

  do_build tvos //app:app || fail "Should build"
  # Assert that the framework contains the bundled files...
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/basic.bundle/basic_bundle.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/simple_bundle_library.bundle/generated.strings"
  # ...and that the application doesn't.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/simple_bundle_library.bundle"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle"
}

# Tests that the bundled .framework contains the expected files.
function test_framework_contains_expected_files() {
  create_minimal_tvos_framework
  do_build tvos //framework:framework || fail "Should build"

  assert_zip_contains "test-bin/framework/framework.zip" \
      "framework.framework/framework"
  assert_zip_contains "test-bin/framework/framework.zip" \
      "framework.framework/Info.plist"
  assert_zip_contains "test-bin/framework/framework.zip" \
      "framework.framework/Headers/Framework.h"
}

# Tests that the correct rpath was added at link-time to the framework's binary.
# The rpath should match the framework bundle name.
function test_framework_has_correct_rpath() {
    create_minimal_tvos_framework
    cat > framework/BUILD <<EOF
package(default_visibility = ["//app:__pkg__"])

load("@build_bazel_rules_apple//apple:tvos.bzl", "tvos_framework")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

tvos_framework(
  name = "framework",
  hdrs = ["Framework.h"],
  bundle_id = "my.framework.id",
  bundle_name = "FrameworkBundleName",
  infoplists = ["Info.plist"],
  extension_safe = True,
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

  do_build tvos //framework:framework || fail "Should build"
  # Extracts binary from framework zip.
  unzip_single_file "test-bin/framework/framework.zip" "FrameworkBundleName.framework/FrameworkBundleName" \
      > "$TEST_TMPDIR/framework_binary"
  # Ensures binary contains correct rpath.
  otool -l "$TEST_TMPDIR/framework_binary" > "$TEST_TMPDIR/otool_output"
  assert_contains "@rpath/FrameworkBundleName.framework/FrameworkBundleName" "$TEST_TMPDIR/otool_output"
}

# Tests that a tvos_framework builds fine without any version info
# since it isn't required.
function test_framework_no_versions() {
  create_minimal_tvos_framework
  create_whole_dump_plist "//framework:framework" \
      "framework.framework/Info.plist"

  cat > framework/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
}
EOF

  do_build tvos //framework:dump_whole_plist || fail "Should build"

  assert_not_contains "CFBundleVersion" \
      "test-bin/framework/dump_whole_plist.txt"
  assert_not_contains "CFBundleShortVersionString" \
      "test-bin/framework/dump_whole_plist.txt"
}

# Tests that the bundled application contains the framework but that the
# extension inside it does *not* contain another copy.
function test_application_contains_expected_files() {
  create_minimal_tvos_framework
  create_minimal_tvos_application_and_extension
  do_build tvos //app:app || fail "Should build"

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

# Tests that resources that both apps and frameworks depend on are present
# in the .framework directory and that the symbols are only present in the
# framework binary.
function test_framework_resources() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_framework"
    )
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [":lib_with_resources"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
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
    data = [":structured_resources"],
)

apple_resource_group(
    name = "structured_resources",
    structured_resources = [":Resources"],
)

filegroup(
    name = "Resources",
    srcs = glob(["Images/*.png"]),
)
EOF

  mkdir -p app/Images
  cp -f $(rlocation build_bazel_rules_apple/test/testdata/resources/sample.png) \
      app/Images/foo.png

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

  do_build tvos //app:app || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/foo.png"
  assert_binary_not_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/app" "fooFunction"
  assert_binary_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework" "fooFunction"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/foo.png"
}

# Tests that a framework is present in the top level application
# bundle in the case that only extensions depend on the framework
# and the application itself does not.
function test_extension_propagates_framework_bundle() {
  create_minimal_tvos_framework

  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_extension"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    frameworks = ["//framework:framework"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
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

  do_build tvos //app:app || fail "Should build"
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
# framework end up in both bundles given that both bundles have explicit owners
# on the resources
function test_root_level_resource_smart_dedupe_keeps_resources() {
  create_app_and_framework_with_common_resources

  do_build tvos //app:app || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/framework.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/framework.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/Images/framework.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/app.png"
}

# Tests that different root-level resources with the same name are not
# deduped between framework and app.
function test_common_root_level_resource_name() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
    )
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

objc_library(
    name = "lib",
    srcs = ["main.m"],
    data = [
        ":lib_structured_resources",
    ],
)

apple_resource_group(
    name = "lib_structured_resources",
    structured_resources = [":AppResources"],
)

filegroup(
    name = "AppResources",
    srcs = glob(["Images/common.png"]),
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    frameworks = ["//framework:framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)
EOF

cat > framework/BUILD <<EOF
package(default_visibility = ["//app:__pkg__"])

load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_framework"
    )
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

tvos_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
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
    alwayslink = 1,
    data = [":framework_structured_resources"],
)

apple_resource_group(
    name = "framework_structured_resources",
    structured_resources = [":FrameworkResources"],
)

filegroup(
    name = "FrameworkResources",
    srcs = glob(["Images/common.png"]),
)
EOF

  mkdir -p app/Images
  cp -f $(rlocation build_bazel_rules_apple/test/testdata/resources/sample.png) \
      app/Images/common.png

  mkdir -p framework/Images
  cp -f $(rlocation build_bazel_rules_apple/test/testdata/resources/sample.png) \
      framework/Images/common.png

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

  do_build tvos //app:app || fail "Should build"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/common.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/common.png"
}


function test_resource_bundle_is_in_framework_same_min_os() {
  verify_resource_bundle_deduping "9.0" "9.0"
}

function test_resource_bundle_is_in_framework_different_min_os() {
  verify_resource_bundle_deduping "9.0" "10.0"
}

# Tests that resource bundles that are dependencies of a framework are
# bundled with the framework if no deduplication is happening.
#
# NOTE: This does now use xibs, storyboards, xcassets to avoid flake from
# ibtool/actool. See the note in the BUILD file.
function test_resource_bundle_is_in_framework() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_framework"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    frameworks = [":framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.bundle.id.framework",
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
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:basic_bundle",
        "@build_bazel_rules_apple//test/testdata/resources:simple_bundle_library",
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

  create_dump_plist "//app:app" \
      "Payload/app.app/Frameworks/framework.framework/simple_bundle_library.bundle/Info.plist" \
      CFBundleIdentifier CFBundleName
  do_build tvos //app:dump_plist || fail "Should build"

  # Verify the values injected by the Starlark rule for bundle_library's
  # info.plist
  assert_equals "org.bazel.simple-bundle-library" \
      "$(cat "test-bin/app/CFBundleIdentifier")"
  assert_equals "simple_bundle_library.bundle" \
      "$(cat "test-bin/app/CFBundleName")"

  do_build tvos //app:app || fail "Should build"

  # Assert that the framework contains the bundled files...
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/basic.bundle/basic_bundle.txt"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/simple_bundle_library.bundle/generated.strings"
  # ...and that the application doesn't.
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/simple_bundle_library.bundle"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/basic.bundle"
}

# Test that if a tvos_framework target depends on a prebuilt framework (i.e.,
# apple_dynamic_framework_import), that the inner framework is propagated up to the
# application and not nested in the outer framework.
#
# NOTE: This does not use xibs, storyboards, xcassets to avoid flake from
# ibtool/actool. See the note in the BUILD file.
function test_framework_depends_on_prebuilt_apple_framework_import() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_framework"
    )
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_dynamic_framework_import",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    frameworks = [":outer_framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_framework(
    name = "outer_framework",
    hdrs = ["OuterFramework.h"],
    bundle_id = "my.bundle.id.framework",
    infoplists = ["Info-Framework.plist"],
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

apple_dynamic_framework_import(
    name = "inner_framework",
    framework_imports = glob(["inner_framework.framework/**"]),
    features = ["-parse_headers"],
)
EOF

  mkdir -p app/inner_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_tvos_dylib_lipobin) \
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

  do_build tvos //app:app || fail "Should build"

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
  create_minimal_tvos_framework_with_params False "9.0"
  create_minimal_tvos_application_and_extension
  do_build tvos //app:app || fail "Should build"

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
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_framework",
    )
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [
        ":dep_framework_lib",
        ":framework_lib",
    ],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    frameworks = [":framework"],
    infoplists = ["Info-App.plist", "Info-Common.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_framework(
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.framework.id",
    frameworks = [":depframework"],
    infoplists = ["Framework-Info.plist", "Info-Common.plist"],
    minimum_os_version = "9.0",
    deps = [":framework_lib"],
)

tvos_framework(
    name = "depframework",
    hdrs = ["DepFramework.h"],
    bundle_id = "my.depframework.id",
    infoplists = ["Framework-Info.plist", "Info-Common.plist"],
    minimum_os_version = "9.0",
    deps = [":dep_framework_lib"],
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
    srcs = [
        "FrameworkDependent.m",
        "FrameworkDependent.h",
    ],
    alwayslink = 1,
    data = [":structured_resources"],
)

apple_resource_group(
    name = "structured_resources",
    structured_resources = [":Resources"],
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
  cp -f $(rlocation build_bazel_rules_apple/test/testdata/resources/sample.png) \
      app/Images/foo.png

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
  cat > app/FrameworkDependent.h <<EOF
#ifndef FRAMEWORK_FRAMEWORK_DEPENDENT_H_
#define FRAMEWORK_FRAMEWORK_DEPENDENT_H_

void frameworkDependent();
#endif  // FRAMEWORK_FRAMEWORK_DEPENDENT_H_
EOF
  cat > app/FrameworkDependent.m <<EOF
#import <Foundation/Foundation.h>

void frameworkDependent() {
  NSLog(@"frameworkDependent() called");
}
EOF
  create_dump_plist --suffix app "//app:app" \
      "Payload/app.app/Info.plist" \
      CFBundleIdentifier CommonKey
  create_dump_plist --suffix framework "//app:app" \
      "Payload/app.app/Frameworks/framework.framework/Info.plist" \
      CFBundleIdentifier CommonKey
  create_dump_plist --suffix depframework "//app:app" \
      "Payload/app.app/Frameworks/depframework.framework/Info.plist" \
      CFBundleIdentifier CommonKey

  do_build tvos //app:app || fail "Should build"

  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/foo.png"
  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/Images/foo.png"
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/depframework.framework/Images/foo.png"

  assert_binary_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/depframework.framework/depframework" \
      "frameworkDependent"
  assert_binary_not_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework" \
      "frameworkDependent"
  assert_binary_not_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/app" "frameworkDependent"

  # They all have Info.plists with the right bundle ids (even though the
  # frameworks share a comment infoplists entry for it).
  # They also all share a common file to add a custom key, ensure that
  # isn't duped away because of the overlap.

  do_build tvos //app:dump_plist_app || fail "Should build"

  assert_equals "my.bundle.id" \
      "$(cat "test-bin/app/CFBundleIdentifier_app")"
  assert_equals "CommonValue" \
      "$(cat "test-bin/app/CommonKey_app")"

  do_build tvos //app:dump_plist_framework || fail "Should build"

  assert_equals "my.framework.id" \
      "$(cat "test-bin/app/CFBundleIdentifier_framework")"
  assert_equals "CommonValue" \
      "$(cat "test-bin/app/CommonKey_framework")"

  do_build tvos //app:dump_plist_depframework || fail "Should build"

  assert_equals "my.depframework.id" \
      "$(cat "test-bin/app/CFBundleIdentifier_depframework")"
  assert_equals "CommonValue" \
      "$(cat "test-bin/app/CommonKey_depframework")"
}

# Verifies that, when an extension depends on a framework with different
# minimum_os, symbol subtraction still occurs.
function test_differing_minimum_os() {
  create_minimal_tvos_framework_with_params True "9.0"

cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_extension"
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = ["//framework:framework_lib"],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    extensions = [":ext"],
    frameworks = ["//framework:framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_extension(
    name = "ext",
    bundle_id = "my.bundle.id.extension",
    frameworks = ["//framework:framework"],
    infoplists = ["Info-Ext.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
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

  do_build tvos //app:app || fail "Should build"

  assert_binary_not_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/PlugIns/ext.appex/ext" "doStuff"
  assert_binary_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/framework.framework/framework" "doStuff"
}

# Test that if a tvos_framework target depends on a prebuilt static library
# framework (i.e., apple_dynamic_framework_import), that the inner framework is
# propagated up to the application and not nested in the outer framework.
function test_framework_depends_on_prebuilt_static_apple_framework_import() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_framework"
    )
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_static_framework_import",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
    deps = [
        ":inner_framework",
    ],
)

tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    frameworks = [":outer_framework"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [
        ":lib",
    ],
)

tvos_framework(
    name = "outer_framework",
    hdrs = ["OuterFramework.h"],
    bundle_id = "my.bundle.id.framework",
    infoplists = ["Info-Framework.plist"],
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

apple_static_framework_import(
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
    minimum_os_version = "9.0",
    platform_type = "tvos",
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

  do_build tvos //staticlib:gen_staticlib || fail "Should build static lib"

  cp test-bin/staticlib/staticlib.a \
      app/inner_framework_pregen

  do_build tvos //app:app -s || fail "Should build"

  assert_binary_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/outer_framework.framework/outer_framework" "doStuff"
  assert_binary_not_contains tvos "test-bin/app/app.ipa" \
      "Payload/app.app/app" "doStuff"
}

run_suite "tvos_framework bundling tests"
