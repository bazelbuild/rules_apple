# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Rules related to Apple bundle versioning."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleVersionInfo",
)

def _collect_group_names(s):
    """Returns the list of placeholder names found in the given string.

    Placeholders are of the form `{foo}`.

    Args:
      s: The string that potentially contains placeholders.

    Returns:
      A list of placeholder names found in the string, if any.
    """
    names = []
    length = len(s)
    end_index = 0
    for i in range(length):
        # Don't try to capture a placeholder inside another placeholder.
        if i < end_index:
            continue

        ch = s[i]
        if ch == "{":
            end_index = s.find("}", i + 1)
            if end_index != -1:
                names.append(s[(i + 1):end_index])
    return names

def _validate_capture_groups(groups, pattern_dict):
    """Validates the placeholders against the capture groups of the target.

    This ensures that all of the placeholders found in any of the attributes are
    also present in the capture groups dictionary.

    Args:
      groups: A list of placeholders derived from capture groups.
      pattern_dict: A dictionary containing the pattern strings to be validated.
          The keys are the rule attribute name with which the pattern is
          associated, and the values are the patterns (i.e., the attribute
          values).
    """
    for attribute, pattern in pattern_dict.items():
        missing_groups = [
            g
            for g in _collect_group_names(pattern)
            if g not in groups
        ]
        if missing_groups:
            fail("Some groups were not defined in capture_groups: [%s]" %
                 ", ".join(sorted(missing_groups)), attr = attribute)

def _apple_bundle_version_impl(ctx):
    """Implementation of the apple_bundle_version rule."""
    build_label_pattern = ctx.attr.build_label_pattern
    capture_groups = ctx.attr.capture_groups

    if (build_label_pattern and not capture_groups or
        not build_label_pattern and capture_groups):
        fail("If either build_label_pattern or capture_groups is provided, then " +
             "both must be provided.")

    fallback_build_label = ctx.attr.fallback_build_label
    if fallback_build_label and not build_label_pattern:
        fail("If fallback_build_label is provided, then build_label_pattern " +
             "and capture_groups must be provided.")

    patterns_to_validate = {
        "build_version": ctx.attr.build_version,
        "short_version_string": ctx.attr.short_version_string,
    }
    if build_label_pattern:
        patterns_to_validate["build_label_pattern"] = build_label_pattern
    _validate_capture_groups((capture_groups or {}).keys(), patterns_to_validate)

    inputs = []
    optional_options = {}

    # If the build label pattern is needed, then make sure the build info file is
    # included among versiontool's inputs.
    if build_label_pattern:
        inputs.append(ctx.info_file)
        optional_options["build_info_path"] = ctx.info_file.path
        optional_options["build_label_pattern"] = build_label_pattern

    if fallback_build_label:
        optional_options["fallback_build_label"] = fallback_build_label

    bundle_version_file = ctx.actions.declare_file(
        ctx.label.name + ".bundle_version",
    )

    # Write the control file that sends arguments to versiontool.
    control = struct(
        build_version_pattern = ctx.attr.build_version,
        short_version_string_pattern = ctx.attr.short_version_string,
        capture_groups = struct(**ctx.attr.capture_groups),
        **optional_options
    )
    control_file = ctx.actions.declare_file(
        ctx.label.name + ".versiontool-control",
    )
    ctx.actions.write(
        output = control_file,
        content = control.to_json(),
    )
    inputs.append(control_file)

    ctx.actions.run(
        executable = ctx.executable._versiontool,
        arguments = [control_file.path, bundle_version_file.path],
        inputs = inputs,
        outputs = [bundle_version_file],
        mnemonic = "AppleBundleVersion",
    )

    return [
        AppleBundleVersionInfo(version_file = bundle_version_file),
        DefaultInfo(files = depset([bundle_version_file])),
    ]

apple_bundle_version = rule(
    _apple_bundle_version_impl,
    attrs = {
        "build_label_pattern": attr.string(
            mandatory = False,
            doc = """
A pattern that should contain placeholders inside curly braces (e.g.,
`"foo_{version}_bar"`) that is used to parse the build label that is generated
in the build info file with the `--embed_label` option passed to Bazel. Each of
the placeholders is expected to match one of the keys in the `capture_groups`
attribute.
""",
        ),
        "build_version": attr.string(
            mandatory = True,
            doc = """
A string that will be used as the value for the `CFBundleVersion` key in a
depending bundle's Info.plist. If this string contains placeholders, then they
will be replaced by strings captured out of `build_label_pattern`.
""",
        ),
        "capture_groups": attr.string_dict(
            mandatory = False,
            doc = """
A dictionary where each key is the name of a placeholder found in
`build_label_pattern` and the corresponding value is the regular expression that
should match that placeholder. If this attribute is provided, then
`build_label_pattern` must also be provided.
""",
        ),
        "fallback_build_label": attr.string(
            mandatory = False,
            doc = """
A build label to use when the no `--embed_label` was provided on the build. Used
to provide a version that will be used during development.
""",
        ),
        "short_version_string": attr.string(
            mandatory = False,
            doc = """
A string that will be used as the value for the `CFBundleShortVersionString` key
in a depending bundle's Info.plist. If this string contains placeholders, then
they will be replaced by strings captured out of `build_label_pattern`. This
attribute is optional; if it is omitted, then the value of `build_version` will
be used for this key as well.
""",
        ),
        "_versiontool": attr.label(
            cfg = "host",
            default = Label(
                "@build_bazel_rules_apple//tools/versiontool",
            ),
            executable = True,
        ),
    },
    doc = """
Produces a target that contains versioning information for an Apple bundle.

Targets created by this rule do not generate outputs themselves, but instead
should be used in the `version` attribute of an Apple application or extension
bundle target to set the version keys in that bundle's Info.plist file.

Provides:
  AppleBundleVersionInfo: Contains a reference to the JSON file that holds the
      version information for a bundle.
""",
)
