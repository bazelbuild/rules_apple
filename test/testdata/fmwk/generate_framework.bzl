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
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")

def _generate_import_framework_impl(ctx):
    # The script has to run on a Mac, so just like the issues in the rule's
    # tools, a py_binary doesn't always work, it is a plain file that gets
    # invoked and has a shebang to force it to run under python3.
    if len(ctx.files._generate_framework_script) != 1:
        fail("Internal Error: Didn't get a single file for the script")

    args = ctx.actions.args()
    args.add("--name", ctx.label.name)
    args.add("--sdk", ctx.attr.sdk)
    args.add("--minimum_os_version", ctx.attr.minimum_os_version)
    args.add("--libtype", ctx.attr.libtype)
    if ctx.attr.embed_bitcode:
        args.add("--embed_bitcode")
    if ctx.attr.embed_debug_info:
        args.add("--embed_debug_info")
    for arch in ctx.attr.archs:
        args.add("--arch", arch)

    framework_dir_name = "{}.framework".format(ctx.label.name)
    binary_file = ctx.actions.declare_file(paths.join(framework_dir_name, ctx.label.name))
    args.add("--framework_path", binary_file.dirname)

    input_files = []
    output_files = [binary_file]

    for source_file in ctx.attr.src.files.to_list():
        args.add("--source_file", source_file)
        input_files.append(source_file)

    for header_file in ctx.attr.hdrs.files.to_list():
        args.add("--header_file", header_file)
        input_files.append(header_file)
        output_files.append(ctx.actions.declare_file(paths.join(
            framework_dir_name,
            "Headers",
            header_file.basename,
        )))

    # Special outputs to handle the generated text files.
    output_files.extend([
        ctx.actions.declare_file(paths.join(framework_dir_name, "Headers", ctx.label.name + ".h")),
        ctx.actions.declare_file(paths.join(framework_dir_name, "Info.plist")),
        ctx.actions.declare_file(paths.join(framework_dir_name, "Modules/module.modulemap")),
    ])

    apple_support.run(
        ctx,
        inputs = input_files,
        outputs = output_files,
        executable = ctx.files._generate_framework_script[0],
        tools = ctx.files._generate_framework_script,
        arguments = [args],
        mnemonic = "GenerateImportedAppleFramework",
    )

    return [
        DefaultInfo(files = depset(output_files)),
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
        "_generate_framework_script": attr.label(
            cfg = "exec",
            allow_files = True,
            default = Label(
                "@build_bazel_rules_apple//test/testdata/fmwk:generate_framework.py",
            ),
        ),
    }),
    fragments = ["apple"],
    doc = """
Generates an imported dynamic framework for testing.

Provides:
  A dynamic framework target that can be referenced through an apple_*_framework_import rule.
""",
)
