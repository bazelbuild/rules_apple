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

"""Support for action specific files."""

def _xctoolrunner_path(path):
    """Prefix paths with a token.

    We prefix paths with a token to indicate that certain arguments are paths,
    so they can be processed accordingly. This prefix must match the prefix
    used here: rules_apple/tools/xctoolrunner/xctoolrunner.py

    Args:
      path: A string of the path to be prefixed.

    Returns:
      A string of the path with the prefix added to the front.
    """
    prefix = "[ABSOLUTE]"
    return prefix + path

# Define the loadable module that lists the exported symbols in this file.
file_support = struct(
    xctoolrunner_path = _xctoolrunner_path,
)
