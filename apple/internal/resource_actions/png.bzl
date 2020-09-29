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
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)

def copy_png(*, actions, input_file, output_file, platform_prerequisites):
    """Creates an action that copies and compresses a png using copypng.

    Args:
      actions: The actions provider from `ctx.actions`.
      input_file: The png file to be copied.
      output_file: The file reference for the output plist.
      platform_prerequisites: Struct containing information on the platform being targeted.
    """

    # Xcode uses `xcrun copypng -strip-PNG-text -compress IN OUT`. But pngcrush
    # is a perl script that doesn't properly handle when the process dies via a
    # signal, so instead just expand out the comment to skip the script and
    # directly run Xcode's copy of pngcrush with the same args.
    apple_support.run(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        arguments = [
            "pngcrush",
            # -compress expands to:
            "-q",
            "-iphone",
            "-f",
            "0",
            # "-strip-PNG-text",
            "-rem",
            "text",
            input_file.path,
            output_file.path,
        ],
        executable = "/usr/bin/xcrun",
        inputs = [input_file],
        mnemonic = "CopyPng",
        outputs = [output_file],
        xcode_config = platform_prerequisites.xcode_version_config,
        xcode_path_wrapper = platform_prerequisites.xcode_path_wrapper,
    )
