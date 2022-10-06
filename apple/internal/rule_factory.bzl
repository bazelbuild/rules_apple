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
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:framework_provider_aspect.bzl",
    "framework_provider_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_rule_support.bzl",
    "coverage_files_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleBundleVersionInfo",
    "AppleTestRunnerInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "use_cpp_toolchain")

def _is_test_product_type(product_type):
    """Returns whether the given product type is for tests purposes or not."""
    return product_type in (
        apple_product_type.ui_test_bundle,
        apple_product_type.unit_test_bundle,
    )

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
    "_apple_coverage_support": attr.label(
        cfg = "exec",
        default = Label("@build_bazel_apple_support//tools:coverage_support"),
    ),
    # gcov and mcov are binary files required to calculate test coverage.
    "_gcov": attr.label(
        cfg = "exec",
        default = Label("@bazel_tools//tools/objc:gcov"),
        allow_single_file = True,
    ),
    "_mcov": attr.label(
        cfg = "exec",
        default = Label("@bazel_tools//tools/objc:mcov"),
        allow_single_file = True,
    ),
}

def _get_macos_binary_attrs(rule_descriptor):
    """Returns a list of dictionaries with attributes for macOS binary rules."""
    attrs = []

    if rule_descriptor.requires_provisioning_profile:
        attrs.append({
            "provisioning_profile": attr.label(
                allow_single_file = [rule_descriptor.provisioning_profile_extension],
                doc = """
The provisioning profile (`{profile_extension}` file) to use when creating the bundle. This value is
optional for simulator builds as the simulator doesn't fully enforce entitlements, but is
required for device builds.
""".format(profile_extension = rule_descriptor.provisioning_profile_extension),
            ),
        })

    if rule_descriptor.product_type == apple_product_type.tool:
        # TODO(b/250698827): Explicitly scope this attribute and its documentation exclusively to
        # macos_command_line_application; there are internal macOS rules that set a product type of
        # apple_product_type.tool.
        attrs.append({
            "launchdplists": attr.label_list(
                allow_files = [".plist"],
                doc = """
A list of system wide and per-user daemon/agent configuration files, as specified by the launch
plist manual that can be found via `man launchd.plist`. These are XML files that can be loaded into
launchd with launchctl, and are required of command line applications that are intended to be used
as launch daemons and agents on macOS. All `launchd.plist`s referenced by this attribute will be
merged into a single plist and written directly into the `__TEXT`,`__launchd_plist` section of the
linked binary.
""",
            ),
        })

    attrs.append({
        "bundle_id": attr.string(
            doc = """
The bundle ID (reverse-DNS path followed by app name) of the command line application. If present,
this value will be embedded in an Info.plist in the application binary.
""",
        ),
        "infoplists": attr.label_list(
            allow_files = [".plist"],
            doc = """
A list of .plist files that will be merged to form the Info.plist that represents the application
and is embedded into the binary. Please see
[Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling)
for what is supported.
""",
        ),
        "version": attr.label(
            providers = [[AppleBundleVersionInfo]],
            doc = """
An `apple_bundle_version` target that represents the version for this target. See
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).
""",
        ),
    })

    return attrs

def _create_apple_binary_rule(
        implementation,
        doc,
        additional_attrs = {},
        cfg = transition_support.apple_rule_transition,
        implicit_outputs = None,
        platform_type = None,
        product_type = None,
        require_linking_attrs = True):
    """Creates an Apple rule that produces a single binary output."""
    attrs = [
        {
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
    ]

    if platform_type:
        attrs.extend([
            rule_attrs.common_tool_attrs,
            rule_attrs.platform_attrs(platform_type = platform_type, add_environment_plist = True),
        ])
    else:
        attrs.append(rule_attrs.platform_attrs())

    if platform_type and product_type:
        rule_descriptor = rule_support.rule_descriptor(
            platform_type = platform_type,
            product_type = product_type,
        )
        is_executable = rule_descriptor.is_executable

        if rule_descriptor.requires_deps:
            attrs.append(rule_attrs.binary_linking_attrs(
                deps_cfg = rule_descriptor.deps_cfg,
                extra_deps_aspects = [
                    apple_resource_aspect,
                    framework_provider_aspect,
                ],
                is_test_supporting_rule = _is_test_product_type(product_type),
                requires_legacy_cc_toolchain = True,
            ))

        attrs.extend(
            [
                {"_product_type": attr.string(default = product_type)},
            ] + _get_macos_binary_attrs(rule_descriptor),
        )
    else:
        is_executable = False
        if require_linking_attrs:
            attrs.append(rule_attrs.binary_linking_attrs(
                deps_cfg = apple_common.multi_arch_split,
                is_test_supporting_rule = False,
                requires_legacy_cc_toolchain = True,
            ))
        else:
            attrs.append(rule_attrs.common_attrs)

    attrs.append(additional_attrs)

    return rule(
        implementation = implementation,
        attrs = dicts.add(*attrs),
        cfg = cfg,
        doc = doc,
        executable = is_executable,
        fragments = ["apple", "cpp", "objc"],
        outputs = implicit_outputs,
        toolchains = use_cpp_toolchain(),
    )

def _create_apple_bundling_rule_with_attrs(
        *,
        archive_extension = ".zip",
        attrs,
        cfg = transition_support.apple_rule_transition,
        doc,
        implementation,
        is_executable = False):
    """Creates an Apple bundling rule with additional control of the set of rule attributes.

    Args:
        archive_extension: An extension to be applied to the generated archive file. Optional. This
            will be `.zip` by default.
        attrs: A list of dictionaries of attributes to be applied to the generated rule.
        cfg: The rule transition to be applied directly on the generated rule. Optional. This will
            be the Starlark Apple rule transition `transition_support.apple_rule_transition` by
            default.
        doc: The documentation string for the rule itself.
        implementation: The method to handle the implementation of the given rule.
        is_executable: Boolean. If set to True, marks the rule as executable. Optional. False by
            default.
    """

    return rule(
        implementation = implementation,
        attrs = dicts.add(
            {
                # Required to use the Apple Starlark rule and split transitions.
                "_allowlist_function_transition": attr.label(
                    default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
                ),
            },
            *attrs
        ),
        cfg = cfg,
        doc = doc,
        executable = is_executable,
        fragments = ["apple", "cpp", "objc"],
        outputs = {"archive": "%{name}" + archive_extension},
        toolchains = use_cpp_toolchain(),
    )

def _create_apple_test_rule(implementation, doc, platform_type):
    """Creates an Apple test rule."""

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

    return rule(
        implementation = implementation,
        attrs = dicts.add(
            rule_attrs.common_tool_attrs,
            _COMMON_TEST_ATTRS,
            *ide_visible_attrs
        ),
        doc = doc,
        test = True,
        toolchains = use_cpp_toolchain(),
    )

rule_factory = struct(
    create_apple_binary_rule = _create_apple_binary_rule,
    create_apple_bundling_rule_with_attrs = _create_apple_bundling_rule_with_attrs,
    create_apple_test_rule = _create_apple_test_rule,
)
