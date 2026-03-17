# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""macos_build_test Starlark tests."""

load(
    "//apple:macos.bzl",
    "macos_build_test",
)
load(
    ":common.bzl",
    "common",
)

def macos_build_test_test_suite(name):
    """Test suite for macos_build_test.

    Args:
      name: the base name to be used in things created by this macro
    """

    macos_build_test(
        name = "{}_builds_simple_library".format(name),
        minimum_os_version = common.min_os_macos.baseline,
        targets = [
            "//test/starlark_tests/resources:objc_lib_with_sdk_dylibs",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
