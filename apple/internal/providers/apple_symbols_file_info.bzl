# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""AppleSymbolsFileInfo provider implementation for transitive .symbols `File`s propagation."""

AppleSymbolsFileInfo = provider(
    doc = "Private provider to propagate the transitive .symbols `File`s.",
    fields = {
        "symbols_output_dirs": "Depset of `File`s containing directories of $UUID.symbols files for transitive dependencies.",
    },
)
