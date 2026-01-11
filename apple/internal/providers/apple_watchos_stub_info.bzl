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

"""AppleWatchosStubInfo implementation.."""

visibility("//apple/internal/...")

AppleWatchosStubInfo = provider(
    doc = """
Internal provider to propagate the watchOS stub that needs to be package in the iOS archive.
""",
    fields = {
        "binary": """
File artifact that contains a reference to the stub binary that needs to be packaged in the iOS
archive.
""",
    },
)
