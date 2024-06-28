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

"""Implementation of apple_resource_locales rule."""

load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "new_appleresourcelocalesinfo",
)

visibility("//apple/...")

def _apple_resource_locales_impl(_ctx):
    locales_to_include = []

    # TODO(b/349902843): Add some input verification for locales_to_include to make sure they are
    # somewhat decent.
    for locale in _ctx.attr.locales_to_include:
        if locale == "iw":
            # Apple prefers `he` to `iw` for Hebrew.
            locale = "he"
        elif locale == "no":
            # Apple prefers `nb` to `no` for Norwegian.
            locale = "nb"
        elif locale == "in":
            # Apple prefers `id` to `in` for Indonesian.
            locale = "id"
        else:
            # Replace the separator with an underscore to match lproj conventions.
            locale = locale.replace("-", "_", 1)
        locales_to_include.append(locale)

    return new_appleresourcelocalesinfo(
        locales_to_include = locales_to_include,
    )

apple_resource_locales = rule(
    implementation = _apple_resource_locales_impl,
    attrs = {
        "locales_to_include": attr.string_list(
            doc = """
List of [Unicode Locale Identifier](https://unicode.org/reports/tr35/#Identifiers) strings in
`<language_id>[_<region_subtag>]` format.
""",
        ),
    },
    doc = """
This rule supplies an allow list of [Unicode Locale Identifiers][ULI] in
`<language_id>[{-_}<region_subtag>]` format. Any hyphens `-` will be converted
to underscores `_` matching `.lproj` naming conventions. Resources that are
filtered out by the allow list will not be copied to the final bundle.
""",
)
