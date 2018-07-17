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
    "@build_bazel_rules_apple//apple/bundling:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)

def compile_datamodels(ctx, datamodel_path, module_name, input_files, output_file):
    """Creates an action that compiles datamodels.

    Args:
      ctx: The target's rule context.
      datamodel_path: The path to the directory containing the datamodels.
      module_name: The module name to use when compiling the datamodels.
      input_files: The list of files to process for the given datamodel.
      output_file: The file reference to the compiled datamodel.
    """
    platform = platform_support.platform(ctx)
    platform_name = platform.name_in_plist.lower()
    deployment_target_option = "--%s-deployment-target" % platform_name
    min_os = platform_support.minimum_os(ctx)

    args = [
        deployment_target_option,
        min_os,
        "--module",
        module_name,
        file_support.xctoolrunner_path(datamodel_path),
        file_support.xctoolrunner_path(output_file.path),
    ]

    platform_support.xcode_env_action(
        ctx,
        inputs = input_files,
        outputs = [output_file],
        executable = ctx.executable._momcwrapper,
        arguments = args,
        mnemonic = "MomCompile",
    )
