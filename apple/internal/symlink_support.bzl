# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Support for symlink generation in rules."""

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _macos_framework_symlink_commands(target_dir, is_macos = True):
    """Returns a list of shell commands to generate macOS framework symlinks."""

    # BSD ln (macOS) expects -h to prevent resolving target directory links,
    # whereas GNU ln (Linux) expects -n.
    symlink_flag = "-sfh" if is_macos else "-sfn"
    return [
        # Create a symlink to the framework content at Versions/A from Versions/Current.
        "ln {symlink_flag} A {target_dir}/Versions/Current".format(
            symlink_flag = symlink_flag,
            target_dir = target_dir,
        ),
        # Create symlinks for all contents of the framework root to the corresponding
        # content as resolved through the Versions/Current symlink. This covers files and
        # folders.
        "for content_path in {target_dir}/Versions/A/* ; ".format(target_dir = target_dir) +
        # Use `##*/` to slice off the parent, leaving only the last path component.
        "do content=\"${content_path##*/}\"; " +
        "if [ \"${content}\" != \"Versions\" ]; then " +
        ("ln {symlink_flag} Versions/Current/\"${{content}}\" " +
         "{target_dir}/\"${{content}}\"; ").format(
            symlink_flag = symlink_flag,
            target_dir = target_dir,
        ) +
        "fi; done",
    ]

symlink_support = struct(
    macos_framework_symlink_commands = _macos_framework_symlink_commands,
)
