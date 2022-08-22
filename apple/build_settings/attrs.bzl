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

"""Apple build settings attributes to be added to rules that read configuration settings."""

# List of all registered build settings at `rules_apple/apple/build_settings/BUILD`.
_BUILD_SETTINGS = [
    "parse_xcframework_info_plist",
]

# Build settings label template including label prefix.
_BUILD_SETTING_LABEL_TEMPLATE = "@build_bazel_rules_apple//apple/build_settings:{name}"

build_settings = struct(
    # A list of labels is shared for apple_verification_test transition to allow
    # tests set these custom build settings.
    all_labels = [
        _BUILD_SETTING_LABEL_TEMPLATE.format(
            name = build_setting,
        )
        for build_setting in _BUILD_SETTINGS
    ],
    # The following struct fields are dynamically generated using each build
    # setting. Each build setting struct will have the following format:
    #
    #   struct(
    #       build_setting_a = struct(
    #           label = "rules_apple/apple/build_settings:build_setting_a"
    #           attr = {
    #               "_build_setting_a": attr.label(
    #                   default = "rules_apple/apple/build_settings:build_setting_a",
    #               )
    #           }
    #       )
    #   )
    **{
        build_setting: struct(
            label = _BUILD_SETTING_LABEL_TEMPLATE.format(
                name = build_setting,
            ),
            attr = {
                "_{build_setting_name}".format(
                    build_setting_name = build_setting,
                ): attr.label(
                    default = _BUILD_SETTING_LABEL_TEMPLATE.format(
                        name = build_setting,
                    ),
                ),
            },
        )
        for build_setting in _BUILD_SETTINGS
    }
)
