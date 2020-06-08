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

# Integration tests for bundling simple macOS applications.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for macOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:macos.bzl",
     "macos_application",
     "macos_bundle")
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_dynamic_framework_import")

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

# Creates a minimal macOS application target.
function create_minimal_macos_application() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.11",
    deps = [":lib"],
)
EOF
}

# Test missing the CFBundleVersion fails the build.
function test_missing_version_fails() {
  create_common_files
  create_minimal_macos_application

  # Replace the file, but without CFBundleVersion.
  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
}
EOF

  ! do_build macos //app:app \
    || fail "Should fail build"

  expect_log 'Target "//app:app" is missing CFBundleVersion.'
}

# Test missing the CFBundleShortVersionString fails the build.
function test_missing_short_version_fails() {
  create_common_files
  create_minimal_macos_application

  # Replace the file, but without CFBundleShortVersionString.
  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleVersion = "1.0";
}
EOF

  ! do_build macos //app:app \
    || fail "Should fail build"

  expect_log 'Target "//app:app" is missing CFBundleShortVersionString.'
}

# Tests that the IPA post-processor is executed and can modify the bundle.
function test_ipa_post_processor() {
  create_common_files

  cat >> app/BUILD <<EOF
macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    ipa_post_processor = "post_processor.sh",
    minimum_os_version = "10.10",
    deps = [":lib"],
)
EOF

  cat > app/post_processor.sh <<EOF
#!/bin/bash
WORKDIR="\$1"
mkdir "\$WORKDIR/app.app/Contents/Resources"
echo "foo" > "\$WORKDIR/app.app/Contents/Resources/inserted_by_post_processor.txt"
EOF
  chmod +x app/post_processor.sh

  do_build macos //app:app || fail "Should build"
  assert_equals "foo" "$(unzip_single_file "test-bin/app/app.zip" \
      "app.app/Contents/Resources/inserted_by_post_processor.txt")"
}

# Tests that the PkgInfo file exists in the bundle and has the expected
# content.
function test_pkginfo_contents() {
  create_common_files
  create_minimal_macos_application
  do_build macos //app:app || fail "Should build"

  assert_equals "APPL????" "$(unzip_single_file "test-bin/app/app.zip" \
      "app.app/Contents/PkgInfo")"
}

run_suite "macos_application bundling tests"
