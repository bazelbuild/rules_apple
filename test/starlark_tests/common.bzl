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
    "nobuilder",
    "notap",
]

# The current min_deployment_target for iOS is version 15.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/, and it is what Apple builds backport
# compatibility libraries with. Anything earlier than 15.0 is likely not going to work with the
#current toolchain.
_min_os_ios = struct(
    app_intents_support = "16.0",
    app_intents_package_support = "17.0",
    min_deployment_target = "15.0",
    cpp_typed_allocator_simulator_support = "18.0",
    icon_bundle_required = "26.0",
    nplus1 = "16.0",
    span_in_os = "26.0",
    test_mismatch_high_threshold = "17.0",
    ui_image_variable_value_support = "16.0",
    widget_configuration_intents_support = "16.0",
)

# The current min_deployment_target for macOS is version 12.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/
_min_os_macos = struct(
    app_intents_support = "13.0",
    app_intents_package_support = "14.0",
    min_deployment_target = "12.0",
    nplus1 = "13.0",
    icon_bundle_required = "26.0",
)

# The current min_deployment_target for tvOS is version 15.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/
_min_os_tvos = struct(
    app_intents_support = "16.0",
    app_intents_package_support = "17.0",
    min_deployment_target = "15.0",
    nplus1 = "16.0",
)

_min_os_visionos = struct(
    min_deployment_target = "1.0",
)

# The current min_deployment_target for watchOS is version 9.0, based on Xcode 27 on Apple's Xcode
# Support page: https://developer.apple.com/support/xcode/
_min_os_watchos = struct(
    app_intents_support = "9.0",
    app_intents_package_support = "10.0",
    min_deployment_target = "9.0",
    nplus1 = "10.0",
    icon_bundle_required = "26.0",
    arm64_support = "26.0",
)

common = struct(
    fixture_tags = _fixture_tags,
    min_os_ios = _min_os_ios,
    min_os_macos = _min_os_macos,
    min_os_tvos = _min_os_tvos,
    min_os_visionos = _min_os_visionos,
    min_os_watchos = _min_os_watchos,
)
