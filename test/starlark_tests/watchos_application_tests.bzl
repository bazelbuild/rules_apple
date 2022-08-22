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

"""watchos_application Starlark tests."""

load(
    ":common.bzl",
    "common",
)
load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    ":rules/analysis_target_actions_test.bzl",
    "analysis_target_actions_test",
)

def watchos_application_test_suite(name):
    """Test suite for watchos_application.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_no_custom_fmwks_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_with_imported_fmwk",
        verifier_script = "verifier_scripts/no_custom_fmwks_verifier.sh",
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "app",
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
            "MinimumOSVersion": common.min_os_watchos.baseline,
            "UIDeviceFamily:0": "4",
            "WKWatchKitApp": "true",
        },
        tags = [name],
    )

    # Tests xcasset tool is passed the correct arguments.
    analysis_target_actions_test(
        name = "{}_xcasset_actool_argv".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        target_mnemonic = "AssetCatalogCompile",
        expected_argv = [
            "xctoolrunner actool --compile",
            "--minimum-deployment-target " + common.min_os_watchos.baseline,
            "--product-type com.apple.product-type.application.watchapp2",
            "--platform watchsimulator",
        ],
        tags = [name],
    )

    # Tests that the WatchKit stub executable is bundled everywhere it's
    # supposed to be. This must be tested through the companion app since
    # the `WatchKitSupport2` directory is only added at the root of archives
    # for distribution.
    archive_contents_test(
        name = "{}_contains_stub_executable_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        contains = [
            "$ARCHIVE_ROOT/WatchKitSupport2/WK",
            "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        ],
        tags = [name],
    )

    # Tests inclusion of extensions within Watch extensions
    archive_contents_test(
        name = "{}_contains_watchos_extension_extension".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ios_watchos_with_watchos_extension",
        contains = [
            "$BUNDLE_ROOT/Watch/app.app/PlugIns/ext.appex/PlugIns/watchos_app_extension.appex/watchos_app_extension",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
