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
    
    ctx.actions.symlink(
        output = target,
        target_file = source,
        progress_message = "Symlinking %s to %s" % (source.path, target.path),
    )

# Define the loadable module that lists the exported symbols in this file.
file_support = struct(
    symlink = _symlink,
)
