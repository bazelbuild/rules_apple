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

"""Support methods for generating Info.plist values."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_extension_point_info.bzl",
    "AppExtensionPointInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:extension_foundation_info.bzl",
    "ExtensionFoundationInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_actions:exutil.bzl",
    "generate_appextension_plist",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _launch_screen_values(
        *,
        default_launch_screen,
        launch_storyboard,
        platform_prerequisites):
    """Returns a struct indicating what plist values should be added to support launch screens.

    Args:
        default_launch_screen: Bool to indicate if plist values should be set to add a default
            launch screen if no launch_storyboard was defined.
        launch_storyboard: A `File` to be used as a launch screen for the application. Can be
            `None` if there is no launch storyboard defined.
        platform_prerequisites: A `struct` containing information on the platform being targeted.

    Returns:
        A struct with `forced_plists` and `overridable_plists`, which each include lists of structs
        with keys and values identical to the plist keys and values that need be merged into the
        final root Info.plist to declare the launch screen. This format is compatible with plisttool
        merging operations.
    """

    if platform_prerequisites.platform_type not in ("ios", "tvos"):
        fail("""\
Internal error: Attempted to define Info.plist values for a launch storyboard/screen on a platform
where the feature isn't supported.

Please file an issue against the Apple BUILD rules.

Found platform is: {platform_type}
""".format(
            platform_type = platform_prerequisites.platform_type,
        ))

    forced_plist = None
    overridable_plist = None

    if launch_storyboard:
        short_name = paths.split_extension(launch_storyboard.basename)[0]
        forced_plist = struct(UILaunchStoryboardName = short_name)
    elif default_launch_screen:
        # Avoid letterboxing iOS apps if a launch storyboard wasn't provided by adding an empty
        # UILaunchScreen dictionary key.
        overridable_plist = struct(UILaunchScreen = {})

    return struct(
        forced_plists = [forced_plist] if forced_plist else [],
        overridable_plists = [overridable_plist] if overridable_plist else [],
    )

def _extension_foundation_infoplist(
        *,
        actions,
        apple_mac_toolchain_info,
        bundle_id,
        is_extensionkit_extension = False,
        label,
        mac_exec_group,
        platform_prerequisites,
        split_attr_deps):
    """Gathers App Extension Info.plist contributions from `ExtensionFoundationInfo` dependencies.

    Collects the `.swiftconstvalues` files exported by `ExtensionFoundationInfo` dependencies,
    generates the App Extension Info.plist fragment (via exutil), and bucketizes it as an
    `infoplists` resource so it is merged into the bundle's root Info.plist. This centralizes logic
    that would otherwise be duplicated across every platform's app extension rule implementation.

    The returned `swiftconstvalues_files` are also re-exported by the caller through a new
    `ExtensionFoundationInfo` provider so that a hosting application can collect them transitively.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_mac_toolchain_info: `struct` of Apple tools from the shared Apple toolchain.
        bundle_id: The bundle identifier to encode into the generated Info.plist fragment.
        is_extensionkit_extension: Boolean indicating whether the extension is an ExtensionKit
            extension.
        label: The label of the target being analyzed.
        mac_exec_group: The exec_group associated with the Apple mac toolchain.
        platform_prerequisites: A `struct` containing information on the platform being targeted.
        split_attr_deps: The split `deps` mapping from `ctx.split_attr.deps`.

    Returns:
        A `struct` with the following fields:
            resource_providers: A list of resource providers to append to the rule's extra resource
                providers. Empty when no `ExtensionFoundationInfo` dependencies are present.
            swiftconstvalues_files: The list of collected `.swiftconstvalues` `File`s, for
                re-exporting via `ExtensionFoundationInfo`. Empty when no such dependencies exist.
    """
    deps_to_iterate = []
    for targets in split_attr_deps.values():
        deps_to_iterate.extend(targets)

    module_name = None
    swiftconstvalues_files = []
    for dep in deps_to_iterate:
        if ExtensionFoundationInfo in dep:
            swiftconstvalues_files.extend(
                dep[ExtensionFoundationInfo].swiftconstvalues_files.to_list(),
            )
        if not module_name and AppExtensionPointInfo in dep:
            for point in dep[AppExtensionPointInfo].extension_points.to_list():
                if point.module_name:
                    module_name = point.module_name
                    break

    if not swiftconstvalues_files:
        return struct(resource_providers = [], swiftconstvalues_files = [])

    if not is_extensionkit_extension:
        fail("""\
The extension target '{label}' depends on ExtensionFoundation dependencies, but \
'extensionkit_extension' is not set to True. Please set 'extensionkit_extension = True' on this \
target.\
""".format(label = label))

    exutil_plist = generate_appextension_plist(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        label = label,
        mac_exec_group = mac_exec_group,
        module_name = module_name,
        platform_prerequisites = platform_prerequisites,
        swiftconstvalues_files = swiftconstvalues_files,
    )
    return struct(
        resource_providers = [resources.bucketize_typed(
            bucket_type = "infoplists",
            expect_files = True,
            owner = str(label),
            resources = [exutil_plist],
        )],
        swiftconstvalues_files = swiftconstvalues_files,
    )

infoplist_support = struct(
    extension_foundation_infoplist = _extension_foundation_infoplist,
    launch_screen_values = _launch_screen_values,
)
