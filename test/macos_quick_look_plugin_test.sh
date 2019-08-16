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

# Integration tests for bundling simple macOS loadable bundles.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for macOS loadable bundles.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:macos.bzl", "macos_quick_look_plugin")

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
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF
}

# Creates a minimal macOS Quick Look plugin target.
function create_minimal_macos_quick_look_plugin() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
macos_quick_look_plugin(
    name = "app",
    bundle_id = "my.bundle.id.qlgenerator",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.11",
    deps = [":lib"],
)
EOF
}

# Test missing the CFBundleVersion fails the build.
function test_missing_version_fails() {
  create_common_files
  create_minimal_macos_quick_look_plugin

  # Replace the file, but without CFBundleVersion.
  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "BNDL";
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
  create_minimal_macos_quick_look_plugin

  # Replace the file, but without CFBundleShortVersionString.
  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "BNDL";
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
macos_quick_look_plugin(
    name = "app",
    bundle_id = "my.bundle.id.qlgenerator",
    infoplists = ["Info.plist"],
    ipa_post_processor = "post_processor.sh",
    minimum_os_version = "10.10",
    deps = [":lib"],
)
EOF

  cat > app/post_processor.sh <<EOF
#!/bin/bash
WORKDIR="\$1"
mkdir "\$WORKDIR/app.qlgenerator/Contents/Resources"
echo "foo" > "\$WORKDIR/app.qlgenerator/Contents/Resources/inserted_by_post_processor.txt"
EOF
  chmod +x app/post_processor.sh

  do_build macos //app:app || fail "Should build"
  assert_equals "foo" "$(unzip_single_file "test-bin/app/app.zip" \
      "app.qlgenerator/Contents/Resources/inserted_by_post_processor.txt")"
}

# Tests that linkopts get passed to the underlying binary target.
function test_linkopts_passed_to_binary() {
  create_common_files

  cat >> app/BUILD <<EOF
macos_quick_look_plugin(
    name = "app",
    bundle_id = "my.bundle.id.qlgenerator",
    infoplists = ["Info.plist"],
    linkopts = ["-alias", "_main", "_linkopts_test_main"],
    minimum_os_version = "10.10",
    deps = [":lib"],
)
EOF

  do_build macos //app:app || fail "Should build"

  unzip_single_file "test-bin/app/app.zip" "app.qlgenerator/Contents/MacOS/app" |
      nm -j - | grep _linkopts_test_main > /dev/null \
      || fail "Could not find -alias symbol in binary; " \
              "linkopts may have not propagated"
}

# Tests that no rpaths were added at link-time to the binary.
function disabled_test_binary_has_no_rpaths() {  # Blocked on b/127807024
  create_common_files
  create_minimal_macos_quick_look_plugin
  do_build macos //app:app || fail "Should build"

  unzip_single_file "test-bin/app/app.zip" "app.qlgenerator/Contents/MacOS/app" \
      > "$TEST_TMPDIR/app_bin"
  otool -l "$TEST_TMPDIR/app_bin" > "$TEST_TMPDIR/otool_output"
  assert_not_contains "cmd LC_RPATH" "$TEST_TMPDIR/otool_output"
}

run_suite "macos_quick_look_plugin bundling tests"
