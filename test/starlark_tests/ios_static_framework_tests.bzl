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

def ios_static_framework_test_suite(name):
    """Test suite for ios_static_framework.

    Args:
      name: the base name to be used in things created by this macro
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
            "$BUNDLE_ROOT/Modules/SwiftFmwkUpperLib.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/Modules/SwiftFmwkUpperLib.swiftmodule/x86_64.swiftinterface",
        ],
        binary_test_file = "$BUNDLE_ROOT/SwiftFmwkUpperLib",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_$s17SwiftFmwkUpperLib5DummyVMn"],
        binary_not_contains_symbols = [
            "_$s17SwiftFmwkLowerLib5DummyVMn",
            "_$s18SwiftFmwkLowestLib5DummyVMn",
        ],
        tags = [name],
    )

    # Test that no module map is generated if the target does not have headers
    # and does not depend on any system dylibs/frameworks.
    archive_contents_test(
        name = "{}_no_module_map_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_static_framework_without_modulemap",
        not_contains = ["$BUNDLE_ROOT/Modules/module.modulemap"],
        tags = [name],
    )

    # Test that a module map is generated if the target depends on system
    # dylibs.
    archive_contents_test(
        name = "{}_module_map_with_sdk_dylibs_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_static_framework_with_sdk_dylibs_dep",
        contains = ["$BUNDLE_ROOT/Modules/module.modulemap"],
        tags = [name],
        text_test_file = "$BUNDLE_ROOT/Modules/module.modulemap",
        text_test_values = [" link \"z\""],
    )

    # Test that a module map is generated if the target depends on system
    # frameworks.
    archive_contents_test(
        name = "{}_module_map_with_sdk_fmwks_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_static_framework_with_sdk_fmwks_dep",
        contains = ["$BUNDLE_ROOT/Modules/module.modulemap"],
        tags = [name],
        text_test_file = "$BUNDLE_ROOT/Modules/module.modulemap",
        text_test_values = [" link framework \"CoreData\""],
    )

    # Test that a module map is generated if the target's `hdrs` is not empty.
    archive_contents_test(
        name = "{}_module_map_with_hdrs_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_static_framework",
        contains = ["$BUNDLE_ROOT/Modules/module.modulemap"],
        tags = [name],
        text_test_file = "$BUNDLE_ROOT/Modules/module.modulemap",
        text_test_values = [" umbrella header \"objc_static_framework.h\""],
    )

    # Test that the Swift generated header is propagated to the Headers visible
    # within this iOS framework along with the swift interfaces and modulemap.
    archive_contents_test(
        name = "{}_swift_generates_header_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:static_framework_with_generated_header",
        contains = [
            "$BUNDLE_ROOT/Headers/SwiftFmwkWithGenHeader.h",
            "$BUNDLE_ROOT/Modules/module.modulemap",
            "$BUNDLE_ROOT/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftinterface",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
