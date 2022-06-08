#!/bin/bash

# Copyright 2019 The Bazel Authors. All rights reserved.
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

# Integration tests for bundling iOS apps with extensions.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

readonly IOS_VERSION="11.0"

# Creates common source, targets, and basic plist for iOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "$IOS_VERSION",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":main"],
)
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

}

function test_objc_library_depends_on_dynamic_import() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "main",
    srcs = ["main.m"],
    deps = ["@build_bazel_rules_apple//test/testdata/fmwk:iOSImportedDynamicFramework"],
)
EOF

cat > app/main.m <<EOF
#import <iOSDynamicFramework/iOSDynamicFramework.h>

int main() {
  SharedClass *sharedClass = [[SharedClass alloc] init];
  [sharedClass doSomethingShared];
  return 0;
}
EOF

  do_build ios //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework"
}

function create_swift_static_framework() {
  if [[ -f fmwk/BUILD ]]; then
    return
  fi

  mkdir libraries
  mkdir fmwk

  cat >> libraries/BUILD <<EOF
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "iOSSwiftStaticFrameworkLibrary",
    generates_header = True,
    module_name = "iOSSwiftStaticFramework",
    srcs = ["@build_bazel_rules_apple//test/testdata/fmwk:swift_source"],
)
EOF

  do_build ios \
    --compilation_mode=dbg \
    --ios_minimum_os="$IOS_VERSION" \
    --cpu=ios_x86_64 \
    --apple_platform_type=ios \
    //libraries:iOSSwiftStaticFrameworkLibrary

  local framework=fmwk/iOSSwiftStaticFramework.framework
  mkdir -p "$framework"
  cp test-bin/libraries/libiOSSwiftStaticFrameworkLibrary.a \
     "$framework/iOSSwiftStaticFramework"
  mkdir -p "$framework/Modules/iOSSwiftStaticFramework.swiftmodule"
  cp test-bin/libraries/iOSSwiftStaticFramework.swiftmodule \
     "$framework/Modules/iOSSwiftStaticFramework.swiftmodule/x86_64.swiftmodule"
  mkdir -p "$framework/Headers"
  cp test-bin/libraries/iOSSwiftStaticFrameworkLibrary-Swift.h \
     "$framework/Headers/iOSSwiftStaticFramework.h"

  cat >> fmwk/BUILD <<EOF
load("@build_bazel_rules_apple//apple:apple.bzl", "apple_static_framework_import")
apple_static_framework_import(
    name = "iOSSwiftStaticFramework",
    framework_imports = glob(["iOSSwiftStaticFramework.framework/**"]),
    visibility = ["//visibility:public"],
)
EOF
}

function create_swift_static_framework_with_ios_static_framework() {
  if [[ -f framework_setup/BUILD ]]; then
    return
  fi

  mkdir framework_setup bazel_frameworks

  cat >> framework_setup/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_static_framework")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "framework_lib",
    module_name = "bazel_framework",
    srcs = ["@build_bazel_rules_apple//test/testdata/fmwk:swift_source"],
)

ios_static_framework(
    name = "bazel_framework",
    minimum_os_version = "$IOS_VERSION",
    deps = [":framework_lib"],
)
EOF

  do_build ios \
    --ios_minimum_os="$IOS_VERSION" \
    --apple_platform_type=ios \
    //framework_setup:bazel_framework

  unzip test-bin/framework_setup/bazel_framework.zip -d bazel_frameworks

  cat >> bazel_frameworks/BUILD <<EOF
load("@build_bazel_rules_apple//apple:apple.bzl", "apple_static_framework_import")
apple_static_framework_import(
    name = "bazel_framework",
    framework_imports = glob(["bazel_framework.framework/**"]),
    visibility = ["//visibility:public"],
)
EOF
}

function test_objc_library_depends_on_static_import() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "main",
    srcs = ["main.m"],
    deps = ["@build_bazel_rules_apple//test/testdata/fmwk:iOSImportedStaticFramework"],
)
EOF

