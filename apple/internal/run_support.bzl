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

load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)

def _register_simulator_executable(
        *,
        actions,
        bundle_extension,
        bundle_name,
        output,
        platform_prerequisites,
        predeclared_outputs,
        runner_template):
    """Registers an action that runs the bundled app in the iOS simulator.

    Args:
      actions: The actions provider from ctx.actions.
      bundle_extension: Extension for the Apple bundle inside the archive.
      bundle_name: The name of the output bundle.
      output: The `File` representing where the executable should be generated.
      platform_prerequisites: Struct containing information on the platform being targeted.
      predeclared_outputs: Outputs declared by the owning context. Typically from `ctx.outputs`
      runner_template: The simulator runner template as a `File`.
    """

    sim_device = str(platform_prerequisites.objc_fragment.ios_simulator_device or "")
    sim_os_version = str(platform_prerequisites.objc_fragment.ios_simulator_version or "")
    minimum_os = str(platform_prerequisites.minimum_os)
    archive = outputs.archive(
        actions = actions,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    actions.expand_template(
        output = output,
        is_executable = True,
        template = runner_template,
        substitutions = {
            "%app_name%": bundle_name,
            "%ipa_file%": archive.short_path,
            "%sim_device%": sim_device,
            "%sim_os_version%": sim_os_version,
            "%minimum_os%": minimum_os,
        },
    )

def _register_macos_executable(
        *,
        actions,
        bundle_extension,
        bundle_name,
        output,
        platform_prerequisites,
        predeclared_outputs,
        runner_template):
    """Registers an action that runs the bundled macOS app.

    Args:
      actions: The actions provider from ctx.actions.
      bundle_extension: Extension for the Apple bundle inside the archive.
      bundle_name: The name of the output bundle.
      output: The `File` representing where the executable should be generated.
      platform_prerequisites: Struct containing information on the platform being targeted.
      predeclared_outputs: Outputs declared by the owning context. Typically from `ctx.outputs`
      runner_template: The macos runner template as a `File`.
    """

    archive = outputs.archive(
        actions = actions,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    actions.expand_template(
        output = output,
        is_executable = True,
        template = runner_template,
        substitutions = {
            "%app_name%": bundle_name,
            "%app_path%": archive.short_path,
        },
    )

# Define the loadable module that lists the exported symbols in this file.
run_support = struct(
    register_simulator_executable = _register_simulator_executable,
    register_macos_executable = _register_macos_executable,
)
