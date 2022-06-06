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

"""Rules to generate import-ready frameworks for testing."""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load(
    "@build_bazel_rules_apple//test/testdata/fmwk:generation_support.bzl",
    "generation_support",
)
load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo")
load("@bazel_skylib//lib:dicts.bzl", "dicts")

def _generate_import_framework_impl(ctx):
    actions = ctx.actions
    apple_fragment = ctx.fragments.apple
    label = ctx.label
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    srcs = ctx.files.src
    hdrs = ctx.files.hdrs
    sdk = ctx.attr.sdk
    libtype = ctx.attr.libtype
    architectures = ctx.attr.archs
    minimum_os_version = ctx.attr.minimum_os_version

    swiftmodule = []
    swift_library_files = ctx.files.swift_library

    if swift_library_files and len(architectures) > 1:
        fail("Internal error: Can only generate a Swift " +
             "framework with a single architecture at this time")

    if not swift_library_files:
        # Compile library
        binary = generation_support.compile_binary(
            actions = actions,
            apple_fragment = apple_fragment,
            archs = architectures,
            embed_bitcode = ctx.attr.embed_bitcode,
            embed_debug_info = ctx.attr.embed_debug_info,
            hdrs = hdrs,
            label = label,
            minimum_os_version = minimum_os_version,
            sdk = sdk,
            srcs = srcs,
            xcode_config = xcode_config,
        )

        # Create dynamic or static library
        if libtype == "dynamic":
            library = generation_support.create_dynamic_library(
                actions = actions,
                apple_fragment = apple_fragment,
                archs = architectures,
                binary = binary,
                minimum_os_version = minimum_os_version,
                sdk = sdk,
                xcode_config = xcode_config,
            )
        else:
            library = generation_support.create_static_library(
                actions = actions,
                apple_fragment = apple_fragment,
                binary = binary,
                xcode_config = xcode_config,
            )
    else:
        # Get dylib and swiftmodule files from swift_library target
        library = None
        for file in swift_library_files:
            if file.extension == "a":
                library = file
                continue
            if file.extension == "swiftmodule":
                architecture = architectures[0]
                swiftmodule_file = actions.declare_file(architecture + ".swiftmodule")
                actions.symlink(output = swiftmodule_file, target_file = file)
                swiftmodule.append(swiftmodule_file)
                continue

    # Create (dynamic) framework bundle
    framework_files = generation_support.create_framework(
        actions = actions,
        bundle_name = label.name,
        library = library,
        headers = hdrs,
        swiftmodule = swiftmodule,
    )

    return [
        DefaultInfo(files = depset(framework_files)),
    ]

generate_import_framework = rule(
    implementation = _generate_import_framework_impl,
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "archs": attr.string_list(
            allow_empty = False,
            doc = "A list of architectures this framework will be generated for.",
        ),
        "sdk": attr.string(
            doc = """
Determines what SDK the framework will be built under.
""",
        ),
        "minimum_os_version": attr.string(
            doc = """
Minimum version of the OS corresponding to the SDK that this binary will support.
""",
        ),
        "src": attr.label(
            allow_single_file = True,
            default = Label(
                "@build_bazel_rules_apple//test/testdata/fmwk:objc_source",
            ),
            doc = "Source file for the generated framework.",
        ),
        "hdrs": attr.label(
            allow_files = True,
            default = Label(
                "@build_bazel_rules_apple//test/testdata/fmwk:objc_headers",
            ),
            doc = "Header files for the generated framework.",
        ),
        "swift_library": attr.label(
            allow_files = True,
            doc = "Label for a Swift library target to source archive and swiftmodule files from.",
            providers = [SwiftInfo],
        ),
        "libtype": attr.string(
            values = ["dynamic", "static"],
            doc = """
Possible values are `dynamic` or `static`.
Determines if the framework will be built as a dynamic framework or a static framework.
""",
        ),
        "embed_bitcode": attr.bool(
            default = False,
            doc = """
Set to `True` to generate and embed bitcode in the final framework binary.
""",
        ),
        "embed_debug_info": attr.bool(
            default = False,
            doc = """
Set to `True` to generate and embed debug information in the framework
binary.
""",
        ),
    }),
    fragments = ["apple"],
    doc = """
Generates an imported dynamic framework for testing.

Provides:
  A dynamic framework target that can be referenced through an apple_*_framework_import rule.
""",
)
