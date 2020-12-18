# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""watchos_static_framework Starlark tests."""

load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)

def watchos_static_framework_test_suite(name = "watchos_static_framework"):
    """Test suite for watchos_static_framework.

    Args:
        name: The name prefix for all the nested tests
    """

    archive_contents_test(
        name = "{}_contents_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:static_fmwk",
        contains = [
            "$BUNDLE_ROOT/Headers/static_fmwk.h",
            "$BUNDLE_ROOT/Headers/shared.h",
            "$BUNDLE_ROOT/Modules/module.modulemap",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
