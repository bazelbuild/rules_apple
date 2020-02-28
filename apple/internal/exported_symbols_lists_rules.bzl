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

"""Actions for supporting exported symbols in link actions."""

load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)

def _exported_symbols_lists_impl(ctx):
    return [
        linking_support.exported_symbols_list_objc_provider(ctx.files.lists),
    ]

exported_symbols_lists = rule(
    implementation = _exported_symbols_lists_impl,
    attrs = {
        "lists": attr.label_list(
            allow_empty = False,
            allow_files = True,
            mandatory = True,
            doc = "The list of files that contain exported symbols.",
        ),
    },
    fragments = ["apple", "objc"],
)
