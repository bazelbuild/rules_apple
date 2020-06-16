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
#
# NOTE: This does now use xibs, storyboards, xcassets to avoid flake from
# ibtool/actool. See the note in the BUILD file.
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

  do_build ios //app:app || fail "Should build"
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


# Tests that different root-level resources with the same name are not
# deduped between framework and app.
function test_common_root_level_resource_name() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
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
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")

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
#
# NOTE: This does now use xibs, storyboards, xcassets to avoid flake from
# ibtool/actool. See the note in the BUILD file.
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
  do_build ios //app:dump_plist || fail "Should build"

  # Verify the values injected by the Starlark rule for bundle_library's
  # info.plist
  assert_equals "org.bazel.simple-bundle-library" \
      "$(cat "test-bin/app/CFBundleIdentifier")"
  assert_equals "simple_bundle_library.bundle" \
      "$(cat "test-bin/app/CFBundleName")"

  do_build ios //app:app || fail "Should build"

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

# Tests that an App->Framework->Framework dependency is handled properly. (That
# a framework that is not directly depended on by the app is still pulled into
# the app, and symbols end up in the correct binaries.)
function test_indirect_framework() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
     "ios_framework",
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
    name = "framework",
    hdrs = ["Framework.h"],
    bundle_id = "my.framework.id",
    frameworks = [":depframework"],
    families = ["iphone"],
    infoplists = ["Framework-Info.plist", "Info-Common.plist"],
    minimum_os_version = "9.0",
    deps = [":framework_lib"],
)

ios_framework(
    name = "depframework",
    hdrs = ["DepFramework.h"],
    bundle_id = "my.depframework.id",
    families = ["iphone"],
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
    srcs = ["FrameworkDependent.m"],
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
  create_dump_plist --suffix app "//app:app" \
      "Payload/app.app/Info.plist" \
      CFBundleIdentifier CommonKey
  create_dump_plist --suffix framework "//app:app" \
      "Payload/app.app/Frameworks/framework.framework/Info.plist" \
      CFBundleIdentifier CommonKey
  create_dump_plist --suffix depframework "//app:app" \
      "Payload/app.app/Frameworks/depframework.framework/Info.plist" \
      CFBundleIdentifier CommonKey

  do_build ios //app:app || fail "Should build"

  assert_zip_not_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Images/foo.png"
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

  do_build ios //app:dump_plist_app || fail "Should build"

  # They all have Info.plists with the right bundle ids (even though the
  # frameworks share a comment infoplists entry for it).
  # They also all share a common file to add a custom key, ensure that
  # isn't duped away because of the overlap.
  assert_equals "my.bundle.id" \
      "$(cat "test-bin/app/CFBundleIdentifier_app")"
  assert_equals "CommonValue" \
      "$(cat "test-bin/app/CommonKey_app")"

  do_build ios //app:dump_plist_framework || fail "Should build"

  assert_equals "my.framework.id" \
      "$(cat "test-bin/app/CFBundleIdentifier_framework")"
  assert_equals "CommonValue" \
      "$(cat "test-bin/app/CommonKey_framework")"

  do_build ios //app:dump_plist_depframework || fail "Should build"

  assert_equals "my.depframework.id" \
      "$(cat "test-bin/app/CFBundleIdentifier_depframework")"
  assert_equals "CommonValue" \
      "$(cat "test-bin/app/CommonKey_depframework")"
}

# Verifies that, when an extension depends on a framework with different
# minimum_os, symbol subtraction still occurs.
function test_differing_minimum_os() {
  create_minimal_ios_framework_with_params True "8.0" "[]"

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

run_suite "ios_framework bundling tests"
