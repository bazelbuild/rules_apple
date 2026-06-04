# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Test-only CcInfo dependency that exposes a validation artifact."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

visibility("//test/starlark_tests/...")

def _validation_artifact_dep_impl(ctx):
    header = ctx.actions.declare_file("%s.h" % ctx.label.name)
    ctx.actions.write(
        output = header,
        content = "#pragma once\n",
    )

    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        language = "objc",
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    (compilation_context, _compilation_outputs) = cc_common.compile(
        actions = ctx.actions,
        name = ctx.label.name,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        public_hdrs = [header],
        language = "objc",
    )

    return [
        CcInfo(
            compilation_context = compilation_context,
        ),
    ]

validation_artifact_dep = rule(
    implementation = _validation_artifact_dep_impl,
    attrs = {
        "_cc_toolchain": attr.label(default = "@rules_cc//cc:current_cc_toolchain"),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
