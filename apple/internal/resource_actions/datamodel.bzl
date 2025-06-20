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

"""Datamodel related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    xctoolrunner_support = "xctoolrunner",
)

visibility("@build_bazel_rules_apple//apple/internal/...")

def compile_datamodels(
        *,
        actions,
        datamodel_path,
        input_files,
        mac_exec_group,
        module_name,
        output_file,
        platform_prerequisites,
        xctoolrunner):
    """Creates an action that compiles datamodels.

    Args:
        actions: The actions provider from `ctx.actions`.
        datamodel_path: The path to the directory containing the datamodels.
        input_files: The list of files to process for the given datamodel.
        mac_exec_group: The exec_group associated with xctoolrunner.
        module_name: The module name to use when compiling the datamodels.
        output_file: The file reference to the compiled datamodel.
        platform_prerequisites: Struct containing information on the platform being targeted.
        xctoolrunner: A files_to_run for the wrapper around the "xcrun" tool.
    """
    platform = platform_prerequisites.platform
    platform_name = platform.name_in_plist.lower()
    deployment_target_option = "--%s-deployment-target" % platform_name

    args = actions.args()
    args.add("momc")

    # Custom xctoolrunner options.
    args.add("--xctoolrunner_assert_nonempty_dir", output_file.dirname)

    # Standard momc options.
    args.add(deployment_target_option, platform_prerequisites.minimum_os)
    args.add("--module", module_name)
    args.add(xctoolrunner_support.prefixed_path(datamodel_path))
    args.add(xctoolrunner_support.prefixed_path(output_file.path))

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [args],
        executable = xctoolrunner,
        exec_group = mac_exec_group,
        inputs = input_files,
        mnemonic = "MomCompile",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
    )

def compile_mappingmodel(
        *,
        actions,
        input_files,
        mac_exec_group,
        mappingmodel_path,
        output_file,
        platform_prerequisites,
        xctoolrunner):
    """Creates an action that compiles CoreData mapping models.

    Args:
        actions: The actions provider from `ctx.actions`.
        input_files: The list of files to process for the given mapping model.
        mappingmodel_path: The path to the directory containing the mapping model.
        mac_exec_group: The exec_group associated with xctoolrunner.
        output_file: The file reference to the compiled mapping model.
        platform_prerequisites: Struct containing information on the platform being targeted.
        xctoolrunner: A files_to_run for the wrapper around the "xcrun" tool.
    """
    args = [
        "mapc",
        xctoolrunner_support.prefixed_path(mappingmodel_path),
        xctoolrunner_support.prefixed_path(output_file.path),
    ]

    apple_support.run(
        actions = actions,
        arguments = args,
        apple_fragment = platform_prerequisites.apple_fragment,
        executable = xctoolrunner,
        exec_group = mac_exec_group,
        inputs = input_files,
        mnemonic = "MappingModelCompile",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
    )
