# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Transition helper for building targets with Swift explicit modules."""

def _swift_explicit_modules_transition_impl(settings, _attr):
    return {
        "//command_line_option:features": settings["//command_line_option:features"] + [
            "swift.emit_c_module",
            "swift.use_c_modules",
            "swift.use_explicit_swift_module_map",
            "-swift.add_default_precompiled_modules",
        ],
    }

_swift_explicit_modules_transition = transition(
    implementation = _swift_explicit_modules_transition_impl,
    inputs = ["//command_line_option:features"],
    outputs = ["//command_line_option:features"],
)

def _swift_explicit_modules_target_impl(ctx):
    target = ctx.attr.target[0]
    return [
        DefaultInfo(files = target[DefaultInfo].files),
    ]

swift_explicit_modules_target = rule(
    implementation = _swift_explicit_modules_target_impl,
    attrs = {
        "target": attr.label(
            mandatory = True,
            cfg = _swift_explicit_modules_transition,
            doc = "The target to build with Swift explicit modules enabled.",
        ),
    },
    doc = "Forwards default outputs from a target built with Swift explicit modules enabled.",
)
