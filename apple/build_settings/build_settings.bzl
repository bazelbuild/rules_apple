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

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

_BUILD_SETTINGS_PACKAGE = "@build_bazel_rules_apple//apple/build_settings"

# List of all registered build settings with command line flags at
# `rules_apple/apple/build_settings/BUILD`.
build_flags = {
    "force_plisttool_on_mac": struct(
        doc = """
Indicates that `plisttool` should be run on the Mac, rather than on Linux. This is an emergency
valve so the default can be flipped if we ever have a problem with the Apple
swift-corelibs-foundation plutil binary on Linux, and should not be used or set by anyone except
Apple BUILD rule maintainers.
""",
        default = False,
    ),
    "signing_certificate_name": struct(
        doc = """
Declare a code signing identity, to be used in all code signing flows related to the rules.
""",
        default = "",
    ),
    # TODO(b/448648527): Remove this build flag once the new mac bundletool is deemed sufficient for
    # all users.
    "use_mac_tree_artifact_bundletool": struct(
        doc = """
Indicates that the new mac tree artifact bundletool should be used, rather than the legacy
experimental tree artifact bundletool when generating tree artifact bundles. This setting has no
effect on non-tree artifact bundles (i.e. "zipped" bundle archives). This is an emergency valve so
the default can be flipped if we ever have a problem with the new mac bundletool, and should not be
used or set by anyone except Apple BUILD rule maintainers.
""",
        default = True,
    ),
    # TODO(b/266604130): Migrate users from the tree artifact output --define flag to this flag.
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
    "building_apple_bundle": struct(
        doc = """
This is set to True if the target configuration is building a bundled Apple
binary. For example, an `ios_application`, `watchos_extension`, or
`macos_unit_test`, but *not* a `macos_command_line_application`.

This can be tested by clients to provide conditional behavior depending on
whether or not a library is being built as a dependency of a bundled executable.
""",
        default = False,
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
    "link_watchos_2_app_extension": struct(
        doc = """
Enables linking of a watchOS 2 app extension, rather than a standard watchOS extension.

These require extra options to be set, and must be embedded within a watchOS 2 app bundle.
""",
        default = False,
    ),
}

_local_build_settings_packages_by_name = {k: _BUILD_SETTINGS_PACKAGE for k in build_settings.keys()}
_local_build_flags_packages_by_name = {k: _BUILD_SETTINGS_PACKAGE for k in build_flags.keys()}
_extra_build_config_packages_by_name = {
}

_all_starlark_build_config_packages_by_name = (
    _local_build_settings_packages_by_name |
    _local_build_flags_packages_by_name |
    _extra_build_config_packages_by_name
)

build_settings_labels = struct(
    all_labels = [
        "{package}:{target_name}".format(
            package = package,
            target_name = target_name,
        )
        for target_name, package in _all_starlark_build_config_packages_by_name.items()
    ],
    **{
        target_name: "{package}:{target_name}".format(
            package = package,
            target_name = target_name,
        )
        for target_name, package in _all_starlark_build_config_packages_by_name.items()
    }
)
