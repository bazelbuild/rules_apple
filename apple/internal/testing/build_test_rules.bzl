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

"""Rules for writing build tests for libraries that target Apple platforms."""

load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)

_PASSING_TEST_SCRIPT = """\
#!/bin/bash
exit 0
"""

def _apple_build_test_rule_impl(ctx):
    if ctx.attr.platform_type != ctx.attr._platform_type:
        fail((
            "The 'platform_type' attribute of '{}' is an implementation " +
            "detail and will be removed in the future; do not change it."
        ).format(ctx.rule.kind))

    targets = ctx.attr.targets
    transitive_files = [target[DefaultInfo].files for target in targets]

    # The test's executable is a vacuously passing script. We pass all of the
    # default outputs from the list of targets as the test's runfiles, so as
    # long as they all build successfully, the entire test will pass.
    ctx.actions.write(
        content = _PASSING_TEST_SCRIPT,
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return [DefaultInfo(
        executable = ctx.outputs.executable,
        runfiles = ctx.runfiles(
            transitive_files = depset(transitive = transitive_files),
        ),
    )]

def apple_build_test_rule(doc, platform_type):
    """Creates and returns an Apple build test rule for the given platform.

    Args:
        doc: The documentation string for the rule.
        platform_type: The Apple platform for which the test should build its
            targets (`"ios"`, `"macos"`, `"tvos"`, or `"watchos"`).

    Returns:
        The created `rule`.
    """

    # TODO(b/161808913): Once resource processing actions have all been moved
    #  into the resource aspect (that is, they are processed at the library
    # level), apply the aspect to the targets and collect the processed
    # resource outputs so that the build test can verify that resources also
    # compile successfully; right now we just verify that the code in the
    # libraries compiles.
    return rule(
        attrs = {
            "minimum_os_version": attr.string(
                doc = """\
A required string indicating the minimum OS version that will be used as the
deployment target when building the targets, represented as a dotted version
number (for example, `"9.0"`).
""",
            ),
            "targets": attr.label_list(
                cfg = apple_common.multi_arch_split,
                doc = "The targets to check for successful build.",
                # Since `CcInfo` is the currency provider for rules that
                # propagate libraries for linking to Apple bundles, this is
                # sufficient to cover C++, Objective-C, and Swift rules.
                # TODO(b/161808913): When we can support resource processing,
                # add the resource providers so that standalone resource
                # targets can also be included here.
                providers = [[CcInfo]],
            ),
            # This is a public attribute due to an implementation detail of
            # `apple_common.multi_arch_split`. The private attribute of the
            # same name is used in the implementation function to verify that
            # the user has not modified it.
            "platform_type": attr.string(default = platform_type),
            "_platform_type": attr.string(default = platform_type),
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
        doc = doc,
        implementation = _apple_build_test_rule_impl,
        test = True,
        cfg = transition_support.apple_rule_transition,
    )
