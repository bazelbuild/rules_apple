# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""IBTool related actions."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    xctoolrunner_support = "xctoolrunner",
)

visibility("@build_bazel_rules_apple//apple/internal/...")

def compile_storyboard(
        *,
        actions,
        input_file,
        mac_exec_group,
        output_dir,
        platform_prerequisites,
        xctoolrunner,
        swift_module):
    """Creates an action that compiles a storyboard.

    Args:
      actions: The actions provider from `ctx.actions`.
      input_file: The storyboard to compile.
      mac_exec_group: The exec_group associated with xctoolrunner.
      output_dir: The directory where the compiled outputs should be placed.
      platform_prerequisites: Struct containing information on the platform being targeted.
      xctoolrunner: A files_to_run for the wrapper around the "xcrun" tool.
      swift_module: The name of the Swift module to use when compiling the
        storyboard.
    """

    min_os = platform_prerequisites.minimum_os
    families = platform_prerequisites.device_families

    args = actions.args()
    args.add("ibtool")

    # Custom xctoolrunner options.
    args.add("--mute-warning", "substring=WARNING: Unhandled destination metrics: (null)")

    # Standard ibtool options.
    args.add("--minimum-deployment-target", min_os)
    args.add_all(families, before_each = "--target-device")
    args.add(
        "--compilation-directory",
        xctoolrunner_support.prefixed_path(output_dir.dirname),
    )
    args.add("--errors")
    args.add("--warnings")
    args.add("--notices")
    args.add("--auto-activate-custom-fonts")
    args.add("--output-format", "human-readable-text")
    args.add("--module", swift_module)
    args.add(xctoolrunner_support.prefixed_path(input_file.path))

    execution_requirements = {
        "no-sandbox": "1",
    }

    apple_support.run(
        actions = actions,
        arguments = [args],
        apple_fragment = platform_prerequisites.apple_fragment,
        executable = xctoolrunner,
        execution_requirements = execution_requirements,
        exec_group = mac_exec_group,
        inputs = [input_file],
        mnemonic = "StoryboardCompile",
        outputs = [output_dir],
        xcode_config = platform_prerequisites.xcode_version_config,
    )

def link_storyboards(
        *,
        actions,
        mac_exec_group,
        output_dir,
        platform_prerequisites,
        xctoolrunner,
        storyboardc_dirs):
    """Creates an action that links multiple compiled storyboards.

    Storyboards that reference each other must be linked, and this operation also
    copies them into a directory structure matching that which should appear in
    the final bundle.

    Args:
      actions: The actions provider from `ctx.actions`.
      mac_exec_group: The exec_group associated with xctoolrunner.
      output_dir: The directory where the linked outputs should be placed.
      platform_prerequisites: Struct containing information on the platform being targeted.
      xctoolrunner: A files_to_run for the wrapper for the "xcrun" tools.
      storyboardc_dirs: A list of `File`s that represent directories containing
        the compiled storyboards.
    """

    min_os = platform_prerequisites.minimum_os
    families = platform_prerequisites.device_families

    args = actions.args()
    args.add("ibtool")

    # Custom xctoolrunner options.
    args.add("--mute-warning", "substring=WARNING: Unhandled destination metrics: (null)")

    # Standard ibtool options.
    args.add("--minimum-deployment-target", min_os)
    args.add_all(families, before_each = "--target-device")
    args.add("--link", xctoolrunner_support.prefixed_path(output_dir.path))
    args.add_all([
        xctoolrunner_support.prefixed_path(f.path)
        for f in storyboardc_dirs
    ])

    apple_support.run(
        actions = actions,
        arguments = [args],
        apple_fragment = platform_prerequisites.apple_fragment,
        executable = xctoolrunner,
        execution_requirements = {"no-sandbox": "1"},
        exec_group = mac_exec_group,
        inputs = storyboardc_dirs,
        mnemonic = "StoryboardLink",
        outputs = [output_dir],
        xcode_config = platform_prerequisites.xcode_version_config,
    )

def compile_xib(
        *,
        actions,
        input_file,
        mac_exec_group,
        output_dir,
        platform_prerequisites,
        xctoolrunner,
        swift_module):
    """Creates an action that compiles a Xib file.

    Args:
      actions: The actions provider from `ctx.actions`.
      input_file: The Xib file to compile.
      mac_exec_group: The exec_group associated with xctoolrunner.
      output_dir: The file reference for the output directory.
      platform_prerequisites: Struct containing information on the platform being targeted.
      xctoolrunner: A files_to_run for the wrapper around the "xcrun" tool.
      swift_module: The name of the Swift module to use when compiling the
        Xib file.
    """

    min_os = platform_prerequisites.minimum_os
    families = platform_prerequisites.device_families

    nib_name = paths.replace_extension(paths.basename(input_file.short_path), ".nib")

    args = actions.args()
    args.add("ibtool")

    # Custom xctoolrunner options.
    args.add("--mute-warning", "substring=WARNING: Unhandled destination metrics: (null)")

    # Standard ibtool options.
    args.add("--minimum-deployment-target", min_os)
    args.add_all(families, before_each = "--target-device")
    args.add(
        "--compile",
        xctoolrunner_support.prefixed_path(paths.join(output_dir.path, nib_name)),
    )
    args.add("--module", swift_module)
    args.add(xctoolrunner_support.prefixed_path(input_file.path))

    execution_requirements = {
        "no-sandbox": "1",
    }

    apple_support.run(
        actions = actions,
        arguments = [args],
        apple_fragment = platform_prerequisites.apple_fragment,
        executable = xctoolrunner,
        execution_requirements = execution_requirements,
        exec_group = mac_exec_group,
        inputs = [input_file],
        mnemonic = "XibCompile",
        outputs = [output_dir],
        xcode_config = platform_prerequisites.xcode_version_config,
    )
