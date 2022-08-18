# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""Apple build settings attributes to be added to rules that read configuration settings."""

_PARSE_XCFRAMEWORK_INFO_PLIST = {
    "_parse_xcframework_info_plist": attr.label(
        default = "@build_bazel_rules_apple//apple/build_settings:parse_xcframework_info_plist",
        doc = """
Boolean build setting to enable Info.plist file parsing using the xcframework_processor_tool.
""",
    ),
}

build_settings = struct(
    attrs = struct(
        parse_xcframework_info_plist = _PARSE_XCFRAMEWORK_INFO_PLIST,
    ),
)
