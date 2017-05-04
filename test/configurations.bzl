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

"""Configuration options for the Apple rule integration tests."""


# Configuration options used with `apple_shell_test` to run tests for
# iOS simulator and device builds.
#
# TODO(b/35091927): Here and below, switch to Bitcode mode "embedded".
IOS_DEVICE_OPTIONS = ["--ios_multi_cpus=arm64,armv7", "-c opt"]

IOS_CONFIGURATIONS = {
    "simulator": ["--ios_multi_cpus=i386,x86_64"],
    "device": IOS_DEVICE_OPTIONS,
    "device_bitcode": IOS_DEVICE_OPTIONS + [
        "--apple_bitcode=embedded_markers",
    ],
}

IOS_TEST_CONFIGURATIONS = {
    "simulator": ["--ios_multi_cpus=i386,x86_64"],
    "device": IOS_DEVICE_OPTIONS,
}

# Configuration options used with `apple_shell_test` to run tests for
# tvOS simulator and device builds.
TVOS_DEVICE_OPTIONS = ["--tvos_cpus=arm64", "-c opt"]

TVOS_CONFIGURATIONS = {
    "simulator": ["--tvos_cpus=x86_64"],
    "device": TVOS_DEVICE_OPTIONS,
    "device_bitcode": TVOS_DEVICE_OPTIONS + [
        "--apple_bitcode=embedded_markers",
    ],
}

# Configuration options used with `apple_shell_test` to run tests for
# watchOS simulator and device builds. Since watchOS apps are always bundled
# with an iOS host app, we include that platform's configuration options as
# well.
WATCHOS_DEVICE_OPTIONS = [
    "--ios_multi_cpus=arm64,armv7", "--watchos_cpus=armv7k", "-c opt",
]

WATCHOS_CONFIGURATIONS = {
    "simulator": ["--ios_multi_cpus=i386,x86_64", "--watchos_cpus=i386"],
    "device": WATCHOS_DEVICE_OPTIONS,
    "device_bitcode": WATCHOS_DEVICE_OPTIONS + [
        "--apple_bitcode=embedded_markers",
    ],
}
