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

"""PNG related actions."""

load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "xcrun_action",
)

def copy_png(ctx, input_file, output_file):
  """Creates an action that copies and compresses a png using copypng.

  Args:
    ctx: The target's rule context.
    input_file: The png file to be copied.
    output_file: The file reference for the output plist.
  """
  xcrun_action(
      ctx,
      inputs=[input_file],
      outputs=[output_file],
      arguments=[
          "copypng",
          "-strip-PNG-text",
          "-compress",
          input_file.path,
          output_file.path,
      ],
      mnemonic="CopyPng",
  )
