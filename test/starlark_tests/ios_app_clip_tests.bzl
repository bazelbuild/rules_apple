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

"""ios_app_clip Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
    "bitcode_symbol_map_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    ":rules/linkmap_test.bzl",
    "linkmap_test",
)

def ios_app_clip_test_suite(name):
    """Test suite for ios_app_clip.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Tests that app clip is codesigned when built as a standalone app
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        verifier_script = "verifier_scripts/app_clip_codesign_verifier.sh",
        tags = [name],
    )

    # Tests that app clip entitlements are added when built for simulator.
    apple_verification_test(
        name = "{}_app_clip_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        verifier_script = "verifier_scripts/app_clip_entitlements_verifier.sh",
        tags = [name],
    )

    # Tests that app clip entitlements are added when built for device.
    apple_verification_test(
        name = "{}_app_clip_entitlements_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        verifier_script = "verifier_scripts/app_clip_entitlements_verifier.sh",
        tags = [name],
    )

    # Tests that entitlements are present when specified and built for simulator.
    apple_verification_test(
        name = "{}_entitlements_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    # Tests that entitlements are present when specified and built for device.
    apple_verification_test(
        name = "{}_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    # Tests that the archive contains Bitcode symbol maps when Bitcode is
    # enabled.
    bitcode_symbol_map_test(
        name = "{}_archive_contains_bitcode_symbol_maps_test".format(name),
        binary_paths = [
            "Payload/app_with_app_clip.app/app_with_app_clip",
            "Payload/app_with_app_clip.app/AppClips/app_clip.app/app_clip",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_app_clip",
        tags = [name],
    )

    # Tests that the linkmap outputs are produced when `--objc_generate_linkmap`
    # is present.
    linkmap_test(
        name = "{}_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        tags = [name],
    )

    # Verifies that Info.plist contains correct package type
    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app_clip",
            "CFBundleIdentifier": "com.google.example.clip",
            "CFBundleName": "app_clip",
            "CFBundlePackageType": "APPL",
            "CFBundleSupportedPlatforms:0": "iPhone*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "iphone*",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "iphone*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "14.0",
            "UIDeviceFamily:0": "1",
        },
        tags = [name],
    )

    # Tests that the provisioning profile is present when built for device.
    archive_contents_test(
        name = "{}_contains_provisioning_profile_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_clip",
        contains = [
            "$BUNDLE_ROOT/embedded.mobileprovision",
        ],
        tags = [name],
    )

    # Tests that the provisioning profile is present when built for device and embedded in an app.
    archive_contents_test(
        name = "{}_embedding_provisioning_profile_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_app_clip",
        contains = [
            "$BUNDLE_ROOT/AppClips/app_clip.app/embedded.mobileprovision",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
