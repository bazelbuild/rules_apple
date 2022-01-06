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

"""macos_kernel_extension Starlark tests."""

load(
    ":rules/analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
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
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "unittest",
)

def _analysis_macos_cpu_test_impl(ctx):
    "Test the architechure passed in to the rule is correctly passed to clang."
    env = analysistest.begin(ctx)
    no_kext = True
    for action in analysistest.target_actions(env):
        if hasattr(action, "argv") and action.argv:
            concat_action_argv = " ".join(action.argv)
            if not "/wrapped_clang " in concat_action_argv:
                continue
            if not " -kext " in concat_action_argv:
                continue
            if not " -target {}-".format(ctx.attr.clang_cpu) in concat_action_argv:
                unittest.fail(env, "\"{}\" not passed to clang \"{}\".".format(
                    ctx.attr.clang_cpu,
                    concat_action_argv,
                ))
            no_kext = False

    if no_kext:
        unittest.fail(env, "Did not find a clang kext action to test.")
    return analysistest.end(env)

_analysis_arm64_macos_cpu_test = analysistest.make(
    _analysis_macos_cpu_test_impl,
    config_settings = {"//command_line_option:macos_cpus": "arm64"},
    attrs = {"clang_cpu": attr.string(default = "arm64e")},
    fragments = ["apple"],
)

_analysis_x86_64_macos_cpu_test = analysistest.make(
    _analysis_macos_cpu_test_impl,
    config_settings = {"//command_line_option:macos_cpus": "x86_64"},
    attrs = {"clang_cpu": attr.string(default = "x86_64")},
    fragments = ["apple"],
)

_analysis_default_macos_cpu_test = analysistest.make(
    _analysis_macos_cpu_test_impl,
    attrs = {"clang_cpu": attr.string(default = "x86_64")},
    fragments = ["apple"],
)

def macos_kernel_extension_test_suite(name):
    """Test suite for macos_kernel_extension.

    Args:
      name: the base name to be used in things created by this macro
    """
    analysis_target_outputs_test(
        name = "{}_zip_file_output_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        expected_outputs = ["kext.zip"],
        tags = [name],
    )

    _analysis_arm64_macos_cpu_test(
        name = "{}_arm64_macos_cpu_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        tags = [name],
    )

    _analysis_x86_64_macos_cpu_test(
        name = "{}_x86_64_macos_cpu_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        tags = [name],
    )

    _analysis_default_macos_cpu_test(
        name = "{}_default_macos_cpu_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_plist_test".format(name),
        build_type = "device",
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "kext",
            "CFBundleIdentifier": "com.google.kext",
            "CFBundleName": "kext",
            "CFBundlePackageType": "KEXT",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": "10.13",
            "IOKitPersonalities": "*",
            "OSBundleLibraries": "*",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_exported_symbols_list_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext_dead_stripped",
        binary_test_file = "$CONTENT_ROOT/MacOS/kext_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
