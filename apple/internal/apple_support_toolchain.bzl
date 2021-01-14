# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Shared toolchain required for processing Apple bundling rules."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleSupportToolchainInfo",
)

def _shared_attrs():
    """Private attributes on every rule to provide access to bundling tools and other file deps."""
    return {
        "_toolchain": attr.label(
            default = Label("@build_bazel_rules_apple//apple/internal:toolchain_support"),
            providers = [[AppleSupportToolchainInfo]],
        ),
    }

def _resolve_tools_for_executable(*, rule_ctx, attr_name):
    """Helper macro to resolve executable runfile dependencies across the rule boundary."""

    # TODO(b/111036105) Migrate away from this helper and its outputs once ctx.executable works
    # across rule boundaries.
    executable = getattr(rule_ctx.executable, attr_name)
    target = getattr(rule_ctx.attr, attr_name)
    inputs, input_manifests = rule_ctx.resolve_tools(tools = [target])
    return struct(
        executable = executable,
        inputs = inputs,
        input_manifests = input_manifests,
    )

def _apple_support_toolchain_impl(ctx):
    return [
        AppleSupportToolchainInfo(
            dsym_info_plist_template = ctx.file._dsym_info_plist_template,
            macos_runner_template = ctx.file._macos_runner_template,
            process_and_sign_template = ctx.file._process_and_sign_template,
            resolved_bundletool = _resolve_tools_for_executable(
                attr_name = "_bundletool",
                rule_ctx = ctx,
            ),
            resolved_bundletool_experimental = _resolve_tools_for_executable(
                attr_name = "_bundletool_experimental",
                rule_ctx = ctx,
            ),
            resolved_codesigningtool = _resolve_tools_for_executable(
                attr_name = "_codesigningtool",
                rule_ctx = ctx,
            ),
            resolved_clangrttool = _resolve_tools_for_executable(
                attr_name = "_clangrttool",
                rule_ctx = ctx,
            ),
            resolved_imported_dynamic_framework_processor = _resolve_tools_for_executable(
                attr_name = "_imported_dynamic_framework_processor",
                rule_ctx = ctx,
            ),
            resolved_plisttool = _resolve_tools_for_executable(
                attr_name = "_plisttool",
                rule_ctx = ctx,
            ),
            resolved_swift_stdlib_tool = _resolve_tools_for_executable(
                attr_name = "_swift_stdlib_tool",
                rule_ctx = ctx,
            ),
            resolved_xctoolrunner = _resolve_tools_for_executable(
                attr_name = "_xctoolrunner",
                rule_ctx = ctx,
            ),
            # TODO(b/74731511): Refactor the runner_template attribute into being specified for each
            # platform.
            runner_template = ctx.file._runner_template,
            std_redirect_dylib = ctx.file._std_redirect_dylib,
        ),
        DefaultInfo(),
    ]

# Define an Apple toolchain rule with tools built in the default configuration.
apple_support_toolchain = rule(
    # TODO(b/162832260): Make these attributes within the toolchain public, for the purposes of
    # being able to specify them in the BUILD file. Will need to clean up the runner template usage
    # first and other bits such that these individual tool targets don't need public visibility.
    attrs = {
        "_bundletool": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/bundletool"),
        ),
        "_bundletool_experimental": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/bundletool:bundletool_experimental"),
        ),
        "_clangrttool": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/clangrttool"),
        ),
        "_codesigningtool": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/codesigningtool"),
        ),
        "_dsym_info_plist_template": attr.label(
            cfg = "host",
            allow_single_file = True,
            default = Label(
                "@build_bazel_rules_apple//apple/internal/templates:dsym_info_plist_template",
            ),
        ),
        "_imported_dynamic_framework_processor": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/imported_dynamic_framework_processor"),
        ),
        "_macos_runner_template": attr.label(
            cfg = "host",
            allow_single_file = True,
            default = Label("@build_bazel_rules_apple//apple/internal/templates:macos_template"),
        ),
        "_plisttool": attr.label(
            cfg = "host",
            default = Label("@build_bazel_rules_apple//tools/plisttool"),
            executable = True,
        ),
        "_process_and_sign_template": attr.label(
            allow_single_file = True,
            default = Label("@build_bazel_rules_apple//tools/bundletool:process_and_sign_template"),
        ),
        # TODO(b/74731511): Refactor _runner_template into being specified for each platform.
        "_runner_template": attr.label(
            cfg = "host",
            allow_single_file = True,
            default = Label("@build_bazel_rules_apple//apple/internal/templates:ios_sim_template"),
        ),
        "_std_redirect_dylib": attr.label(
            cfg = "host",
            allow_single_file = True,
            default = Label("@bazel_tools//tools/objc:StdRedirect.dylib"),
        ),
        "_swift_stdlib_tool": attr.label(
            cfg = "host",
            default = Label("@build_bazel_rules_apple//tools/swift_stdlib_tool"),
            executable = True,
        ),
        "_xctoolrunner": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/xctoolrunner"),
        ),
    },
    doc = """Represents an Apple support toolchain""",
    implementation = _apple_support_toolchain_impl,
)

# Define the loadable module that lists the exported symbols in this file.
apple_support_toolchain_utils = struct(
    resolve_tools_for_executable = _resolve_tools_for_executable,
    shared_attrs = _shared_attrs,
)
