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

"""Test-only rule for generating unencoded provisioning profile plists."""

visibility("//test/testdata/provisioning/...")

_PLIST_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!--
    This is a fake provisioning profile used for integration tests. These tests
    force the identity to be "-", so these files will not be read to detect the
    identity, but can be used to validate that they are embedded correctly.
-->
<plist version="1.0">
<dict>
    <key>AppIDName</key>
    <string>Wildcard</string>
    <key>ApplicationIdentifierPrefix</key>
    <array>
    <string>{team_identifier}</string>
    </array>
    <key>CreationDate</key>
    <date>2017-01-04T13:44:01Z</date>
    <key>Platform</key>
    <array>
{platform_entries}
    </array>
    <key>DeveloperCertificates</key>
    <array>
        <data>NOT_A_VALID_CERTIFICATE</data>
    </array>
    <key>Entitlements</key>
    <dict>
{entitlement_entries}
    </dict>
    <key>ExpirationDate</key>
    <date>2117-01-04T13:44:01Z</date>
    <key>Name</key>
    <string>{profile_name}</string>
    <key>ProvisionedDevices</key>
    <array>
    </array>
    <key>TeamIdentifier</key>
    <array>
        <string>{team_identifier}</string>
    </array>
    <key>TeamName</key>
    <string>Bazel Rules Apple</string>
    <key>TimeToLive</key>
    <integer>36500</integer>
    <key>UUID</key>
    <string>eaf3d44a-f20e-11e6-bc64-92361f002671</string>
    <key>Version</key>
    <integer>1</integer>
</dict>
</plist>
"""

_PLATFORM_TYPE_TO_PLATFORMS = {
    "ios": ["iOS"],
    "macos": ["OSX"],
    "tvos": ["tvOS"],
    "visionos": ["xrOS", "visionOS"],
    "watchos": ["WatchOS"],
}

def _unencoded_provisioning_profile_impl(ctx):
    """Implementation of the `unencoded_provisioning_profile` rule."""
    output = ctx.actions.declare_file(ctx.label.name)

    platforms = _PLATFORM_TYPE_TO_PLATFORMS[ctx.attr.platform_type]
    platform_entries = "\n".join([
        "        <string>{}</string>".format(platform)
        for platform in platforms
    ])

    entitlement_lines = []
    for key, values in ctx.attr.entitlements_string_lists.items():
        entitlement_lines.append("        <key>{}</key>".format(key))
        entitlement_lines.append("        <array>")
        for value in values:
            entitlement_lines.append("            <string>{}</string>".format(value))
        entitlement_lines.append("        </array>")

    if ctx.attr.get_task_allow == "true":
        entitlement_lines.append("        <key>get-task-allow</key>")
        entitlement_lines.append("        <true/>")
    elif ctx.attr.get_task_allow == "false":
        entitlement_lines.append("        <key>get-task-allow</key>")
        entitlement_lines.append("        <false/>")

    app_id_key = (
        "com.apple.application-identifier" if ctx.attr.platform_type == "macos" else "application-identifier"
    )
    entitlement_lines.extend([
        "        <key>{}</key>".format(app_id_key),
        "        <string>{}</string>".format(ctx.attr.application_identifier),
        "        <key>com.apple.developer.team-identifier</key>",
        "        <string>{}</string>".format(ctx.attr.team_identifier),
    ])

    content = _PLIST_TEMPLATE.format(
        entitlement_entries = "\n".join(entitlement_lines),
        platform_entries = platform_entries,
        profile_name = ctx.attr.profile_name,
        team_identifier = ctx.attr.team_identifier,
    )
    ctx.actions.write(
        output = output,
        content = content,
    )
    return DefaultInfo(files = depset([output]))

unencoded_provisioning_profile = rule(
    implementation = _unencoded_provisioning_profile_impl,
    attrs = {
        "application_identifier": attr.string(
            default = "FOOBARBAZ1.*",
            doc = "The application identifier value in the profile's Entitlements.",
        ),
        "entitlements_string_lists": attr.string_list_dict(
            default = {},
            doc = "Additional array-of-string entitlements to include in the profile.",
        ),
        "get_task_allow": attr.string(
            default = "true",
            values = ["true", "false", "None"],
            doc = "Whether to include get-task-allow as true, false, or omit it ('None').",
        ),
        "platform_type": attr.string(
            default = "ios",
            values = _PLATFORM_TYPE_TO_PLATFORMS.keys(),
            doc = "The Apple platform_type value for the provisioning profile.",
        ),
        "profile_name": attr.string(
            default = "Integration Testing iOS",
            doc = "The Name value in the provisioning profile.",
        ),
        "team_identifier": attr.string(
            default = "FOOBARBAZ1",
            doc = "The TeamIdentifier value in the provisioning profile.",
        ),
    },
    doc = "Generates an unencoded Apple provisioning profile plist for integration tests.",
)
