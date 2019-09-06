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

# Creates common source, targets, and basic plist for iOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_application",
    )
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_dynamic_framework_import",
     "apple_static_framework_import",
    )

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info-App.plist"],
    minimum_os_version = "11.0",
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
    deps = ["@build_bazel_rules_apple//test/testdata/frameworks:iOSDynamicFramework"],
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

function test_objc_library_depends_on_static_import() {
  create_common_files

  cat >> app/BUILD <<EOF
objc_library(
    name = "main",
    srcs = ["main.m"],
    deps = ["@build_bazel_rules_apple//test/testdata/frameworks:iOSStaticFramework"],
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

    cat >> app/BUILD <<EOF
objc_library(
    name = "main",
    srcs = ["main.m"],
    deps = ["@build_bazel_rules_apple//test/testdata/frameworks:iOSSwiftStaticFramework"],
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
    deps = ["@build_bazel_rules_apple//test/testdata/frameworks:iOSDynamicFramework"],
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
    deps = ["@build_bazel_rules_apple//test/testdata/frameworks:iOSStaticFramework"],
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

    cat >> app/BUILD <<EOF
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "main",
    srcs = ["main.swift"],
    deps = ["@build_bazel_rules_apple//test/testdata/frameworks:iOSSwiftStaticFramework"],
)
EOF

    cat > app/main.swift <<EOF
import iOSSwiftStaticFramework

let sharedClass = SharedClass()
sharedClass.doSomethingShared()
EOF

    do_build ios //app:app || fail "Should build"
}

run_suite "framework_import tests"
