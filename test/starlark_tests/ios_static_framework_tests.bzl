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

"""ios_static_framework Starlark tests."""

load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)

def ios_static_framework_test_suite(name = "ios_static_framework"):
    """Test suite for ios_static_framework.

    Args:
        name: The name prefix for all the nested tests
    """

    # Test that it's permitted for a static framework to have multiple
    # `swift_library` dependencies if only one module remains after excluding
    # the transitive closure of `avoid_deps`. Likewise, make sure that the
    # symbols from the avoided deps aren't linked in. (In a situation like
    # this, the user must provide those dependencies separately if they are
    # needed.)
    archive_contents_test(
        name = "{}_swift_avoid_deps_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:static_fmwk_with_swift_and_avoid_deps",
        contains = [
            "$BUNDLE_ROOT/Modules/StaticFmwkUpperLib.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/Modules/StaticFmwkUpperLib.swiftmodule/x86_64.swiftinterface",
        ],
        binary_test_file = "$BUNDLE_ROOT/StaticFmwkUpperLib",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_$s18StaticFmwkUpperLib5DummyVMf"],
        binary_not_contains_symbols = [
            "_$s18StaticFmwkLowerLib5DummyVMf",
            "_$s19StaticFmwkLowestLib5DummyVMf",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
