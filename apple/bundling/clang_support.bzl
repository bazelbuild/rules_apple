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

"""Supporting functions for Clang libraries."""

load("@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support")
load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support")
load("@build_bazel_rules_apple//apple/bundling:file_support.bzl",
    "file_support")
load("@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support")


def _should_package_clang_runtime(ctx):
  """Returns whether the Clang runtime should be bundled."""
  # List of crosstool sanitizer features that require packaging some clang
  # runtime libraries.
  features_requiring_clang_runtime = {
      "asan": True,
      "tsan": True,
      "ubsan": True,
  }

  for feature in ctx.features:
    if feature in features_requiring_clang_runtime:
      return True
  return False


def _register_runtime_lib_actions(ctx, binary_artifact):
  """Creates an archive with Clang runtime libraries.

  Args:
    ctx: The Skylark context.
    binary_artifact: The bundle binary to be processed with clang's runtime
        tool.
  Returns:
    A `File` object representing the ZIP file containing runtime libraries.
  """
  zip_file = file_support.intermediate(ctx, "%{name}.clang_rt_libs.zip")
  platform_support.xcode_env_action(
      ctx,
      inputs=[binary_artifact],
      outputs=[zip_file],
      executable=ctx.executable._clangrttool,
      arguments=[
        binary_artifact.path,
        zip_file.path,
      ],
      mnemonic="ClangRuntimeLibsCopy",
      # This action needs to read the contents of the Xcode bundle.
      no_sandbox=True,
  )
  return zip_file


clang_support = struct(
    register_runtime_lib_actions=_register_runtime_lib_actions,
    should_package_clang_runtime=_should_package_clang_runtime
)
