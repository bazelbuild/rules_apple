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

"""tvos_static_framework Starlark tests."""

load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)

def tvos_static_framework_test_suite(name):
    """Test suite for tvos_static_framework.

    Args:
      name: the base name to be used in things created by this macro
    """
    archive_contents_test(
        name = "{}_contents_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:static_fmwk",
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
