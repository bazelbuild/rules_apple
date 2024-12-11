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

"""An aspect that collects information about the Swift generated header."""

load(
    "@build_bazel_rules_apple//apple/internal/providers:swift_generated_header_info.bzl",
    "SwiftGeneratedHeaderInfo",
)

visibility("@build_bazel_rules_apple//apple/...")

def _swift_generated_header_aspect_impl(target, aspect_ctx):
    if aspect_ctx.rule.kind != "swift_library":
        return []

    # TODO(b/383374684): Consider pulling this into a shared rules_swift helper.
    generated_header_name = aspect_ctx.rule.attr.generated_header_name

    if not generated_header_name:
        generated_header_name = "{}-Swift.h".format(target.label.name)

    return [SwiftGeneratedHeaderInfo(generated_header_name = generated_header_name)]

swift_generated_header_aspect = aspect(
    doc = "Collects information about the Swift generated header.",
    implementation = _swift_generated_header_aspect_impl,
)
