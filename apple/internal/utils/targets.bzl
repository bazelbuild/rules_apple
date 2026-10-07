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

def _target_set(*attrs, first_split_only = False):
    """Produces a set of targets from one or more attributes or target collections.

    Args:
        *attrs: Attribute values that can be lists, sets, dicts, or single
            targets representing target dependencies (e.g., `ctx.attr.deps` or
            `ctx.split_attr.deps`).
        first_split_only: If True and an attribute is a `split_attr` dictionary,
            only targets from the first split key are returned.

    Returns:
        A set of deduplicated non-None targets.
    """
    target_list = []
    for attr in attrs:
        if not attr:
            continue
        attr_type = type(attr)
        if attr_type == "dict":
            split_values = attr.values()[:1] if first_split_only else attr.values()
            for split_value in split_values:
                if not split_value:
                    continue
                if type(split_value) == "list":
                    target_list.extend([x for x in split_value if x])
                else:
                    target_list.append(split_value)
        elif attr_type in ("list", "set", "tuple"):
            target_list.extend([x for x in attr if x])
        else:
            target_list.append(attr)
    return set(target_list)

def _providers(attr, provider, *, first_split_only = False):
    """Extracts a list of providers of the given type from an attribute or target collection.

    Args:
        attr: An attribute value that can be a list, set, dict, or single target
            representing target dependencies.
        provider: The provider type to extract from the targets.
        first_split_only: If True and `attr` is a `split_attr` dictionary, only
            providers from the first split key are returned.

    Returns:
        A list of providers of type `provider` found on the targets in `attr`.
    """
    return [
        target[provider]
        for target in _target_set(attr, first_split_only = first_split_only)
        if provider in target
    ]

targets = struct(
    providers = _providers,
    target_set = _target_set,
)
