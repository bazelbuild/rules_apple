# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Implementation of the aspect that propagates AppIntentsInfo providers."""

load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsInfo",
)
load("@build_bazel_rules_apple//apple/internal:cc_info_support.bzl", "cc_info_support")

def _app_intents_aspect_impl(target, ctx):
    """Implementation of the swift source files propation aspect."""
    if ctx.rule.kind != "swift_library":
        return []

    sdk_frameworks = cc_info_support.get_sdk_frameworks(deps = [target], include_weak = True)
    if "AppIntents" not in sdk_frameworks.to_list():
        fail(
            "Target '%s' does not depend on the AppIntents SDK framework. " % target.label +
            "Found the following SDK frameworks: %s" % sdk_frameworks.to_list(),
        )

    return [
        AppIntentsInfo(
            swift_source_files = ctx.rule.files.srcs,
        ),
    ]

app_intents_aspect = aspect(
    implementation = _app_intents_aspect_impl,
    doc = "Collects Swift source files from swift_library targets required by AppIntents tooling.",
)
