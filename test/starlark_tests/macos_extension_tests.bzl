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

"""macos_extension Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:apple_dsym_bundle_info_test.bzl",
    "apple_dsym_bundle_info_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
    "entry_point_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

visibility("private")

def macos_extension_test_suite(name):
    """Test suite for macos_extension.

    Args:
      name: the base name to be used in things created by this macro
    """
    entry_point_test(
        name = "{}_entry_point_nsextensionmain_test".format(name),
        build_type = "simulator",
        entry_point = "_NSExtensionMain",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:ext",
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:ext_with_capability_set_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.ext-with-capability-set-derived-bundle-id",
        },
        tags = [name],
    )

    # Test that an ExtensionKit extension is bundled in Extensions and not PlugIns.
    archive_contents_test(
        name = "{}_extensionkit_bundling_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_extensionkit_ext",
        contains = ["$BUNDLE_ROOT/Contents/Extensions/extensionkit_ext.appex/Contents/MacOS/extensionkit_ext"],
        not_contains = ["$BUNDLE_ROOT/Contents/PlugIns/extensionkit_ext.appex/Contents/MacOS/extensionkit_ext"],
        tags = [name],
    )

    # Test ext with App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:ext_with_transitive_app_intents",
        contains = [
            "$RESOURCE_ROOT/Metadata.appintents/extract.actionsdata",
            "$RESOURCE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_with_fmwk_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:ext_with_fmwk",
        not_contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_with_imported_static_fmwk_contains_symbols_and_bundles_resources".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_fmwk_and_ext",
        cpus = {"macos_cpus": ["arm64"]},
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        is_not_binary_plist = ["$BUNDLE_ROOT/Contents/Resources/macOSStaticFramework.bundle/Info.plist"],
        contains = ["$BUNDLE_ROOT/Contents/Resources/macOSStaticFramework.bundle/Info.plist"],
        not_contains = ["$BUNDLE_ROOT/Contents/Frameworks/macOSStaticFramework.framework"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_with_imported_dynamic_fmwk_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_fmwk_and_ext",
        cpus = {"macos_cpus": ["arm64"]},
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/macOSDynamicFramework.framework/Versions/A/Resources/Info.plist",
            "$BUNDLE_ROOT/Contents/Frameworks/macOSDynamicFramework.framework/Versions/A/macOSDynamicFramework",
            "$BUNDLE_ROOT/Contents/Frameworks/macOSDynamicFramework.framework/Versions/A/Resources/macOSDynamicFramework.bundle/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/macOSDynamicFramework.framework/Versions/A/Headers/SharedClass.h",
            "$BUNDLE_ROOT/Contents/Frameworks/macOSDynamicFramework.framework/Versions/A/Headers/macOSDynamicFramework.h",
            "$BUNDLE_ROOT/Contents/Frameworks/macOSDynamicFramework.framework/Versions/A/Modules/module.modulemap",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_with_runtime_framework_transitive_dsyms_output_group_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:ext_with_fmwks_from_objc_swift_libraries_using_data",
        output_group_name = "dsyms",
        expected_outputs = [
            "ext_with_fmwks_from_objc_swift_libraries_using_data.appex.dSYM",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_with_runtime_framework_transitive_linkmaps_output_group_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:ext_with_fmwks_from_objc_swift_libraries_using_data",
        output_group_name = "linkmaps",
        expected_outputs = [
            "ext_with_fmwks_from_objc_swift_libraries_using_data_arm64.linkmap",
            "ext_with_fmwks_from_objc_swift_libraries_using_data_x86_64.linkmap",
        ],
        tags = [name],
    )

    apple_dsym_bundle_info_test(
        name = "{}_with_runtime_framework_dsym_bundle_info_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:ext_with_fmwks_from_objc_swift_libraries_using_data",
        expected_direct_dsyms = [
            "ext_with_fmwks_from_objc_swift_libraries_using_data.appex.dSYM",
        ],
        expected_transitive_dsyms = [
            "ext_with_fmwks_from_objc_swift_libraries_using_data.appex.dSYM",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
