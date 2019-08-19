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

"""Proxy for exporting test symbols."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    _AppleTestInfo = "AppleTestInfo",
    _AppleTestRunnerInfo = "AppleTestRunnerInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_rule_support.bzl",
    _CoverageFilesInfo = "CoverageFilesInfo",
    _coverage_files_aspect = "coverage_files_aspect",
)

# Re-export these symbols to avoid breaking current users of these.
# TODO(kaipi): Find a better location for test providers to export them as public interface from
# rules_apple.
AppleTestInfo = _AppleTestInfo
AppleTestRunnerInfo = _AppleTestRunnerInfo
CoverageFilesInfo = _CoverageFilesInfo
coverage_files_aspect = _coverage_files_aspect
