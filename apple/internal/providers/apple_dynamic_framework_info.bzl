# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""AppleDynamicFrameworkInfo provider implementation."""

visibility([
    "//apple/internal/...",
])

_AppleDynamicFrameworkInfo = provider(
    doc = "Contains information about an Apple dynamic framework.",
    fields = {
        "framework_dirs": """\
The framework path names used as link inputs in order to link against the
dynamic framework.
""",
        "framework_files": """\
The full set of artifacts that should be included as inputs to link against the
dynamic framework.
""",
        "binary": "The dylib binary artifact of the dynamic framework.",
        "cc_info": """\
A `CcInfo` which contains information about the transitive dependencies linked
into the binary.
""",
    },
)

# TODO: Remove when we drop 7.x
AppleDynamicFrameworkInfo = getattr(apple_common, "AppleDynamicFramework", _AppleDynamicFrameworkInfo)

# TODO: Remove when we drop 7.x
def new_appledynamicframeworkinfo(**kwargs):
    legacy_initializer = getattr(apple_common, "new_dynamic_framework_provider", None)
    if legacy_initializer:
        return legacy_initializer(**kwargs)

    return AppleDynamicFrameworkInfo(**kwargs)
