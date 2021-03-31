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
    "xctoolrunner",
)

def compile_datamodels(
        *,
        actions,
        datamodel_path,
        input_files,
        module_name,
        output_file,
        platform_prerequisites,
        resolved_xctoolrunner):
    """Creates an action that compiles datamodels.

    Args:
        actions: The actions provider from `ctx.actions`.
        datamodel_path: The path to the directory containing the datamodels.
        input_files: The list of files to process for the given datamodel.
        module_name: The module name to use when compiling the datamodels.
        output_file: The file reference to the compiled datamodel.
        platform_prerequisites: Struct containing information on the platform being targeted.
        resolved_xctoolrunner: A struct referencing the resolved wrapper for "xcrun" tools.
    """
    platform = platform_prerequisites.platform
    platform_name = platform.name_in_plist.lower()
    deployment_target_option = "--%s-deployment-target" % platform_name

    args = [
        "momc",
        deployment_target_option,
        platform_prerequisites.minimum_os,
        "--module",
        module_name,
        xctoolrunner.prefixed_path(datamodel_path),
        xctoolrunner.prefixed_path(output_file.path),
    ]

    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = args,
        executable = resolved_xctoolrunner.executable,
        inputs = depset(input_files, transitive = [resolved_xctoolrunner.inputs]),
        input_manifests = resolved_xctoolrunner.input_manifests,
        mnemonic = "MomCompile",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
    )

def compile_mappingmodel(
        *,
        actions,
        input_files,
        mappingmodel_path,
        output_file,
        platform_prerequisites,
        resolved_xctoolrunner):
    """Creates an action that compiles CoreData mapping models.

    Args:
        actions: The actions provider from `ctx.actions`.
        input_files: The list of files to process for the given mapping model.
        mappingmodel_path: The path to the directory containing the mapping model.
        output_file: The file reference to the compiled mapping model.
        platform_prerequisites: Struct containing information on the platform being targeted.
        resolved_xctoolrunner: A struct referencing the resolved wrapper for "xcrun" tools.
    """
    args = [
        "mapc",
        xctoolrunner.prefixed_path(mappingmodel_path),
        xctoolrunner.prefixed_path(output_file.path),
    ]

    apple_support.run(
        actions = actions,
        arguments = args,
        apple_fragment = platform_prerequisites.apple_fragment,
        executable = resolved_xctoolrunner.executable,
        inputs = depset(input_files, transitive = [resolved_xctoolrunner.inputs]),
        input_manifests = resolved_xctoolrunner.input_manifests,
        mnemonic = "MappingModelCompile",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
    )
