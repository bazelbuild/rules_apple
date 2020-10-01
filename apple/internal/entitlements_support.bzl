# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Entitlements support."""

load(
    "@build_bazel_rules_apple//apple/internal:entitlement_rules.bzl",
    "AppleEntitlementsInfo",
)

def _entitlements(*, entitlements_attr, entitlements_file):
    """Returns the entitlements file to be used for codesigning.

    This returns the entitlements from the internal provider if it's present to support rules that
    manipulate them before passing them to the bundler. Otherwise, it will return the entitlements
    from the file that was provided instead.

    Args:
        entitlements_attr: Attribute for the entitlements provider. Typically from
            `ctx.attr.entitlements`.
        entitlements_file: File for the entitlements of this target. Typically from
            `ctx.file.entitlements`.

    Returns:
        The preferred entitlements file for codesigning between all given sources.
    """
    if entitlements_attr:
        if AppleEntitlementsInfo in entitlements_attr:
            return entitlements_attr[AppleEntitlementsInfo].final_entitlements
        return entitlements_file
    return None

entitlements_support = struct(
    entitlements = _entitlements,
)
