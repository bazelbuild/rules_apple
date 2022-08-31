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

"""apple_static_library Starlark implementation"""

load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)

def _apple_static_library_impl(ctx):
    # Validation of the platform type and minimum version OS currently happen in
    # `transition_support.apple_platform_transition`, either implicitly through native
    # `dotted_version` or explicitly through `fail` on an unrecognized platform type value.

    link_result = linking_support.register_static_library_linking_action(ctx = ctx)

    files_to_build = [link_result.library]
    runfiles = ctx.runfiles(
        files = files_to_build,
        collect_default = True,
        collect_data = True,
    )

    return [
        DefaultInfo(files = depset(files_to_build), runfiles = runfiles),
        AppleBinaryInfo(
            binary = link_result.library,
            infoplist = None,
        ),
        link_result.objc,
        link_result.output_groups,
    ]

apple_static_library = rule(
    implementation = _apple_static_library_impl,
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        rule_factory.common_bazel_attributes.link_multi_arch_static_library_attrs(
            cfg = transition_support.apple_platform_split_transition,
        ),
        {
            "additional_linker_inputs": attr.label_list(
                # Flag required for compile_one_dependency
                flags = ["DIRECT_COMPILE_TIME_INPUT"],
                allow_files = True,
                doc = """
A list of input files to be passed to the linker.
""",
            ),
            "avoid_deps": attr.label_list(
                cfg = transition_support.apple_platform_split_transition,
                providers = [CcInfo],
                # Flag required for compile_one_dependency
                flags = ["DIRECT_COMPILE_TIME_INPUT"],
                doc = """
A list of library targets on which this framework depends in order to compile, but the transitive
closure of which will not be linked into the framework's binary.
""",
            ),
            "data": attr.label_list(
                allow_files = True,
                doc = """
Files to be made available to the library archive upon execution.
""",
            ),
            "deps": attr.label_list(
                cfg = transition_support.apple_platform_split_transition,
                providers = [CcInfo],
                # Flag required for compile_one_dependency
                flags = ["DIRECT_COMPILE_TIME_INPUT"],
                doc = """
A list of dependencies targets that will be linked into this target's binary. Any resources, such as
asset catalogs, that are referenced by those targets will also be transitively included in the final
bundle.
""",
            ),
            "linkopts": attr.string_list(
                doc = """
A list of strings representing extra flags that should be passed to the linker.
""",
            ),
            "minimum_os_version": attr.string(
                mandatory = True,
                doc = """
A required string indicating the minimum OS version supported by the target, represented as a
dotted version number (for example, "9.0").
""",
            ),
            "platform_type": attr.string(
                mandatory = True,
                doc = """
The target Apple platform for which to create a binary. This dictates which SDK
is used for compilation/linking and which flag is used to determine the
architectures to target. For example, if `ios` is specified, then the output
binaries/libraries will be created combining all architectures specified by
`--ios_multi_cpus`. Options are:

*   `ios`: architectures gathered from `--ios_multi_cpus`.
*   `macos`: architectures gathered from `--macos_cpus`.
*   `tvos`: architectures gathered from `--tvos_cpus`.
*   `watchos`: architectures gathered from `--watchos_cpus`.
""",
            ),
            "sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to link with (e.g., `AddressBook`, `QuartzCore`).
`UIKit` and `Foundation` are always included, even if this attribute is
provided and does not list them.

This attribute is discouraged; in general, targets should list system
framework dependencies in the library targets where that framework is used,
not in the top-level bundle.
""",
            ),
            "sdk_dylibs": attr.string_list(
                doc = """
Names of SDK `.dylib` libraries to link with (e.g., `libz` or `libarchive`).
`libc++` is included automatically if the binary has any C++ or Objective-C++
sources in its dependency tree. When linking a binary, all libraries named in
that binary's transitive dependency graph are used.
""",
            ),
            "weak_sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to weakly link with (e.g., `MediaAccessibility`).
Unlike regularly linked SDK frameworks, symbols from weakly linked
frameworks do not cause the binary to fail to load if they are not present in
the version of the framework available at runtime.

This attribute is discouraged; in general, targets should list system
framework dependencies in the library targets where that framework is used,
not in the top-level bundle.
""",
            ),
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
    ),
    outputs = {
        "lipo_archive": "%{name}_lipo.a",
    },
    fragments = ["objc", "apple", "cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    incompatible_use_toolchain_transition = True,
)
