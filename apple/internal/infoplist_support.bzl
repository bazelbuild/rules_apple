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

visibility([
    "//apple/...",
    "//test/...",
])

def _launch_screen_values(
        *,
        default_launch_screen = False,
        launch_storyboard,
        platform_prerequisites):
    """Returns a struct indicating what plist values should be added to support launch screens.

    Args:
        default_launch_screen: Bool to indicate if plist values should be set to add a default
            launch screen if no launch_storyboard was defined. `False` by default.
        launch_storyboard: A `File` to be used as a launch screen for the application. Can be
            `None` if there is no launch storyboard defined.
        platform_prerequisites: A `struct` containing information on the platform being targeted.

    Returns:
        A struct with `forced_plists` and `overridable_plists`, which each include lists of structs
        with keys and values identical to the plist keys and values that need be merged into the
        final root Info.plist to declare the launch screen. This format is compatible with plisttool
        merging operations.
    """

    if (platform_prerequisites.platform_type != apple_common.platform_type.ios and
        platform_prerequisites.platform_type != apple_common.platform_type.tvos):
        fail("""\
Internal error: Attempted to define Info.plist values for a launch storyboard/screen on a platform
where the feature isn't supported.

Please file an issue against the Apple BUILD rules.

Found platform is: {platform_type}
""".format(
            platform_type = str(platform_prerequisites.platform_type),
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

infoplist_support = struct(
    launch_screen_values = _launch_screen_values,
)
