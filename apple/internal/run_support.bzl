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

load("@build_bazel_rules_apple//apple/internal:bundling_support.bzl", "bundling_support")
load("@build_bazel_rules_apple//apple/internal:outputs.bzl", "outputs")

def _register_simulator_executable(ctx, output):
    """Registers an action that runs the bundled app in the iOS simulator.

    Args:
      ctx: The Skylark context.
      output: The `File` representing where the executable should be generated.
    """

    sim_device = str(ctx.fragments.objc.ios_simulator_device or "")
    sim_os_version = str(ctx.fragments.objc.ios_simulator_version or "")

    ctx.actions.expand_template(
        output = output,
        is_executable = True,
        template = ctx.file._runner_template,
        substitutions = {
            "%app_name%": bundling_support.bundle_name(ctx),
            "%ipa_file%": outputs.archive(ctx).short_path,
            "%sim_device%": sim_device,
            "%sim_os_version%": sim_os_version,
            "%std_redirect_dylib_path%": ctx.file._std_redirect_dylib.short_path,
        },
    )

def _register_macos_executable(ctx, output):
    """Registers an action that runs the bundled macOS app.

    Args:
      ctx: The Skylark context.
      output: The `File` representing where the executable should be generated.
    """
    ctx.actions.expand_template(
        output = output,
        is_executable = True,
        template = ctx.file._macos_runner_template,
        substitutions = {
            "%app_name%": bundling_support.bundle_name(ctx),
            "%app_path%": outputs.archive(ctx).short_path,
        },
    )

# Define the loadable module that lists the exported symbols in this file.
run_support = struct(
    register_simulator_executable = _register_simulator_executable,
    register_macos_executable = _register_macos_executable,
)
