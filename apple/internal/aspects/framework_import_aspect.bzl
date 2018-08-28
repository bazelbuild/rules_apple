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

AppleFrameworkImportInfo = provider(
    doc = "Provider that propagates information about framework import targets.",
    fields = {
        "framework_imports": """
Depset of Files that represent framework imports that need to be bundled in the top level
application bundle under the Frameworks directory.
""",
    },
)

def _framework_import_aspect_impl(target, ctx):
    """Implementation of the framework import propagation aspect."""
    if AppleFrameworkImportInfo in target:
        return []

    transitive_sets = []
    for attribute in ["deps", "frameworks"]:
        if not hasattr(ctx.rule.attr, attribute):
            continue
        for dep_target in getattr(ctx.rule.attr, attribute):
            if AppleFrameworkImportInfo in dep_target:
                transitive_sets.append(dep_target[AppleFrameworkImportInfo].framework_imports)

    if (ctx.rule.kind == "objc_framework" and
        ctx.rule.attr.is_dynamic and
        ctx.rule.attr.framework_imports):
        framework_imports = []
        for file_target in ctx.rule.attr.framework_imports:
            for file in file_target.files.to_list():
                file_short_path = file.short_path
                if file_short_path.endswith(".h"):
                    continue
                if file_short_path.endswith(".modulemap"):
                    continue
                if "Headers/" in file_short_path:
                    # This matches /Headers/ and /PrivateHeaders/
                    continue
                if "/Modules/" in file_short_path:
                    continue
                framework_imports.append(file)

        if framework_imports:
            transitive_sets.append(depset(framework_imports))

    if not transitive_sets:
        return []

    return [AppleFrameworkImportInfo(framework_imports = depset(transitive = transitive_sets))]

framework_import_aspect = aspect(
    implementation = _framework_import_aspect_impl,
    attr_aspects = ["deps", "frameworks"],
    doc = """
Aspect that collects all files from framework import targets (e.g. objc_framework) so that they can
be packaged within the top-level application bundle.
""",
)