cat > app/main.m <<EOF
#import <iOSStaticFramework/iOSStaticFramework.h>

int main() {
  SharedClass *sharedClass = [[SharedClass alloc] init];
  [sharedClass doSomethingShared];
  return 0;
}
EOF

  do_build ios //app:app || fail "Should build"
}

function test_objc_library_depends_on_swift_static_import() {
    create_common_files

    create_swift_static_framework

    cat >> app/BUILD <<EOF
objc_library(
    name = "main",
    srcs = ["main.m"],
    deps = ["//fmwk:iOSSwiftStaticFramework"],
)
EOF

    cat > app/main.m <<EOF
#import <iOSSwiftStaticFramework/iOSSwiftStaticFramework.h>

int main() {
  SharedClass *sharedClass = [[SharedClass alloc] init];
  [sharedClass doSomethingShared];
  return 0;
}
EOF

    do_build ios //app:app || fail "Should build"
}

function test_swift_library_depends_on_dynamic_import() {
  create_common_files

  cat >> app/BUILD <<EOF
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "main",
    srcs = ["main.swift"],
    deps = ["@build_bazel_rules_apple//test/testdata/fmwk:iOSImportedDynamicFramework"],
)
EOF

cat > app/main.swift <<EOF
import iOSDynamicFramework

let sharedClass = SharedClass()
sharedClass.doSomethingShared()
EOF

  do_build ios //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework"
}

function test_swift_library_depends_on_static_import() {
  create_common_files

  cat >> app/BUILD <<EOF
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "main",
    srcs = ["main.swift"],
    deps = ["@build_bazel_rules_apple//test/testdata/fmwk:iOSImportedStaticFramework"],
)
EOF

cat > app/main.swift <<EOF
import iOSStaticFramework

let sharedClass = SharedClass()
sharedClass.doSomethingShared()
EOF

  do_build ios //app:app || fail "Should build"
}

function test_swift_library_depends_on_swift_static_import() {
    create_common_files

    create_swift_static_framework

    cat >> app/BUILD <<EOF
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "main",
    srcs = ["main.swift"],
    deps = ["//fmwk:iOSSwiftStaticFramework"],
)
EOF

    cat > app/main.swift <<EOF
import iOSSwiftStaticFramework

let sharedClass = SharedClass()
sharedClass.doSomethingShared()
EOF

    do_build ios --compilation_mode=dbg //app:app || fail "Should build"

    local symbols
    symbols=$(
        unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/app" \
            | nm -aj - | grep .swiftmodule
    )

    local swiftmodules=(
        app_main.swiftmodule
        iOSSwiftStaticFramework.swiftmodule/x86_64.swiftmodule
    )

    local swiftmodule
    for swiftmodule in "${swiftmodules[@]}"; do
        if [[ "$symbols" != *"$swiftmodule"* ]]; then
            fail "Could not find $swiftmodule AST reference in binary; " \
                 "linkopts may have not propagated"
        fi
    done
}

function test_swift_library_depends_on_swift_static_import_from_framework() {
    create_common_files

    create_swift_static_framework_with_ios_static_framework

    cat >> app/BUILD <<EOF
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "main",
    srcs = ["main.swift"],
    deps = ["//bazel_frameworks:bazel_framework"],
)
EOF

    cat > app/main.swift <<EOF
import bazel_framework

let sharedClass = SharedClass()
sharedClass.doSomethingShared()
EOF

    do_build ios --compilation_mode=dbg //app:app || fail "Should build"

    local symbols
    symbols=$(
        unzip_single_file "test-bin/app/app.ipa" "Payload/app.app/app" \
            | nm -aj - | grep .swiftmodule
    )

    for symbol in "${symbols[@]}"; do
      if [[ "$symbol" != *app_main.swiftmodule ]]; then
        fail "Unexpected symbol in binary: $symbol"
      fi
    done
}

run_suite "framework_import tests"
