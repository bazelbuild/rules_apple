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

"""watchos_dynamic_framework Starlark tests."""

load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def watchos_dynamic_framework_test_suite(name = "watchos_dynamic_framework"):
    """Test suite for watchos_dynamic_framework.

    Args:
        name: The name prefix for all the nested tests
    """

    archive_contents_test(
        name = "{}_archive_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:basic_framework",
        contains = [
            "$BUNDLE_ROOT/BasicFramework",
            "$BUNDLE_ROOT/Headers/BasicFramework.h",
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/Modules/module.modulemap",
            "$BUNDLE_ROOT/Modules/BasicFramework.swiftmodule/i386.swiftdoc",
            "$BUNDLE_ROOT/Modules/BasicFramework.swiftmodule/i386.swiftmodule"
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:basic_framework",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "BasicFramework",
            "CFBundleIdentifier": "com.google.example.framework",
            "CFBundleName": "BasicFramework",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator*",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "6.0",
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_direct_dependency_archive_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:basic_framework_with_direct_dependency",
        contains = [
            "$BUNDLE_ROOT/DirectDependencyTest",
            "$BUNDLE_ROOT/Headers/DirectDependencyTest.h",
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/Modules/module.modulemap",
            "$BUNDLE_ROOT/Modules/DirectDependencyTest.swiftmodule/i386.swiftdoc",
            "$BUNDLE_ROOT/Modules/DirectDependencyTest.swiftmodule/i386.swiftmodule"
        ],
        tags = [name],
    )


    archive_contents_test(
        name = "{}_transitive_dependency_archive_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:basic_framework_with_transitive_dependency",
        contains = [
            "$BUNDLE_ROOT/TransitiveDependencyTest",
            "$BUNDLE_ROOT/Headers/TransitiveDependencyTest.h",
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/Modules/module.modulemap",
            "$BUNDLE_ROOT/Modules/TransitiveDependencyTest.swiftmodule/i386.swiftdoc",
            "$BUNDLE_ROOT/Modules/TransitiveDependencyTest.swiftmodule/i386.swiftmodule"
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
