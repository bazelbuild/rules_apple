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

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_feature_allowlist_info.bzl",
    "AppleFeatureAllowlistInfo",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

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
        "bundletool_mac": """\
The files_to_run for a tool to create an Apple bundle that is expected to always run on a Mac.
""",
        "clangrttool": """\
The files_to_run for a tool to find all Clang runtime libs linked to a
binary.
""",
        "codesigningtool": """\
The files_to_run for a tool to select the appropriate signing identity
for Apple apps and Apple executable bundles.
""",
        "dossier_codesigningtool": """\
The files_to_run for a tool to generate codesigning dossiers.
""",
        "environment_plist_tool": """\
The files_to_run for a tool for collecting dev environment values.
""",
        "feature_allowlists": """\
A list of `AppleFeatureAllowlistInfo` providers that allow or prohibit packages
from requesting or disabling features.
""",
        "imported_dynamic_framework_processor": """\
The files_to_run for a tool to process an imported dynamic framework
such that the given framework only contains the same slices as the app binary, every file belonging
to the dynamic framework is copied to a temporary location, and the dynamic framework is codesigned
and zipped as a cacheable artifact.
""",
        "plisttool": """\
The files_to_run for a tool to perform plist operations such as variable
substitution, merging, and conversion of plist files to binary format.
""",
        "provisioning_profile_tool": """\
The files_to_run for a tool that extracts entitlements from a
provisioning profile.
""",
        "signature_tool": """\
The files_to_run for a tool that extracts signatures XML from an artifact.
""",
        "swift_stdlib_tool": """\
The files_to_run for a tool that copies and lipos Swift stdlibs required
for the target to run.
""",
        "xcframework_processor_tool": """\
The files_to_run for a tool that extracts and copies an XCFramework
library for a target triplet.
""",
        "xctoolrunner_alternative": """\
The files_to_run for an alternative tool that acts as a wrapper for xcrun actions.
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
        "build_settings": """\
A `struct` containing custom build settings values, where fields are the name of the build setting
target name and values are retrieved from the BuildSettingInfo provider for each label provided.

e.g. apple_xplat_tools_toolchaininfo.build_settings.signing_certificate_name
""",
        "bundletool": """\
A tool to create an Apple bundle by taking a list of
files/ZIPs and destinations paths to build the directory structure for those files.
""",
        "feature_allowlists": """\
A list of `AppleFeatureAllowlistInfo` providers that allow or prohibit packages
from requesting or disabling features.
""",
        "plisttool": """\
The files_to_run for a tool to perform plist operations such as variable
substitution, merging, and conversion of plist files to binary format.
""",
        "versiontool": """\
A tool that acts as a wrapper for xcrun actions.
""",
    },
)

def _apple_mac_tools_toolchain_impl(ctx):
    apple_mac_tools_info = AppleMacToolsToolchainInfo(
        bundletool_mac = ctx.attr.bundletool_mac.files_to_run,
        clangrttool = ctx.attr.clangrttool.files_to_run,
        codesigningtool = ctx.attr.codesigningtool.files_to_run,
        dossier_codesigningtool = ctx.attr.dossier_codesigningtool.files_to_run,
        dsym_info_plist_template = ctx.file.dsym_info_plist_template,
        environment_plist_tool = ctx.attr.environment_plist_tool.files_to_run,
        feature_allowlists = [target[AppleFeatureAllowlistInfo] for target in ctx.attr.feature_allowlists],
        imported_dynamic_framework_processor = ctx.attr.imported_dynamic_framework_processor.files_to_run,
        plisttool = ctx.attr.plisttool.files_to_run,
        process_and_sign_template = ctx.file.process_and_sign_template,
        provisioning_profile_tool = ctx.attr.provisioning_profile_tool.files_to_run,
        signature_tool = ctx.attr.signature_tool.files_to_run,
        swift_stdlib_tool = ctx.attr.swift_stdlib_tool.files_to_run,
        xcframework_processor_tool = ctx.attr.xcframework_processor_tool.files_to_run,
        xctoolrunner_alternative = ctx.attr.xctoolrunner_alternative.files_to_run,
    )
    return [
        platform_common.ToolchainInfo(mac_tools_info = apple_mac_tools_info),
        DefaultInfo(),
    ]

apple_mac_tools_toolchain = rule(
    attrs = {
        "bundletool_mac": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to create an Apple bundle that is expected to always run on a Mac.
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
            cfg = "target",
            allow_single_file = True,
            doc = "A `File` referencing a plist template for dSYM bundles.",
        ),
        "environment_plist_tool": attr.label(
            cfg = "target",
            executable = True,
            doc = """
