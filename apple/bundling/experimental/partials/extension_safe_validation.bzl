# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Partial implementation for extension safety validation."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

_AppleExtensionSafeValidationInfo = provider(
    doc = "Private provider that propagates whether the target is marked as extension safe or not.",
    fields = {
        "is_extension_safe": "Boolean indicating that the target is extension safe or not.",
    },
)

def _extension_safe_validation_partial_impl(ctx, is_extension_safe):
    """Implementation for the extension safety validation partial."""

    if is_extension_safe:
        for target in ctx.attr.frameworks:
            if not target[_AppleExtensionSafeValidationInfo].is_extension_safe:
                print(
                    ("The target {current_label} is for an extension but its framework " +
                     "dependency {target_label} is not marked extension-safe. Specify " +
                     "'extension_safe = 1' on the framework target. This will soon cause a build " +
                     "failure.").format(current_label = ctx.label, target_label = target.label),
                )

    return struct(
        providers = [_AppleExtensionSafeValidationInfo(is_extension_safe = is_extension_safe)],
    )

def extension_safe_validation_partial(is_extension_safe):
    """Constructor for the extension safety validation partial.

    This partial validates that the framework dependencies are extension safe iff the current target
    is also extension safe.

    Args:
        is_extension_safe: Boolean indicating that the current target is extension safe or not.

    Returns:
        A partial that validates extension safety.
    """
    return partial.make(
        _extension_safe_validation_partial_impl,
        is_extension_safe = is_extension_safe,
    )
