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
        label_name,
        output,
        platform_prerequisites,
        predeclared_outputs,
        rule_descriptor,
        runner_template,
        simulator_device = None,
        simulator_version = None):
    """Registers an action that runs the bundled app in the iOS simulator.

    Args:
      actions: The actions provider from ctx.actions.
      bundle_extension: Extension for the Apple bundle inside the archive.
      bundle_name: The name of the output bundle.
      label_name: The name of the target.
      output: The `File` representing where the executable should be generated.
      platform_prerequisites: Struct containing information on the platform being targeted.
      predeclared_outputs: Outputs declared by the owning context. Typically from `ctx.outputs`
      rule_descriptor: The rule descriptor for the given rule.
      runner_template: The simulator runner template as a `File`.
      simulator_device: The type of device (e.g. 'iPhone 6') to use when running on the simulator.
      simulator_version: The SDK version of the simulator to use when running on the simulator.
    """

    sim_device = str(simulator_device or "")
    sim_os_version = str(simulator_version or "")
    minimum_os = str(platform_prerequisites.minimum_os)
    platform_type = str(platform_prerequisites.platform_type)
    archive = outputs.archive(
        actions = actions,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        label_name = label_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        rule_descriptor = rule_descriptor,
    )

    actions.expand_template(
        output = output,
        is_executable = True,
        template = runner_template,
        substitutions = {
            "%app_name%": bundle_name,
            "%ipa_file%": archive.short_path,
            "%minimum_os%": minimum_os,
            "%platform_type%": platform_type,
            "%sim_device%": sim_device,
            "%sim_os_version%": sim_os_version,
        },
    )

def _register_macos_executable(
        *,
        actions,
        bundle_extension,
        bundle_name,
        label_name,
        output,
        platform_prerequisites,
        predeclared_outputs,
        rule_descriptor,
        runner_template):
    """Registers an action that runs the bundled macOS app.

    Args:
      actions: The actions provider from ctx.actions.
      bundle_extension: Extension for the Apple bundle inside the archive.
      bundle_name: The name of the output bundle.
      label_name: The name of the target.
      output: The `File` representing where the executable should be generated.
      platform_prerequisites: Struct containing information on the platform being targeted.
      predeclared_outputs: Outputs declared by the owning context. Typically from `ctx.outputs`
      runner_template: The macos runner template as a `File`.
      rule_descriptor: The rule descriptor for the given rule.
    """

    archive = outputs.archive(
        actions = actions,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        label_name = label_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        rule_descriptor = rule_descriptor,
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
