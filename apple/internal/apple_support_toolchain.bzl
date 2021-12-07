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
            dsym_info_plist_template = ctx.file.dsym_info_plist_template,
            process_and_sign_template = ctx.file.process_and_sign_template,
            resolved_alticonstool = _resolve_tools_for_executable(
                attr_name = "alticonstool",
                rule_ctx = ctx,
            ),
            resolved_bundletool = _resolve_tools_for_executable(
                attr_name = "bundletool",
                rule_ctx = ctx,
            ),
            resolved_bundletool_experimental = _resolve_tools_for_executable(
                attr_name = "bundletool_experimental",
                rule_ctx = ctx,
            ),
            resolved_codesigningtool = _resolve_tools_for_executable(
                attr_name = "codesigningtool",
                rule_ctx = ctx,
            ),
            resolved_dossier_codesigningtool = _resolve_tools_for_executable(
                attr_name = "dossier_codesigningtool",
                rule_ctx = ctx,
            ),
            resolved_clangrttool = _resolve_tools_for_executable(
                attr_name = "clangrttool",
                rule_ctx = ctx,
            ),
            resolved_imported_dynamic_framework_processor = _resolve_tools_for_executable(
                attr_name = "imported_dynamic_framework_processor",
                rule_ctx = ctx,
            ),
            resolved_plisttool = _resolve_tools_for_executable(
                attr_name = "plisttool",
                rule_ctx = ctx,
            ),
            resolved_provisioning_profile_tool = _resolve_tools_for_executable(
                attr_name = "provisioning_profile_tool",
                rule_ctx = ctx,
            ),
            resolved_swift_stdlib_tool = _resolve_tools_for_executable(
                attr_name = "swift_stdlib_tool",
                rule_ctx = ctx,
            ),
            resolved_xctoolrunner = _resolve_tools_for_executable(
                attr_name = "xctoolrunner",
                rule_ctx = ctx,
            ),
        ),
        DefaultInfo(),
    ]

# Define an Apple toolchain rule with tools built in the default configuration.
apple_support_toolchain = rule(
    attrs = {
        "alticonstool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to insert alternate icons entries in the app bundle's `Info.plist`.
""",
        ),
        "bundletool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to create an Apple bundle by taking a list of files/ZIPs and destination
paths to build the directory structure for those files.
""",
        ),
        "bundletool_experimental": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing an experimental tool to create an Apple bundle by combining the bundling,
post-processing, and signing steps into a single action that eliminates the archiving step.
""",
        ),
        "clangrttool": attr.label(
            cfg = "exec",
            executable = True,
            doc = "A `File` referencing a tool to find all Clang runtime libs linked to a binary.",
        ),
        "codesigningtool": attr.label(
            cfg = "exec",
            executable = True,
            doc = "A `File` referencing a tool to assist in signing bundles.",
        ),
        "dossier_codesigningtool": attr.label(
            cfg = "exec",
            executable = True,
            doc = "A `File` referencing a tool to assist in generating signing dossiers.",
        ),
        "dsym_info_plist_template": attr.label(
            cfg = "exec",
            allow_single_file = True,
            doc = "A `File` referencing a plist template for dSYM bundles.",
        ),
        "imported_dynamic_framework_processor": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to process an imported dynamic framework such that the given framework
only contains the same slices as the app binary, every file belonging to the dynamic framework is
copied to a temporary location, and the dynamic framework is codesigned and zipped as a cacheable
artifact.
""",
        ),
        "plisttool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to perform plist operations such as variable substitution, merging, and
conversion of plist files to binary format.
""",
        ),
        "process_and_sign_template": attr.label(
            allow_single_file = True,
            doc = "A `File` referencing a template for a shell script to process and sign.",
        ),
        "provisioning_profile_tool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool that extracts entitlements from a provisioning profile.
""",
        ),
        "swift_stdlib_tool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool that copies and lipos Swift stdlibs required for the target to run.
""",
        ),
        "xctoolrunner": attr.label(
            cfg = "exec",
            executable = True,
            doc = "A `File` referencing a tool that acts as a wrapper for xcrun actions.",
        ),
    },
    doc = """Represents an Apple support toolchain""",
    implementation = _apple_support_toolchain_impl,
)

# Define the loadable module that lists the exported symbols in this file.
apple_support_toolchain_utils = struct(
    shared_attrs = _shared_attrs,
)
