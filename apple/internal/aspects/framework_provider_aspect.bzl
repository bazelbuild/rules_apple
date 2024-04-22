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

"""Implementation of the aspect that propagates framework providers."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleFrameworkImportInfo",
    "apple_provider",
)

visibility("//apple/...")

# List of attributes through which the aspect propagates.
_FRAMEWORK_PROVIDERS_ASPECT_ATTRS = ["deps", "frameworks"]

def _framework_provider_aspect_impl(target, ctx):
    """Implementation of the framework provider propagation aspect."""
    if AppleFrameworkImportInfo in target:
        return []

    apple_framework_infos = []
    for attribute in _FRAMEWORK_PROVIDERS_ASPECT_ATTRS:
        if not hasattr(ctx.rule.attr, attribute):
            continue
        for dep_target in getattr(ctx.rule.attr, attribute):
            if AppleFrameworkImportInfo in dep_target:
                apple_framework_infos.append(dep_target[AppleFrameworkImportInfo])

    apple_framework_info = apple_provider.merge_apple_framework_import_info(apple_framework_infos)

    if (apple_framework_info.binary_imports or
        apple_framework_info.bundling_imports or
        apple_framework_info.signature_files):
        return [apple_framework_info]
    return []

framework_provider_aspect = aspect(
    implementation = _framework_provider_aspect_impl,
    attr_aspects = _FRAMEWORK_PROVIDERS_ASPECT_ATTRS,
    doc = """
Aspect that collects transitive `AppleFrameworkImportInfo` providers from non-Apple rules targets
(e.g. `objc_library` or `swift_library`) to be packaged within the top-level application bundle.

Supported framework and XCFramework rules are:

*   `apple_dynamic_framework_import`
*   `apple_dynamic_xcframework_import`
*   `apple_static_framework_import`
*   `apple_static_xcframework_import`
""",
)
