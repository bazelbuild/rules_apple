# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""List of Bazel's rules_apple build settings."""

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)

visibility([
    "//apple/...",
    "//test/...",
])

_BUILD_SETTINGS_PACKAGE = "@build_bazel_rules_apple//apple/build_settings"

# List of all registered build settings with command line flags at
# `rules_apple/apple/build_settings/BUILD`.
build_flags = {
    "force_app_intents_linked_binary": struct(
        doc = """
Forces a linked binary to be generated as an input to the tool that generates app intents metadata
bundles.

This is no longer required for Xcode 15.3 and later, as the app intents metadata processor considers
its source of truth to be in Swift const value files instead of a linked binary. However, this is
still a required input of the app intents metadata processor xcodebuild action, and subsequent
versions of Xcode still pass a linked binary as a required build input even though it appears to be
redundant (FB347041279).
""",
        default = False,
    ),
    # TODO(b/252873771): Clean up all usages of --ios_signing_cert_name and replace them with this
    # new custom build setting.
    "signing_certificate_name": struct(
        doc = """
Declare a code signing identity, to be used in all code signing flows related to the rules.
""",
        default = "",
    ),
    # TODO(b/266604130): Migrate users from tree artifacts outputs define flag to build setting.
    "use_tree_artifacts_outputs": struct(
        doc = """
Enables Bazel's tree artifacts for Apple bundle rules (instead of archives).
""",
        default = False,
    ),
}

# List of all registered build settings without command line flags at
# `rules_apple/apple/build_settings/BUILD`.
build_settings = {
    "device_families": struct(
        doc = """
Used by the transitions to pass down the required device families for processing resources. For most
Apple platforms these will correspond to defaults, but for iOS, users will either indicate "iphone",
"iphone" and "ipad", or (rarely) exclusively "ipad".

This list should remain sorted where possible to foster sharing the results of processed resources,
as no Apple tool should depend on the ordering of this list.
""",
        default = [],
        type = "string_list",
    ),
    "enable_wip_features": struct(
        doc = """
Enables functionality that is still a work in progress, with interfaces and output that can change
at any time, that is only ready for automated testing now.

This could indicate functionality intended for a future release of the Apple BUILD rules, or
functionality that is never intended to be production-ready but is required of automated testing.
""",
        default = False,
    ),
}

_all_build_settings = dicts.add(build_settings, build_flags)

build_settings_labels = struct(
    all_labels = [
        "{package}:{target_name}".format(
            package = _BUILD_SETTINGS_PACKAGE,
            target_name = build_setting_name,
        )
        for build_setting_name in _all_build_settings
    ],
    **{
        build_setting_name: "{package}:{target_name}".format(
            package = _BUILD_SETTINGS_PACKAGE,
            target_name = build_setting_name,
        )
        for build_setting_name in _all_build_settings
    }
)
