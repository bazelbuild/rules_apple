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

"""Common build definitions used by test fixtures."""

visibility("//test/starlark_tests/...")

# Common tags that prevent the test fixtures from actually being built (i.e.,
# their actions executed) when running `bazel test` to do analysis testing.
_fixture_tags = [
    "manual",
    "notap",
]

# The current baseline for iOS is version 13.0, based on Xcode 15.3's minimum version for XCTest.
_min_os_ios = struct(
    app_intents_support = "16.0",
    appclip_support = "14.0",
    arm_sim_support = "14.0",
    baseline = "13.0",
    oldest_supported = "12.0",
    nplus1 = "14.0",
    stable_swift_abi = "12.2",
    widget_configuration_intents_support = "16.0",
)

_min_os_macos = struct(
    app_intents_support = "13.0",
    arm64_support = "11.0",
    baseline = "10.13",
)

# The current baseline for tvOS is version 13.0, based on Xcode 15.3's minimum version for XCTest.
_min_os_tvos = struct(
    app_intents_support = "16.0",
    arm_sim_support = "14.0",
    baseline = "13.0",
    oldest_supported = "12.0",
    nplus1 = "14.0",
    stable_swift_abi = "12.2",
)

_min_os_visionos = struct(
    baseline = "1.0",
    oldest_supported = "1.0",
)

_min_os_watchos = struct(
    app_intents_support = "9.0",
    arm64_support = "9.0",
    arm_sim_support = "7.0",
    baseline = "4.0",
    requires_single_target_app = "9.0",
    single_target_app = "7.0",
    stable_swift_abi = "6.0",
    test_runner_support = "7.4",
)

common = struct(
    fixture_tags = _fixture_tags,
    min_os_ios = _min_os_ios,
    min_os_macos = _min_os_macos,
    min_os_tvos = _min_os_tvos,
    min_os_visionos = _min_os_visionos,
    min_os_watchos = _min_os_watchos,
)
