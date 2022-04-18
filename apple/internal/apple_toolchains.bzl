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

AppleMacToolsToolchainInfo = provider(
    doc = """
Propagates information about an Apple toolchain to internal bundling rules that use the toolchain.

This provider exists as an internal detail for the rules to reference common, executable tools and
files used as script templates for the purposes of executing Apple actions. Defined by the
`apple_mac_tools_toolchain` rule.

This toolchain is for the tools (and support files) for actions that *must* run on a Mac.
""",
    fields = {
        "dsym_info_plist_template": """\
A `File` referencing a plist template for dSYM bundles.
""",
        "process_and_sign_template": """\
A `File` referencing a template for a shell script to process and sign.
""",
        "resolved_alticonstool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to insert alternate icons entries in the app
bundle's `Info.plist`.
""",
        "resolved_bundletool_experimental": """\
A `struct` from `ctx.resolve_tools` referencing an experimental tool to create an Apple bundle by
combining the bundling, post-processing, and signing steps into a single action that eliminates the
archiving step.
""",
        "resolved_clangrttool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to find all Clang runtime libs linked to a
binary.
""",
        "resolved_codesigningtool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to select the appropriate signing identity
for Apple apps and Apple executable bundles.
""",
        "resolved_dossier_codesigningtool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to generate codesigning dossiers.
""",
        "resolved_environment_plist_tool": """\
A `struct` from `ctx.resolve_tools` referencing a tool for collecting dev environment values.
""",
        "resolved_imported_dynamic_framework_processor": """\
A `struct` from `ctx.resolve_tools` referencing a tool to process an imported dynamic framework
such that the given framework only contains the same slices as the app binary, every file belonging
to the dynamic framework is copied to a temporary location, and the dynamic framework is codesigned
and zipped as a cacheable artifact.
""",
        "resolved_plisttool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to perform plist operations such as variable
substitution, merging, and conversion of plist files to binary format.
""",
        "resolved_provisioning_profile_tool": """\
A `struct` from `ctx.resolve_tools` referencing a tool that extracts entitlements from a
provisioning profile.
""",
        "resolved_swift_stdlib_tool": """\
A `struct` from `ctx.resolve_tools` referencing a tool that copies and lipos Swift stdlibs required
for the target to run.
""",
        "resolved_xctoolrunner": """\
A `struct` from `ctx.resolve_tools` referencing a tool that acts as a wrapper for xcrun actions.
""",
    },
)

AppleXPlatToolsToolchainInfo = provider(
    doc = """
Propagates information about an Apple toolchain to internal bundling rules that use the toolchain.

This provider exists as an internal detail for the rules to reference common, executable tools and
files used as script templates for the purposes of executing Apple actions. Defined by the
`apple_xplat_tools_toolchain` rule.

This toolchain is for the tools (and support files) for actions that can run on any platform,
i.e. - they do *not* have to run on a Mac.
""",
    fields = {
        "resolved_bundletool": """\
A `struct` from `ctx.resolve_tools` referencing a tool to create an Apple bundle by taking a list of
files/ZIPs and destinations paths to build the directory structure for those files.
""",
        "resolved_versiontool": """\
A `struct` from `ctx.resolve_tools` referencing a tool that acts as a wrapper for xcrun actions.
""",
    },
)

def _shared_attrs():
    """Private attributes on every rule to provide access to bundling tools and other file deps."""
    return {
        "_mac_toolchain": attr.label(
            default = Label("@build_bazel_rules_apple//apple/internal:mac_tools_toolchain"),
            providers = [[AppleMacToolsToolchainInfo]],
        ),
        "_xplat_toolchain": attr.label(
            default = Label("@build_bazel_rules_apple//apple/internal:xplat_tools_toolchain"),
            providers = [[AppleXPlatToolsToolchainInfo]],
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

def _apple_mac_tools_toolchain_impl(ctx):
    return [
        AppleMacToolsToolchainInfo(
            dsym_info_plist_template = ctx.file.dsym_info_plist_template,
            process_and_sign_template = ctx.file.process_and_sign_template,
            resolved_alticonstool = _resolve_tools_for_executable(
                attr_name = "alticonstool",
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
            resolved_environment_plist_tool = _resolve_tools_for_executable(
                attr_name = "environment_plist_tool",
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

apple_mac_tools_toolchain = rule(
    attrs = {
        "alticonstool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to insert alternate icons entries in the app bundle's `Info.plist`.
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
        "environment_plist_tool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to collect data from the development environment to be record into
final bundles.
""",
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
    doc = """Represents an Apple support toolchain for tools that must run on a Mac""",
    implementation = _apple_mac_tools_toolchain_impl,
)

def _apple_xplat_tools_toolchain_impl(ctx):
    return [
        AppleXPlatToolsToolchainInfo(
            resolved_bundletool = _resolve_tools_for_executable(
                attr_name = "bundletool",
                rule_ctx = ctx,
            ),
            resolved_versiontool = _resolve_tools_for_executable(
                attr_name = "versiontool",
                rule_ctx = ctx,
            ),
        ),
        DefaultInfo(),
    ]

apple_xplat_tools_toolchain = rule(
    attrs = {
        "bundletool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to create an Apple bundle by taking a list of files/ZIPs and destination
paths to build the directory structure for those files.
""",
        ),
        "versiontool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool for extracting version info from builds.
""",
        ),
    },
    doc = """Represents an Apple support toolchain for tools that can run on any platform""",
    implementation = _apple_xplat_tools_toolchain_impl,
)

# Define the loadable module that lists the exported symbols in this file.
apple_toolchain_utils = struct(
    shared_attrs = _shared_attrs,
)
