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

"""Texture atlas related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)

def compile_texture_atlas(ctx, input_path, input_files, output_dir):
    """Creates an action that compiles texture atlas bundles (i.e. .atlas).

    Args:
      ctx: The target's rule context.
      input_path: The path to the .atlas directory to compile.
      input_files: The atlas file inputs that will be compiled.
      output_dir: The file reference for the compiled output directory.
    """
    apple_support.run(
        ctx,
        executable = "/usr/bin/xcrun",
        arguments = [
            "TextureAtlas",
            input_path,
            output_dir.path,
        ],
        inputs = input_files,
        outputs = [output_dir],
        mnemonic = "CompileTextureAtlas",
    )
