# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""watchos_application Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
    "binary_contents_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

def watchos_single_target_application_test_suite(name):
    """Test suite for watchos_single_target_application.

    Args:
      name: the base name to be used in things created by this macro
    """
    analysis_failure_message_test(
        name = "{}_too_low_minimum_os_version_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app_too_low_minos",
        expected_error = "Single-target watchOS applications require a minimum_os_version of 7.0 or greater.",
        tags = [
            name,
        ],
    )

    analysis_failure_message_test(
        name = "{}_unexpected_watch2_extension_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app_with_watch2_ext",
        expected_error = """
Single-target watchOS applications do not support watchOS 2 extensions or their delegates.

Please remove the assigned watchOS 2 app `extension` and make sure a valid watchOS application
delegate is referenced in the single-target `watchos_application`'s `deps`.
""",
        tags = [
            name,
        ],
    )

    # Tests analysis phase failure when an extension depends on a framework which
    # is not marked extension_safe.
    analysis_failure_message_test(
        name = "{}_fails_with_extension_depending_on_not_extension_safe_framework".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_ext_with_fmwk_not_extension_safe",
        expected_error = (
            "The target {package}:ext_with_fmwk_not_extension_safe is for an extension but its " +
            "framework dependency {package}:fmwk_not_extension_safe is not marked extension-safe." +
            " Specify 'extension_safe = 1' on the framework target."
        ).format(
            package = "//test/starlark_tests/targets_under_test/watchos/frameworks",
        ),
        tags = [name],
    )

    # Test that if a watchos_framework target depends on a prebuilt framework (i.e.,
    # apple_dynamic_framework_import), that the inner framework is propagated up
    # to the application and not nested in the outer framework.
    archive_contents_test(
        name = "{}_contains_framework_depends_on_prebuilt_apple_framework_import".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_runtime_framework_using_import_framework_dep",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_imported_dynamic_framework.framework/fmwk_with_imported_dynamic_framework",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_imported_dynamic_framework.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_watchos_dynamic_fmwk.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_watchos_dynamic_fmwk.framework/Resources/generated_watchos_dynamic_fmwk.bundle/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_watchos_dynamic_fmwk.framework/generated_watchos_dynamic_fmwk",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/generated_watchos_dynamic_fmwk.framework/Frameworks/fmwk_with_imported_dynamic_framework.framework/",
        ],
        tags = [name],
    )

    # Tests that the bundled application contains the framework but that the
    # extension inside it does *not* contain another copy.
    archive_contents_test(
        name = "{}_contains_framework_and_framework_depending_extension_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_framework_and_framework_depending_ext",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/PlugIns/ext_with_framework.appex/Info.plist",
            "$BUNDLE_ROOT/PlugIns/ext_with_framework.appex/ext_with_framework",
        ],
        not_contains = [
            "$BUNDLE_ROOT/PlugIns/ext_with_framework.appex/Frameworks/",
        ],
        tags = [name],
    )

    # Tests that resources that both apps and frameworks depend on are present
    # in the .framework directory and that the symbols are only present in the
    # framework binary.
    archive_contents_test(
        name = "{}_with_resources_and_framework_resources_contains_files_only_on_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_transitive_structured_resources",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_transitive_structured_resources.framework/Images/foo.png",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_transitive_structured_resources.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_transitive_structured_resources.framework/fmwk_with_transitive_structured_resources",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Images/foo.png",
        ],
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_with_transitive_structured_resources.framework/fmwk_with_transitive_structured_resources",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "_dontCallMeShared",
            "_anotherFunctionShared",
            "_anticipatedDeadCode",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_with_resources_and_framework_resources_app_binary_not_contains_symbols".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_transitive_structured_resources",
        binary_test_file = "$BUNDLE_ROOT/app_with_fmwk_with_transitive_structured_resources",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = [
            "_dontCallMeShared",
            "_anotherFunctionShared",
            "_anticipatedDeadCode",
        ],
        tags = [name],
    )

    # Tests that a framework is present in the top level application
    # bundle in the case that only extensions depend on the framework
    # and the application itself does not.
    archive_contents_test(
        name = "{}_propagates_framework_from_watchos_extension_and_not_bundles_framework_on_extension".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_framework_depending_ext",
        contains = [
            # The main bundle should contain the framework...
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/PlugIns/ext_with_framework.appex/Info.plist",
            "$BUNDLE_ROOT/PlugIns/ext_with_framework.appex/ext_with_framework",
        ],
        not_contains = [
            # The extension bundle should be intact, but have no inner framework.
            "$BUNDLE_ROOT/PlugIns/ext_with_framework.appex/Frameworks/",
        ],
        tags = [name],
    )

    # Tests that resource bundles that are dependencies of a framework are
    # bundled with the framework if no deduplication is happening.
    archive_contents_test(
        name = "{}_contains_resource_bundles_in_framework_and_not_in_app".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_resource_bundles",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_resource_bundles.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_resource_bundles.framework/simple_bundle_library.bundle/generated.strings",
        ],
        not_contains = [
            "$BUNDLE_ROOT/simple_bundle_library.bundle",
            "$BUNDLE_ROOT/basic.bundle",
        ],
        tags = [name],
    )

    # Tests that an App->Framework->Framework dependency is handled properly. (That
    # a framework that is not directly depended on by the app is still pulled into
    # the app, and symbols end up in the correct binaries.)
    archive_contents_test(
        name = "{}_contains_shared_framework_resource_files_only_in_inner_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        contains = [
            # Contains expected framework files...
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/Info.plist",
            # Contains expected shared framework resource file...
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/Images/foo.png",
        ],
        not_contains = [
            # Doesn't contains shared framework resource file...
            "$BUNDLE_ROOT/Images/foo.png",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/Images/foo.png",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_depending_fmwk_with_fmwk_shared_lib_symbols_in_inner_framework_binary".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["-[ObjectiveCCommonClass doSomethingCommon]"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_depending_fmwk_with_fmwk_shared_lib_symbols_not_in_outer_framework_binary".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["-[ObjectiveCCommonClass doSomethingCommon]"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_depending_fmwk_with_fmwk_shared_lib_symbols_not_in_app_binary".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        binary_test_file = "$BUNDLE_ROOT/app_with_fmwk_with_fmwk",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["-[ObjectiveCCommonClass doSomethingCommon]"],
        tags = [name],
    )

    # They all have Info.plists with the right bundle ids (even though the
    # frameworks share a comment infoplists entry for it).
    # They also all share a common file to add a custom key, ensure that
    # isn't duped away because of the overlap.
    archive_contents_test(
        name = "{}_depending_fmwk_with_fmwk_app_plist_content".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIdentifier": "com.google.example",
            "AnotherKey": "AnotherValue",
        },
        tags = [name],
    )
    archive_contents_test(
        name = "{}_depending_fmwk_with_fmwk_outer_framework_plist_content".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        plist_test_file = "$BUNDLE_ROOT/Frameworks/fmwk.framework/Info.plist",
        plist_test_values = {
            "CFBundleIdentifier": "com.google.example.framework",
            "AnotherKey": "AnotherValue",
        },
        tags = [name],
    )
    archive_contents_test(
        name = "{}_depending_fmwk_with_fmwk_inner_framework_plist_content".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        plist_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/Info.plist",
        plist_test_values = {
            "CFBundleIdentifier": "com.google.example.frameworkception",
            "AnotherKey": "AnotherValue",
        },
        tags = [name],
    )

    # Verifies that, when an extension depends on a framework with different
    # minimum_os, symbol subtraction still occurs.
    archive_contents_test(
        name = "{}_with_ext_min_os_nplus1_extension_binary_not_contains_lib_symbols".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_ext_min_os_nplus1",
        binary_test_file = "$BUNDLE_ROOT/PlugIns/ext_min_os_nplus1.appex/ext_min_os_nplus1",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_with_ext_min_os_nplus1_framework_binary_contains_lib_symbols".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_ext_min_os_nplus1",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    # Tests that different root-level resources with the same name are not
    # deduped between framework and app.
    archive_contents_test(
        name = "{}_does_not_dedup_structured_resources_from_framework_and_app".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_structured_resources_and_fmwk_with_structured_resources",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_structured_resources.framework/Images/foo.png",
            "$BUNDLE_ROOT/Images/foo.png",
        ],
        tags = [name],
    )

    # Tests that root-level resources depended on by both an application and its
    # framework end up in both bundles given that both bundles have explicit owners
    # on the resources
    archive_contents_test(
        name = "{}_contains_root_level_resource_smart_dedupe_resources".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_ext_and_fmwk_with_common_structured_resources",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_structured_resources.framework/Images/foo.png",
            "$BUNDLE_ROOT/Images/foo.png",
            "$BUNDLE_ROOT/PlugIns/ext_with_framework_with_structured_resources.appex/Images/foo.png",
        ],
        tags = [name],
    )

    # Verifies that resource bundles that are dependencies of a framework are
    # bundled with the framework if no deduplication is happening.
    # watchOS application and framework have the same minimum os version.
    archive_contents_test(
        name = "{}_does_not_contain_common_resource_bundle_from_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_resource_bundles_and_fmwk_with_resource_bundles",
        # Assert that the framework contains the bundled files...
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_resource_bundles.framework/basic.bundle",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_resource_bundles.framework/simple_bundle_library.bundle",
        ],
        # ...and that the application doesn't.
        not_contains = [
            "$BUNDLE_ROOT/simple_bundle_library.bundle",
            "$BUNDLE_ROOT/basic.bundle",
        ],
        tags = [name],
    )

    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [
            name,
        ],
    )

    apple_verification_test(
        name = "{}_fmwk_in_fmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_fmwk_in_fmwk_provisioned_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_fmwk_with_fmwk_provisioned",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_two_fmwk_provisioned_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_two_fmwk_provisioned",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_fmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_imported_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_framework_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app_with_imported_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [
            name,
        ],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "single_target_app",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "single_target_app",
            "CFBundlePackageType": "APPL",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": common.min_os_watchos.single_target_app,
            "UIDeviceFamily:0": "4",
            "WKApplication": "true",
        },
        tags = [
            name,
        ],
    )

    # TODO: b/433727264 - Create a new test with archive_contents_test once Xcode 26 beta 4 is
    # widely used by clients with the following target:
    # //test/starlark_tests/targets_under_test/watchos:app_with_icon_bundle_only_for_low_minimum_os_version

    # Tests the new icon composer bundles for Xcode 26.
    archive_contents_test(
        name = "{}_icon_composer_app_icons_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_icon_bundle",
        contains = [
            "$BUNDLE_ROOT/Assets.car",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName": "app_icon",
        },
        tags = [
            name,
        ],
    )

    # Tests the new icon composer bundles for Xcode 26, along with a set of asset catalog icons.
    archive_contents_test(
        name = "{}_icon_composer_and_asset_catalog_app_icons_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_icon_bundle_and_xcassets_app_icons",
        contains = [
            "$BUNDLE_ROOT/Assets.car",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName": "app_icon",
        },
        tags = [
            name,
        ],
    )

    # Tests xcasset tool is passed the correct arguments.
    analysis_target_actions_test(
        name = "{}_xcasset_actool_argv".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app",
        target_mnemonic = "AssetCatalogCompile",
        expected_argv = [
            "xctoolrunner actool --compile",
            "--minimum-deployment-target " + common.min_os_watchos.single_target_app,
            "--platform watchsimulator",
        ],
        tags = [
            name,
        ],
    )

    # Post-ABI stability, Swift should not be bundled at all.
    archive_contents_test(
        name = "{}_device_build_ios_swift_watchos_swift_stable_abi_test".format(name),
        build_type = "device",
        not_contains = [
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
            "$ARCHIVE_ROOT/SwiftSupport/watchos/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Watch/app.app/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Watch/app.app/PlugIns/ext.appex/Frameworks/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ios_with_swift_single_target_watchos_with_swift_stable_abi",
        tags = [
            name,
        ],
    )

    # Test that the output application binary is identified as watchOS simulator via the Mach-O
    # load command LC_BUILD_VERSION for the arm64 binary slice when only iOS cpus are defined, and
    # that 32-bit archs are eliminated.
    binary_contents_test(
        name = "{}_simulator_ios_cpus_intel_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion_arm64_support",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app_arm64_support.app/app_arm64_support",
        binary_test_architecture = "x86_64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output application binary is identified as watchOS simulator via the Mach-O
    # load command LC_BUILD_VERSION for the arm64 binary slice when only iOS cpus are defined, and
    # that 32-bit archs are eliminated.
    binary_contents_test(
        name = "{}_simulator_ios_cpus_arm_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion_arm64_support",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app_arm64_support.app/app_arm64_support",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output application binary is identified as watchOS device via the Mach-O
    # load command LC_BUILD_VERSION for the arm64 binary slice when only iOS cpus are defined, and
    # that it does not default to the unsupported armv7k architecture.
    binary_contents_test(
        name = "{}_device_ios_cpus_arm64_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion_arm64_support",
        cpus = {
            "ios_multi_cpus": ["arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app_arm64_support.app/app_arm64_support",
        binary_test_architecture = "arm64_32",
        binary_not_contains_architectures = ["armv7k", "arm64", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOS"],
        tags = [name],
    )

    # Test that the output application binary is identified as watchOS device via the Mach-O
    # load command LC_BUILD_VERSION for the arm64e binary slice when only iOS cpus are defined, and
    # that it does not default to the unsupported armv7k architecture.
    binary_contents_test(
        name = "{}_device_ios_cpus_arm64e_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion_arm64_support",
        cpus = {
            "ios_multi_cpus": ["arm64e"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app_arm64_support.app/app_arm64_support",
        binary_test_architecture = "arm64_32",
        binary_not_contains_architectures = ["armv7k", "arm64", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOS"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app_with_capability_set_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.watchkitapp",
        },
        tags = [name],
    )

    # Verifies that resource bundles that are dependencies of a framework are
    # bundled with the framework if no deduplication is happening.
    # watchOS application has baseline minimum os version and framework has baseline plus one.
    archive_contents_test(
        name = "{}_nplus1_does_not_contain_common_resource_bundle_from_framework_baseline".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_nplus1_with_resource_bundles_and_fmwk_baseline_with_resource_bundles",
        # Assert that the framework contains the bundled files...
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_resource_bundles.framework/basic.bundle",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_resource_bundles.framework/simple_bundle_library.bundle",
        ],
        # ...and that the application doesn't.
        not_contains = [
            "$BUNDLE_ROOT/simple_bundle_library.bundle",
            "$BUNDLE_ROOT/basic.bundle",
        ],
        tags = [name],
    )

    # Test app with transitive App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_transitive_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_transitive_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [
            name,
        ],
    )
