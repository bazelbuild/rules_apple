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

"""Implementation of the `app_intents_hint` rule."""

load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsHintInfo",
)

visibility("public")

def _app_intents_hint_impl(ctx):
    return [AppIntentsHintInfo(static_metadata = ctx.attr.static_metadata)]

app_intents_hint = rule(
    doc = """
Rule to declare aspect hints appropriate for controlling App Intents processing for Apple rules.
""",
    attrs = {
        "static_metadata": attr.bool(
            default = False,
            doc = """\
If `True`, the hinted target is expected to only provide "static metadata" for App Intents, which
are explicitly used by the appintentsmetadataprocessor tool to declare a set of App Intents that
will be inherited by a "main" "app_intents" hinted target in the build graph for a given top level
target. This allows for sharing App Intents via swift_library targets without creating an ambiguous
main source of truth for the App Intents metadata.
""",
            mandatory = False,
        ),
    },
    implementation = _app_intents_hint_impl,
)
