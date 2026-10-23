# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Custom test runners with XML generation post-action."""

load(
    "//apple/testing/default_runner:ios_xctestrun_runner.bzl",
    "ios_xctestrun_runner",
)
load(
    "//apple/testing/default_runner:ios_test_runner.bzl",
    "ios_test_runner",
)
load(
    "//apple/testing/default_runner:macos_test_runner.bzl",
    "macos_test_runner",
)

# iOS XCTestRun Runner with XML generation
ios_xctestrun_runner(
    name = "ios_xctestrun_runner_enhanced_junit_xml",
    post_action = "//tools/test_xml_generator:generate_test_xml",
    post_action_determines_exit_code = False,
    visibility = ["//visibility:public"],
)

# iOS Test Runner with XML generation
ios_test_runner(
    name = "ios_test_runner_enhanced_junit_xml",
    post_action = "//tools/test_xml_generator:generate_test_xml",
    post_action_determines_exit_code = False,
    visibility = ["//visibility:public"],
)

# macOS Test Runner with XML generation
macos_test_runner(
    name = "macos_test_runner_enhanced_junit_xml",
    post_action = "//tools/test_xml_generator:generate_test_xml",
    post_action_determines_exit_code = False,
    visibility = ["//visibility:public"],
)

