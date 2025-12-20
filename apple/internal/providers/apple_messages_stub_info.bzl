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

"""AppleMessagesStubInfo implementation."""

visibility("//apple/internal/...")

AppleMessagesStubInfo = provider(
    doc = """
Provider for iMessage application stub binaries that need to be packaged in the archive.
""",
    fields = {
        "messages_application_support": """
File for the MessagesApplicationSupport stub binary (for iMessage apps). May be None.
""",
        "messages_extension_support": """
File for the MessagesApplicationExtensionSupport stub binary (from extensions). May be None.
""",
    },
)
