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

visibility("@build_bazel_rules_apple//apple/...")

def apple_locale_from_unicode_locale(unicode_locale):
    """Converts a Unicode Locale Identifier to an Apple locale.

    This function converts a [Unicode Locale Identifier](https://unicode.org/reports/tr35/#Identifiers) in
    `<language_id>[{-_}<region_subtag>]` format to Apple's preferred names for
    `lproj` directories.

    Args:
        unicode_locale: [Unicode Locale Identifier](https://unicode.org/reports/tr35/#Identifiers)
            string to convert to an `lproj` directory name.

    Returns:
        A String with the Apple locale name.
    """

    # TODO(b/349902843): Add some input verification for unicode_locale to make sure it is
    # somewhat decent.
    if unicode_locale == "iw":
        # Apple prefers `he` to `iw` for Hebrew.
        return "he"
    elif unicode_locale == "no":
        # Apple prefers `nb` to `no` for Norwegian.
        return "nb"
    elif unicode_locale == "in":
        # Apple prefers `id` to `in` for Indonesian.
        return "id"
    else:
        # Replace the separator with an underscore to match lproj conventions.
        return unicode_locale.replace("-", "_", 1)

def _apple_resource_locales_impl(_ctx):
    ctx_locales = _ctx.attr.locales_to_include
    if _ctx.attr.default_locale not in ctx_locales:
        ctx_locales = [_ctx.attr.default_locale] + ctx_locales
    locales_to_include = [apple_locale_from_unicode_locale(locale) for locale in ctx_locales]
    return new_appleresourcelocalesinfo(
        locales_to_include = locales_to_include,
        default_locale = _ctx.attr.default_locale,
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
        "default_locale": attr.string(
            default = "en",
            doc = """
The locale that should always be included. Sometimes projects explicitly exclude "en" from their
translation console language lists to avoid doing translations at build time. This makes sure that
this locale is always included.
""",
        ),
    },
    doc = """
This rule supplies an allow list of [Unicode Locale Identifiers](https://unicode.org/reports/tr35/#Identifiers) in
`<language_id>[{-_}<region_subtag>]` format. Any hyphens `-` will be converted
to underscores `_` matching `.lproj` naming conventions. Resources that are
filtered out by the allow list will not be copied to the final bundle.
""",
)
