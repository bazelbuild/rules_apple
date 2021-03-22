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

"""Starlark test rules for linkmap generation."""

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

def _linkmap_test_impl(ctx):
    """Implementation of the linkmap_test rule."""
    env = analysistest.begin(ctx)
    target_under_test = ctx.attr.target_under_test[0]

    platform_type = target_under_test[AppleBundleInfo].platform_type
    if platform_type == "watchos":
        architecture = "i386"
    else:
        architecture = "x86_64"

    outputs = {
        x.short_path: None
        for x in target_under_test[DefaultInfo].files.to_list()
    }

    package = target_under_test.label.package
    target_name = target_under_test.label.name
    linkmap_name = "{}_{}.linkmap".format(target_name, architecture)

    expected_linkmap = paths.join(package, linkmap_name)

    workspace = target_under_test.label.workspace_name
    if workspace != "":
        expected_linkmap = paths.join("..", workspace, expected_linkmap)

    asserts.true(
        env,
        expected_linkmap in outputs,
        msg = "Expected\n\n{0}\n\nto be built. Contents were:\n\n{1}\n\n".format(
            expected_linkmap,
            "\n".join(outputs.keys()),
        ),
    )

    return analysistest.end(env)

linkmap_test = analysistest.make(
    _linkmap_test_impl,
    config_settings = {
        "//command_line_option:objc_generate_linkmap": "true",
    },
)
