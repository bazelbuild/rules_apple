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

"""Starlark test rules for debug symbols."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
    "AppleBundleInfo",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
)

def _dsyms_test_impl(ctx):
    """Implementation of the dsyms_test rule."""
    env = analysistest.begin(ctx)
    target_under_test = ctx.attr.target_under_test[0]
    architectures = ctx.attr.architectures

    if not architectures:
        if AppleBundleInfo in target_under_test:
            platform_type = target_under_test[AppleBundleInfo].platform_type
            if platform_type == "watchos":
                architectures = ["i386"]
            else:
                architectures = ["x86_64"]
        elif AppleBinaryInfo in target_under_test:
            # AppleBinaryInfo does not supply a platform_type. In this case, assume x86_64.
            architectures = ["x86_64"]
        else:
            fail(("Target %s does not provide AppleBundleInfo or AppleBinaryInfo") %
                 target_under_test.label)

    outputs = {
        x.short_path: None
        for x in target_under_test[OutputGroupInfo]["dsyms"].to_list()
    }

    package = target_under_test.label.package

    expected_infoplists = [
        "{0}/{1}.dSYM/Contents/Info.plist".format(package, x)
        for x in ctx.attr.expected_dsyms
    ]

    expected_binaries = []
    expected_binaries.extend([
        "{0}/{1}.dSYM/Contents/Resources/DWARF/{2}".format(
            package,
            x,
            paths.split_extension(x)[0],
        )
        for x in ctx.attr.expected_dsyms
    ])

    workspace = target_under_test.label.workspace_name
    if workspace != "":
        expected_infoplists = [
            paths.join("..", workspace, x)
            for x in expected_infoplists
        ]
        expected_binaries = [
            paths.join("..", workspace, x)
            for x in expected_binaries
        ]

    for expected in expected_infoplists + expected_binaries:
        asserts.true(
            env,
            expected in outputs,
            msg = "Expected\n\n{0}\n\nto be built. Contents were:\n\n{1}\n\n".format(
                expected,
                "\n".join(outputs.keys()),
            ),
        )

    return analysistest.end(env)

dsyms_test = analysistest.make(
    _dsyms_test_impl,
    attrs = {
        "architectures": attr.string_list(
            mandatory = False,
            default = [],
            doc = """
List of architectures to verify for the given dSYM bundles as provided. Defaults to x86_64 for all
platforms except for watchOS, which has a default of i386.
""",
        ),
        "expected_dsyms": attr.string_list(
            mandatory = True,
            doc = """
List of bundle names in the format <bundle_name>.<bundle_extension> to verify that dSYMs bundles are
created for them.
""",
        ),
        "expected_binaries": attr.string_list(
            mandatory = False,
            doc = """
List of expected binaries in dSYMs bundles in the format
<bundle_name>.<bundle_extension>/Contents/Resources/DWARF/<executable_name> to
verify that dSYMs binaries are created with the correct names.
""",
        ),
    },
    config_settings = {
        "//command_line_option:apple_generate_dsym": "true",
    },
)
