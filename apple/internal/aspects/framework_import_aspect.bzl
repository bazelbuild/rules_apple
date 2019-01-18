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

"""Implementation of the aspect that propagates framework import files."""

load(
    "@build_bazel_rules_apple//apple/internal:apple_framework_import.bzl",
    "AppleFrameworkImportInfo",
)

# List of attributes through which the aspect propagates. We include `runtime_deps` here as
# these are supported by `objc_library` for frameworks that should be present in the bundle, but not
# linked against.
# TODO(b/120205406): Migrate the `runtime_deps` use case to be referenced through `data` instead.
_FRAMEWORK_IMPORT_ASPECT_ATTRS = ["deps", "frameworks", "runtime_deps"]

def _framework_import_aspect_impl(target, ctx):
    """Implementation of the framework import propagation aspect."""
    if AppleFrameworkImportInfo in target:
        return []

    transitive_sets = []
    for attribute in _FRAMEWORK_IMPORT_ASPECT_ATTRS:
        if not hasattr(ctx.rule.attr, attribute):
            continue
        for dep_target in getattr(ctx.rule.attr, attribute):
            if AppleFrameworkImportInfo in dep_target:
                if hasattr(dep_target[AppleFrameworkImportInfo], "framework_imports"):
                    transitive_sets.append(dep_target[AppleFrameworkImportInfo].framework_imports)

    if not transitive_sets:
        return []

    return [AppleFrameworkImportInfo(framework_imports = depset(transitive = transitive_sets))]

framework_import_aspect = aspect(
    implementation = _framework_import_aspect_impl,
    attr_aspects = _FRAMEWORK_IMPORT_ASPECT_ATTRS,
    doc = """
Aspect that collects all files from framework import targets (e.g. objc_framework) so that they can
be packaged within the top-level application bundle.
""",
)