A `File` referencing a tool to collect data from the development environment to be record into
final bundles.
""",
        ),
        "feature_allowlists": attr.label_list(
            doc = """\
A list of `apple_feature_allowlist` targets that allow or prohibit packages from
requesting or disabling features.
""",
            providers = [[AppleFeatureAllowlistInfo]],
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
        "signature_tool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool that extracts signatures XML from an artifact.
""",
        ),
        "swift_stdlib_tool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool that copies and lipos Swift stdlibs required for the target to run.
""",
        ),
        "xcframework_processor_tool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool that extracts and copies an XCFramework library for a given target
triplet.
""",
        ),
        "xctoolrunner_alternative": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing an alternative tool that acts as a wrapper for xcrun actions.
""",
        ),
    },
    doc = """Represents an Apple support toolchain for tools that must run on a Mac""",
    implementation = _apple_mac_tools_toolchain_impl,
)

APPLE_MAC_TOOLCHAIN_TYPE = "@build_bazel_rules_apple//apple/internal/toolchains:mac_tools_toolchain_type"
APPLE_XPLAT_TOOLCHAIN_TYPE = "@build_bazel_rules_apple//apple/internal/toolchains:apple_xplat_toolchain_type"

APPLE_MAC_EXEC_GROUP = "_mac_tool_group"
APPLE_XPLAT_EXEC_GROUP = "_xplat_tool_group"

def _apple_xplat_tools_toolchain_impl(ctx):
    xplat_info = AppleXPlatToolsToolchainInfo(
        build_settings = struct(
            **{
                build_setting.label.name: build_setting[BuildSettingInfo].value
                for build_setting in ctx.attr.build_settings
            }
        ),
        bundletool = ctx.attr.bundletool,
        feature_allowlists = [target[AppleFeatureAllowlistInfo] for target in ctx.attr.feature_allowlists],
        plisttool = ctx.attr.plisttool.files_to_run,
        versiontool = ctx.attr.versiontool,
    )

    return [
        platform_common.ToolchainInfo(xplat_tools_info = xplat_info),
        DefaultInfo(),
    ]

apple_xplat_tools_toolchain = rule(
    attrs = {
        "build_settings": attr.label_list(
            providers = [BuildSettingInfo],
            mandatory = True,
            doc = """
List of `Label`s referencing custom build settings for all Apple rules.
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
        "feature_allowlists": attr.label_list(
            doc = """\
A list of `apple_feature_allowlist` targets that allow or prohibit packages from
requesting or disabling features.
""",
            providers = [[AppleFeatureAllowlistInfo]],
        ),
        "plisttool": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A `File` referencing a tool to perform plist operations such as variable substitution, merging, and
conversion of plist files to binary format.
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

def _get_mac_toolchain(ctx):
    return ctx.exec_groups[APPLE_MAC_EXEC_GROUP].toolchains[APPLE_MAC_TOOLCHAIN_TYPE].mac_tools_info

def _get_mac_exec_group(_ctx):
    return APPLE_MAC_EXEC_GROUP

def _get_xplat_toolchain(ctx):
    return ctx.exec_groups[APPLE_XPLAT_EXEC_GROUP].toolchains[APPLE_XPLAT_TOOLCHAIN_TYPE].xplat_tools_info

def _get_xplat_exec_group(_ctx):
    return APPLE_XPLAT_EXEC_GROUP

def _use_apple_exec_group_toolchain():
    """
    Helper to depend on the All Apple toolchains through exec_groups.

    Usage:
    ```
    my_rule = rule(
        exec_groups = {other exec_groups} |
                      apple_toolchain_utils.use_apple_exec_group_toolchain(),
    )
    ```
    Returns:
      A dict that can be used as the value for `rule.exec_groups`.
    """
    groups = {
        APPLE_XPLAT_EXEC_GROUP: exec_group(
            toolchains = [config_common.toolchain_type(APPLE_XPLAT_TOOLCHAIN_TYPE)],
        ),
        APPLE_MAC_EXEC_GROUP: exec_group(
            exec_compatible_with = ["@platforms//os:macos"],
            toolchains = [config_common.toolchain_type(APPLE_MAC_TOOLCHAIN_TYPE)],
        ),
    }

    return groups

# Define the loadable module that lists the exported symbols in this file.
apple_toolchain_utils = struct(
    get_mac_toolchain = _get_mac_toolchain,
    get_mac_exec_group = _get_mac_exec_group,
    get_xplat_toolchain = _get_xplat_toolchain,
    get_xplat_exec_group = _get_xplat_exec_group,
    use_apple_exec_group_toolchain = _use_apple_exec_group_toolchain,
)
