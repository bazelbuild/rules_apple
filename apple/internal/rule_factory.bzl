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

"""Helpers for defining Apple bundling rules uniformly."""

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "use_cpp_toolchain")
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleInfo",
    "AppleTestRunnerInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_rule_support.bzl",
    "coverage_files_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

# Returns the common set of rule attributes to support Apple test rules.
# TODO(b/246990309): Move _COMMON_TEST_ATTRS to rule attrs in a follow up CL.
_COMMON_TEST_ATTRS = {
    "data": attr.label_list(
        allow_files = True,
        default = [],
        doc = "Files to be made available to the test during its execution.",
    ),
    "env": attr.string_dict(
        doc = """
Dictionary of environment variables that should be set during the test execution.
""",
    ),
    "runner": attr.label(
        doc = """
The runner target that will provide the logic on how to run the tests. Needs to provide the
AppleTestRunnerInfo provider.
""",
        mandatory = True,
        providers = [AppleTestRunnerInfo],
    ),
    # This is an implementation detail attribute, so it's not documented on purpose.
    "deps": attr.label_list(
        mandatory = True,
        aspects = [coverage_files_aspect],
        providers = [AppleBundleInfo],
    ),
}

# The name of the execution group used for C++ toolchain linking actions, as
# documented at
# https://bazel.build/extending/exec-groups#exec-groups-for-native-rules.
_CPP_LINK_EXEC_GROUP = "cpp_link"

def _create_apple_rule(
        *,
        avoid_apple_exec_group_toolchain = False,
        cfg,
        doc,
        implementation,
        is_executable = False,
        predeclared_outputs = {},
        toolchains = use_cpp_toolchain(),
        attrs):
    """Creates an Apple bundling rule with additional control of the set of rule attributes.

    Args:
        avoid_apple_exec_group_toolchain: Boolean to determine if the rule should depend on the
            Apple exec group toolchain.
        cfg: The rule transition to be applied directly on the generated rule.
        doc: The documentation string for the rule itself.
        implementation: The method to handle the implementation of the given rule. Optional. True
            by default.
        toolchains: List. A list of toolchains that this rule requires. Optional. If not set, adds
            the cpp toolchain to the rule definition as its sole requirement.
        is_executable: Boolean. If set to True, marks the rule as executable. Optional. False by
            default.
        predeclared_outputs: A dictionary of any predeclared outputs that the rule is expected to
            have. Optional. An empty dictionary by default.
        attrs: A list of dictionaries of attributes to be applied to the generated rule.
    """
    extra_args = {}
    if predeclared_outputs:
        extra_args["outputs"] = predeclared_outputs

    exec_groups = {
        _CPP_LINK_EXEC_GROUP: exec_group(),
    }

    if not avoid_apple_exec_group_toolchain:
        exec_groups = dicts.add(
            exec_groups,
            apple_toolchain_utils.use_apple_exec_group_toolchain(),
        )

    return rule(
        implementation = implementation,
        attrs = dicts.add(
            *attrs
        ),
        cfg = cfg,
        doc = doc,
        executable = is_executable,
        exec_groups = exec_groups,
        fragments = [
            "apple",
            "cpp",
            "objc",
        ],
        toolchains = toolchains,
        **extra_args
    )

def _create_apple_test_rule(*, cfg = None, doc, implementation, platform_type):
    """Creates an Apple test rule.

    Args:
        cfg: An optional rule transition to be applied directly on the generated test rule. This
            configuration will apply to test bundle and test host targets by association.
        doc: The documentation string for the rule itself.
        implementation: The method to handle the implementation of the given rule. Optional. True
            by default.
        platform_type: String value to indicate the required `platform_type`.
    """

    extra_args = {}

    # These attrs are exposed for IDE experiences via `bazel query` as long as these test rules are
    # split between an actual test rule and a test bundle rule generated by a macro.
    #
    # These attrs are not required for linking the test rule itself. However, similarly named attrs
    # are all used for linking the test bundle target that is an implementation detail of the macros
    # that generate Apple tests. That information is still of interest to IDEs via `bazel query`.
    ide_visible_attrs = [
        # The private environment plist attr is omitted as it's of no use to IDE experiences.
        rule_attrs.platform_attrs(platform_type = platform_type),
        # The aspect is withheld to avoid unnecessary overhead in this instance of `test_host`, and
        # the provider is unnecessarily generic to accomodate any possible value of `test_host`.
        rule_attrs.test_host_attrs(aspects = [], providers = [[AppleBundleInfo]]),
    ]

    if cfg:
        extra_args = {
            "cfg": cfg,
        }

    return rule(
        implementation = implementation,
        attrs = dicts.add(
            rule_attrs.common_tool_attrs(),
            _COMMON_TEST_ATTRS,
            *ide_visible_attrs
        ),
        doc = doc,
        exec_groups = dicts.add(
            {
                _CPP_LINK_EXEC_GROUP: exec_group(),
            },
            apple_toolchain_utils.use_apple_exec_group_toolchain(),
        ),
        test = True,
        toolchains = use_cpp_toolchain(),
        **extra_args
    )

rule_factory = struct(
    create_apple_rule = _create_apple_rule,
    create_apple_test_rule = _create_apple_test_rule,
)
