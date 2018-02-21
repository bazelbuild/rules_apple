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

"""Common definitions used to make runnable Apple bundling rules."""

load("@bazel_skylib//lib:shell.bzl", "shell")


def _start_simulator(ctx):
  """Registers an action that runs the bundled app in the iOS simulator.

  This function requires that the calling rule include the `objc` configuration
  fragment, outputs an `archive` with the IPA, and have the following tool
  attributes:

  - `_std_redirect_dylib`: The StdRedirect.dylib file used to make an app's
    output visible during the run.

  Args:
    ctx: The Skylark context.
  Returns:
    A list of files that should be added to the calling rule's runfiles.
  """
  ctx.template_action(
      output=ctx.outputs.executable,
      executable=True,
      template=ctx.file._ios_runner,
      substitutions={
          "%app_name%": ctx.label.name,
          "%ipa_file%": ctx.outputs.archive.short_path,
          "%sdk_version%": str(ctx.fragments.objc.ios_simulator_version),
          "%sim_device%": shell.quote(ctx.fragments.objc.ios_simulator_device),
          "%std_redirect_dylib_path%": ctx.file._std_redirect_dylib.short_path,
      },
  )
  return [
      ctx.outputs.executable,
      ctx.outputs.archive,
      ctx.file._std_redirect_dylib,
  ]


# Define the loadable module that lists the exported symbols in this file.
run_actions = struct(
    start_simulator=_start_simulator,
)
