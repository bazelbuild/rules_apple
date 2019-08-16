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

    platform_type = target_under_test[AppleBundleInfo].platform_type
    if platform_type == "watchos":
        architecture = "i386"
    else:
        architecture = "x86_64"

    outputs = {
        x.short_path: None
        for x in target_under_test[OutputGroupInfo]["dsyms"].to_list()
    }

    package = target_under_test.label.package

    expected_infoplists = [
        "{0}/{1}.dSYM/Contents/Info.plist".format(package, x)
        for x in ctx.attr.expected_dsyms
    ]

    expected_binaries = [
        "{0}/{1}.dSYM/Contents/Resources/DWARF/{2}_{3}".format(
            package,
            x,
            paths.split_extension(x)[0],
            architecture,
        )
        for x in ctx.attr.expected_dsyms
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
        "expected_dsyms": attr.string_list(
            mandatory = True,
            doc = """
List of bundle names in the format <bundle_name>.<bundle_extension> to verify that dSYMs bundles are
created for them.
""",
        ),
    },
    config_settings = {
        "//command_line_option:apple_generate_dsym": "true",
    },
)
