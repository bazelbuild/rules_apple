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

"""Plist related actions."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "apple_action",
)
load(
    "@build_bazel_rules_apple//apple/bundling:plist_support.bzl",
    "plist_support",
)

def compile_plist(ctx, input_file, output_file):
  """Creates an action that compiles plist and strings files.

  Args:
    ctx: The Skylark context.
    input_file: The property list file that should be converted.
    output_file: The file reference for the output plist.
  """
  if input_file.basename.endswith(".strings"):
    mnemonic = "CompileStrings"
  else:
    mnemonic = "CompilePlist"

  # This command will check whether the input file is non-empty, and then
  # execute the version of plutil that takes the file directly. If the file is
  # empty, it will echo an new line and then pipe it into plutil. We do this
  # to handle empty files as plutil doesn't handle them very well.
  plutil_command = "plutil -convert binary1 -o %s --" % output_file.path
  complete_command = ("([[ -s {in_file} ]] && {plutil_command} {in_file} ) " +
                      "|| ( echo | {plutil_command} -)").format(
      in_file=input_file.path,
      plutil_command=plutil_command,
  )

  # Ideally we should be able to use command, which would set up the
  # /bin/sh -c prefix for us.
  # TODO(b/77637734): Change this to use command instead.
  apple_action(
      ctx,
      inputs=[input_file],
      outputs=[output_file],
      executable="/bin/sh",
      arguments=[
          "-c",
          complete_command,
      ],
      mnemonic=mnemonic,
  )

def merge_resource_infoplists(ctx, bundle_name, input_files, output_file):
  """Merges a list of plist files for resource bundles with substitutions.

  Args:
    ctx: The target's rule context.
    bundle_name: The name of the bundle where the plist will be placed in.
    input_files: The list of plists to merge.
    output_file: The file reference for the output plist.
  """
  substitutions = {
      "BUNDLE_NAME": bundle_name,
      "PRODUCT_NAME": paths.replace_extension(bundle_name, ""),
  }

  target = '%s (while bundling under "%s")' % (bundle_name, str(ctx.label))

  control = struct(
      binary=True,
      output=output_file.path,
      plists=[p.path for p in input_files],
      target=target,
      variable_substitutions=struct(**substitutions),
  )

  control_file = ctx.actions.declare_file(
      "%s-control" % output_file.basename,
      sibling=output_file,
  )
  ctx.actions.write(
      output=control_file,
      content=control.to_json()
  )

  plist_support.plisttool_action(
      ctx,
      inputs=input_files,
      outputs=[output_file],
      control_file=control_file,
      mnemonic="CompileInfoPlist",
  )
