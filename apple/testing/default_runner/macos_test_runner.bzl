# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Sample Apple test runner rule."""

load(
    "@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
    "AppleTestRunner",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "is_xcode_at_least_version",
)

def _get_xctestrun_template_substitutions(ctx):
    """Returns the template substitutions for the xctestrun template."""
    xcode_version = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    # Xcode 10 introduced new dylibs that are required when running unit tests, so we need to
    # provide different values in the xctestrun file that describes the test.
    # TODO(kaipi): Revisit this when Nitro has support for macOS. Nitro should be the one detecting
    #              Xcode version and configuring it appropriately.
    if is_xcode_at_least_version(xcode_version, "10.0"):
        xctestrun_insert_libraries = [
            "__PLATFORMS__/MacOSX.platform/Developer/usr/lib/libXCTestBundleInject.dylib",
            "__DEVELOPERUSRLIB__/libMainThreadChecker.dylib",
        ]
    else:
        xctestrun_insert_libraries = [
            "__PLATFORMS__/MacOSX.platform/Developer/Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection",
        ]

    subs = {
        "xctestrun_insert_libraries": ":".join(xctestrun_insert_libraries),
    }

    return {"%(" + k + ")s": subs[k] for k in subs}

def _get_template_substitutions(xctestrun_template):
    """Returns the template substitutions for this runner."""
    subs = {
        "xctestrun_template": xctestrun_template.short_path,
    }

    return {"%(" + k + ")s": subs[k] for k in subs}

def _get_test_environment(ctx):
    """Returns the test environment for this runner."""
    test_environment = dict(ctx.configuration.test_env)
    xcode_version = str(ctx.attr._xcode_config[apple_common.XcodeVersionConfig].xcode_version())
    if xcode_version:
        test_environment["XCODE_VERSION"] = xcode_version

    return test_environment

def _macos_test_runner_impl(ctx):
    """Implementation for the macos_runner rule."""
    preprocessed_xctestrun_template = ctx.actions.declare_file(
        "{}.generated.xctestrun".format(ctx.label.name),
    )

    ctx.actions.expand_template(
        template = ctx.file._xctestrun_template,
        output = preprocessed_xctestrun_template,
        substitutions = _get_xctestrun_template_substitutions(ctx),
    )

    ctx.actions.expand_template(
        template = ctx.file._test_template,
        output = ctx.outputs.test_runner_template,
        substitutions = _get_template_substitutions(preprocessed_xctestrun_template),
    )

    return [
        AppleTestRunner(
            test_runner_template = ctx.outputs.test_runner_template,
            execution_requirements = {"requires-darwin": ""},
            test_environment = _get_test_environment(ctx),
        ),
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = [preprocessed_xctestrun_template],
            ),
        ),
    ]

macos_test_runner = rule(
    _macos_test_runner_impl,
    attrs = {
        "_test_template": attr.label(
            default = Label("@build_bazel_rules_apple//apple/testing/default_runner:macos_test_runner.template.sh"),
            allow_single_file = True,
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                fragment = "apple",
                name = "xcode_config_label",
            ),
        ),
        "_xctestrun_template": attr.label(
            default = Label("@build_bazel_rules_apple//apple/testing/default_runner:macos_test_runner.template.xctestrun"),
            allow_single_file = True,
        ),
    },
    outputs = {
        "test_runner_template": "%{name}.sh",
    },
    fragments = ["apple", "objc"],
)
"""Rule to identify an macOS runner that runs tests for macOS.

Provides:
  AppleTestRunner:
    test_runner_template: Template file that contains the specific mechanism
        with which the tests will be performed.
    execution_requirements: Dictionary that represents the specific hardware
        requirements for this test.
    test_environment: Dictionary with the environment variables required for the
        test.
  Runfiles:
    files: The files needed during runtime for the test to be performed.
"""
