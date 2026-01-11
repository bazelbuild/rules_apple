# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""AppleSwiftDylibsInfo implementation.."""

visibility("//apple/internal/...")

AppleSwiftDylibsInfo = provider(
    doc = """
Internal provider to propagate the transitive binary `File`s that depend on
Swift.
""",
    fields = {
        "binary": """
Depset of binary `File`s containing the transitive dependency binaries that use
Swift.
""",
        "swift_support_files": """
List of 2-element tuples that represent which files should be bundled as part of the SwiftSupport
archive directory. The first element of the tuple is the platform name, and the second element is a
File object that represents a directory containing the Swift dylibs to package for that platform.
""",
    },
)
