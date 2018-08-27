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

"""ZIP related actions."""

def unzip(ctx, input_file, output_dir):
    """Creates an action that extracts a ZIP file into a given directory.

    Args:
      ctx: The target's rule context.
      input_file: The ZIP file to be unzip.
      output_dir: The file reference for the output directory.
    """
    ctx.actions.run_shell(
        inputs = [input_file],
        outputs = [output_dir],
        command = " ".join([
            "unzip",
            "-qq",
            "-o",
            input_file.path,
            "-d",
            output_dir.path,
        ]),
        mnemonic = "UnzipResources",
    )
