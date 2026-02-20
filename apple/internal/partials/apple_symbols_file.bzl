# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Partial implementation for Apple .symbols file processing."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

visibility("@build_bazel_rules_apple//apple/...")

def _apple_symbols_file_partial_impl(
        *,
        include_symbols_in_bundle,
        rule_label):
    """Implementation for the Apple .symbols file processing partial."""
    if include_symbols_in_bundle:
        # print is the only way to emit a warning during rule processing.
        # buildifier: disable=print
        print(
            """
WARNING: Including symbols in the bundle is still enabled for the target {rule_label}, via the use \
of "include_symbols_in_bundle = True".

This attribute is now a no-op.

Per FB21934928, Apple has requested that symbols no longer be included in the bundle, as they are \
only required for shipping bitcode, and bitcode is forbidden from shipping applications on all \
Apple platforms since Xcode 14.

Please remove the use of this attribute at your earliest convenience.""".format(
                rule_label = str(rule_label),
            ),
        )
    return struct()

def apple_symbols_file_partial(
        *,
        include_symbols_in_bundle,
        rule_label):
    """Retired constructor for the Apple .symbols package processing partial.

    Args:
      include_symbols_in_bundle: Whether the partial should package in its bundle
        the .symbols files for this binary plus all binaries in `dependency_targets`. Currently only
        used to message that the feature is still enabled, and is not used to perform any actions.
      rule_label: The label of the rule being processed, used for warning messages.

    Returns:
      A partial that warns that the `include_symbols_in_bundle` attribute is a no-op, if it is used.
    """
    return partial.make(
        _apple_symbols_file_partial_impl,
        include_symbols_in_bundle = include_symbols_in_bundle,
        rule_label = rule_label,
    )
