# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Bitcode support."""

def _bitcode_mode_string(apple_fragment):
    """Returns a string representing the current Bitcode mode."""

    bitcode_mode = apple_fragment.bitcode_mode
    if not bitcode_mode:
        fail("Internal error: Can't figure out bitcode_mode from apple " +
             "fragment")

    bitcode_mode_string = str(bitcode_mode)
    bitcode_modes = ["embedded", "embedded_markers", "none"]
    if bitcode_mode_string in bitcode_modes:
        return bitcode_mode_string

    fail("Internal error: expected bitcode_mode to be one of: " +
         "{}, but got '{}'".format(
             bitcode_modes,
             bitcode_mode_string,
         ))

bitcode_support = struct(
    bitcode_mode_string = _bitcode_mode_string,
)
