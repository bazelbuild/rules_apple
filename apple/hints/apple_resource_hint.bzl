# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Implementation of the `apple_resource_hint` rule."""

load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_hint_info.bzl",
    "AppleResourceHintInfo",
)

visibility("public")

def _apple_resource_hint_impl(ctx):
    return [
        AppleResourceHintInfo(needs_swift_srcs = ctx.attr.needs_swift_srcs),
    ]

apple_resource_hint = rule(
    attrs = {
        "needs_swift_srcs": attr.bool(
            default = False,
            doc = """\
If `True`, the hinted target will indicate that swift_library sources are to be passed down to
Apple resource processing. This is needed for resources that declare Swift source code dependencies
like rkassets from Swift packages that declare Swift sources.
""",
            mandatory = False,
        ),
    },
    doc = """
Rule to declare aspect hints appropriate for controlling resource processing for Apple BUILD rules.
""",
    implementation = _apple_resource_hint_impl,
)
