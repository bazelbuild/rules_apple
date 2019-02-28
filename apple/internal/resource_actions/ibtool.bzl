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
    "@build_bazel_rules_apple//apple/internal/utils:legacy_actions.bzl",
    "legacy_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    "xctoolrunner",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _ibtool_arguments(min_os, families):
    """Returns common `ibtool` command line arguments.

    This function returns the common arguments used by both xib and storyboard
    compilation, as well as storyboard linking. Callers should add their own
    arguments to the returned array for their specific purposes.

    Args:
      min_os: The minimum OS version to use when compiling interface files.
      families: The families that should be supported by the compiled interfaces.

    Returns:
      An array of command-line arguments to pass to ibtool.
    """
    return [
        "--minimum-deployment-target",
        min_os,
    ] + collections.before_each(
        "--target-device",
        families,
    )

def compile_storyboard(ctx, swift_module, input_file, output_dir):
    """Creates an action that compiles a storyboard.

    Args:
      ctx: The target's rule context.
      swift_module: The name of the Swift module to use when compiling the
        storyboard.
      input_file: The storyboard to compile.
      output_dir: The directory where the compiled outputs should be placed.
    """

    args = [
        "ibtool",
        "--compilation-directory",
        xctoolrunner.prefixed_path(output_dir.dirname),
    ]

    min_os = platform_support.minimum_os(ctx)
    families = platform_support.families(ctx)
    args.extend(_ibtool_arguments(min_os, families))
    args.extend([
        "--module",
        swift_module,
        xctoolrunner.prefixed_path(input_file.path),
    ])

    legacy_actions.run(
        ctx,
        inputs = [input_file],
        outputs = [output_dir],
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "StoryboardCompile",
        execution_requirements = {"no-sandbox": "1"},
    )

def link_storyboards(ctx, storyboardc_dirs, output_dir):
    """Creates an action that links multiple compiled storyboards.

    Storyboards that reference each other must be linked, and this operation also
    copies them into a directory structure matching that which should appear in
    the final bundle.

    Args:
      ctx: The target's rule context.
      storyboardc_dirs: A list of `File`s that represent directories containing
        the compiled storyboards.
      output_dir: The directory where the linked outputs should be placed.
    """

    min_os = platform_support.minimum_os(ctx)
    families = platform_support.families(ctx)

    args = [
        "ibtool",
        "--link",
        xctoolrunner.prefixed_path(output_dir.path),
    ]
    args.extend(_ibtool_arguments(min_os, families))
    args.extend([
        xctoolrunner.prefixed_path(f.path)
        for f in storyboardc_dirs
    ])

    legacy_actions.run(
        ctx,
        inputs = storyboardc_dirs,
        outputs = [output_dir],
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "StoryboardLink",
        execution_requirements = {"no-sandbox": "1"},
    )

def compile_xib(ctx, swift_module, input_file, output_dir):
    """Creates an action that compiles a Xib file.

    Args:
      ctx: The target's rule context.
      swift_module: The name of the Swift module to use when compiling the
        Xib file.
      input_file: The Xib file to compile.
      output_dir: The file reference for the output directory.
    """

    min_os = platform_support.minimum_os(ctx)
    families = platform_support.families(ctx)

    nib_name = paths.replace_extension(paths.basename(input_file.short_path), ".nib")

    args = [
        "ibtool",
        "--compile",
        xctoolrunner.prefixed_path(paths.join(output_dir.path, nib_name)),
    ]
    args.extend(_ibtool_arguments(min_os, families))
    args.extend([
        "--module",
        swift_module,
        xctoolrunner.prefixed_path(input_file.path),
    ])

    legacy_actions.run(
        ctx,
        inputs = [input_file],
        outputs = [output_dir],
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "XibCompile",
        execution_requirements = {"no-sandbox": "1"},
    )
