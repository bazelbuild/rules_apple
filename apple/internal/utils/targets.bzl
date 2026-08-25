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

"""Utility functions for handling target attributes and dependencies."""

visibility("@build_bazel_rules_apple//apple/internal/...")

def _target_set(attr):
    """Produces a set of targets from an attribute.

    Args:
        attr: An attribute value that can be a list, dict, or nested structure
            representing target dependencies (e.g., `ctx.attr.deps` or
            `ctx.split_attr.deps`).

    Returns:
        A set of deduplicated targets.
    """
    if not attr:
        return set()

    if type(attr) == "dict":
        return set(attr.values())
    elif type(attr) == "list":
        return set(attr)
    return set(attr)

targets = struct(
    target_set = _target_set,
)
