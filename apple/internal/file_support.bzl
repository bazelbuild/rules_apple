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

"""Support for basic file system operations."""

def _symlink(ctx, source, target):
    """Creates a symlink.

    This action will create the necessary directory structure for the target if
    it is not present already.

    Args:
      ctx: The Skylark context.
      source: The source `File` of the symlink.
      target: A `File` representing the target of the symlink.
    """

    # TODO(b/33386130): Create proper symlinks everywhere.
    ctx.actions.run_shell(
        inputs = [source],
        outputs = [target],
        mnemonic = "Symlink",
        arguments = [
            target.dirname,
            source.path,
            target.path,
            ctx.file._realpath.path,
        ],
        command = ('mkdir -p "$1"; ' +
                   'if [[ "$(uname)" == Darwin ]]; then ' +
                   '  ln -s "$("$4" "$2")" "$3"; ' +
                   "else " +
                   '  cp "$2" "$3"; ' +
                   "fi"),
        progress_message = "Symlinking %s to %s" % (source.path, target.path),
        tools = [ctx.file._realpath],
        execution_requirements = {"no-sandbox": "1"},
    )

# Define the loadable module that lists the exported symbols in this file.
file_support = struct(
    symlink = _symlink,
)
