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

# Integration tests for the Apple bundle versioning rule.

function set_up() {
  rm -rf pkg
  mkdir -p pkg

  cat > pkg/saver.bzl <<EOF
load("@build_bazel_rules_apple//apple:versioning.bzl",
     "AppleBundleVersionInfo")

def _saver_impl(ctx):
  infile = ctx.attr.bundle_version[AppleBundleVersionInfo].version_file
  outfile = ctx.outputs.version_file
  ctx.action(
      inputs=[infile],
      outputs=[outfile],
      command="cp %s %s" % (infile.path, outfile.path),
  )

saver = rule(
    _saver_impl,
    attrs={
        "bundle_version": attr.label(
            providers=[[AppleBundleVersionInfo]],
        ),
    },
    outputs = {
        "version_file": "%{name}.txt",
    },
)
EOF

  cat > pkg/BUILD <<EOF
load("@build_bazel_rules_apple//apple:versioning.bzl",
     "apple_bundle_version")
load(":saver.bzl", "saver")

saver(
    name = "saved_version",
    bundle_version = ":bundle_version",
)
EOF
}

# Tests that manual version numbers work correctly.
function test_manual_version_numbers() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_version = "1.2.3",
    short_version_string = "1.2",
)
EOF

  do_build ios //pkg:saved_version || \
      fail "Should build"
  assert_contains "\"build_version\": \"1.2.3\"" test-bin/pkg/saved_version.txt
  assert_contains "\"short_version_string\": \"1.2\"" \
      test-bin/pkg/saved_version.txt
}

# Tests that short_version_string defaults to the same value as build_version
# if not specified.
function test_short_version_string_defaults_to_build_version() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_version = "1.2.3",
)
EOF

  do_build ios //pkg:saved_version || fail "Should build"
  assert_contains "\"build_version\": \"1.2.3\"" test-bin/pkg/saved_version.txt
  assert_contains "\"short_version_string\": \"1.2.3\"" \
      test-bin/pkg/saved_version.txt
}

# Test that the build label passed via --embed_label can be parsed out
# correctly.
function test_build_label_substitution() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    short_version_string = "{version}",
    capture_groups = {
        "version": "\\d+\.\\d+",
        "candidate": "\\d+",
    },
)
EOF

  do_build ios //pkg:saved_version --embed_label=MyApp_1.2_RC03 || \
      fail "Should build"
  assert_contains "\"build_version\": \"1.2.3\"" test-bin/pkg/saved_version.txt
  assert_contains "\"short_version_string\": \"1.2\"" \
      test-bin/pkg/saved_version.txt
}

# Tests that short_version_string defaults to the same value as build_version
# if not specified.
function test_short_version_string_defaults_to_build_version_with_label_substitution() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    capture_groups = {
        "version": "\\d+\.\\d+",
        "candidate": "\\d+",
    },
)
EOF

  do_build ios //pkg:saved_version --embed_label=MyApp_1.2_RC03 || \
      fail "Should build"
  assert_contains "\"build_version\": \"1.2.3\"" test-bin/pkg/saved_version.txt
  assert_contains "\"short_version_string\": \"1.2.3\"" \
      test-bin/pkg/saved_version.txt
}

# Tests that a build_label_pattern that contains placeholders not found in
# capture_groups fails.
function test_pattern_referencing_missing_capture_groups_fails() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_label_pattern = "MyApp_{version}_RC00",
    build_version = "{version}.{candidate}",
    capture_groups = {
        "version": "\\d+",
    },
)
EOF

  ! do_build ios //pkg:saved_version --embed_label=MyApp_1.2_RC03 || \
      fail "Should fail"
  expect_log "Some groups were not defined in capture_groups: \[candidate\]"
}

# Tests that the build fails if build_label_pattern is provided but
# capture_groups is not.
function test_build_label_pattern_requires_capture_groups() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
)
EOF

  ! do_build ios //pkg:saved_version --embed_label=MyApp_1.2_RC03 || \
      fail "Should fail"
  expect_log "If either build_label_pattern or capture_groups is provided, " \
      "then both must be provided"
}

# Tests that the build fails if capture_groups is provided but
# build_label_pattern is not.
function test_capture_groups_requires_build_label_pattern() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_version = "{version}.{candidate}",
    capture_groups = {
        "foo": "bar",
    },
)
EOF

  ! do_build ios //pkg:saved_version --embed_label=MyApp_1.2_RC03 || \
      fail "Should fail"
  expect_log "If either build_label_pattern or capture_groups is provided, " \
      "then both must be provided"
}

# Test that the build fails if the build label does not match the regular
# expression that is built after substituting the regex groups for the
# placeholders.
function test_build_label_that_does_not_match_regex_fails() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    short_version_string = "{version}",
    capture_groups = {
        "version": "\\d+\.\\d+\.\\d+",
        "candidate": "\\d+",
    },
)
EOF

  ! do_build ios //pkg:saved_version --embed_label=MyApp_1.2_RC03 || \
      fail "Should fail"
  expect_log "The build label (\"MyApp_1.2_RC03\") did not match the pattern"
}

# Test that substitution does not occur if there is a build label pattern but
# --embed_label is not specified on the command line. (This supports local
# builds).
function test_no_substitution_if_build_label_not_present() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    short_version_string = "{version}",
    capture_groups = {
        "version": "\\d+\.\\d+",
        "candidate": "\\d+",
    },
)
EOF

  do_build ios //pkg:saved_version || fail "Should build"
  assert_contains "{}" test-bin/pkg/saved_version.txt
}

# Test that the presence of a build label pattern does not short circuit the
# use of a literal version string, even if no --embed_label argument is
# provided.
function test_build_label_pattern_does_not_short_circuit_literal_version() {
  cat >> pkg/BUILD <<EOF
apple_bundle_version(
    name = "bundle_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "1.2.3",
    short_version_string = "1.2",
    capture_groups = {
        "version": "\\d+\.\\d+",
        "candidate": "\\d+",
    },
)
EOF

  do_build ios //pkg:saved_version || fail "Should build"
  assert_contains "\"build_version\": \"1.2.3\"" test-bin/pkg/saved_version.txt
  assert_contains "\"short_version_string\": \"1.2\"" \
      test-bin/pkg/saved_version.txt
}

run_suite "apple_bundle_version tests"
