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
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleInfo",
    "AppleDsymBundleInfo",
    "AppleFrameworkBundleInfo",
    "AppleLinkmapInfo",
    "AppleRunfilesInfo",
    "merge_apple_framework_import_info",
    "new_appledsymbundleinfo",
    "new_applelinkmapinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_validation_info.bzl",
    "AppleResourceValidationInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:embedded_framework_bundle_info.bzl",
    "AppleEmbeddedFrameworkBundleInfo",
)

ADDITIONAL_QUALIFIED_KINDS = {}
ADDITIONAL_PROPAGATION_ATTRS = {}
FRAMEWORK_RESOURCE_ALLOWLIST = {}

visibility([
    "@build_bazel_rules_apple//apple/...",
])

# List of attributes through which the aspect propagates by default.
_DEFAULT_FRAMEWORK_ASPECT_ATTRS = [
    # keep sorted
    "deps",
    "frameworks",
    "implementation_deps",
]

_FRAMEWORK_RESOURCES_ALLOWLIST_VALUES = set([
    framework
    for frameworks in FRAMEWORK_RESOURCE_ALLOWLIST.values()
    for framework in frameworks
])

_OBJC_LIBRARY_ATTRS = [
    # keep sorted
    "data",
    "deps",
    "implementation_deps",
]

_SUPPORTED_QUALIFIED_KINDS = ADDITIONAL_QUALIFIED_KINDS
_SUPPORTED_QUALIFIED_KINDS_PROPAGATION_ATTRS = ADDITIONAL_PROPAGATION_ATTRS

def _propagation_attrs(ctx):
    """Returns the set of attributes to propagate for the framework provider aspect."""
    if hasattr(ctx.rule, "qualified_kind"):
        qualified_kind = ctx.rule.qualified_kind
        expected_label = _SUPPORTED_QUALIFIED_KINDS.get(qualified_kind.rule_name)
        if expected_label and qualified_kind.file_label == expected_label:
            return _SUPPORTED_QUALIFIED_KINDS_PROPAGATION_ATTRS[qualified_kind.rule_name]
        rule_name = qualified_kind.rule_name
    else:
        rule_name = ctx.rule.kind
        if rule_name in _SUPPORTED_QUALIFIED_KINDS_PROPAGATION_ATTRS:
            return _SUPPORTED_QUALIFIED_KINDS_PROPAGATION_ATTRS[rule_name]

    # Targeted propagation scoping for library rules referencing runtime frameworks.
    if rule_name == "objc_library":
        return _OBJC_LIBRARY_ATTRS

    # Always support the standard set of deps-like attributes for framework propagation.
    return _DEFAULT_FRAMEWORK_ASPECT_ATTRS

def _validate_runtime_framework(*, dep_target, from_source_target, rule_kind, rule_label):
    """Validates that a framework referenced outside the 'frameworks' attribute is permitted."""

    if AppIntentsBundleInfo in dep_target:
        fail("An App Intents metadata bundle was found in the following " +
             "framework that is not directly loaded by an app/extension:\n\n" +
             "- {framework_target}\n\n" +
             "This was loaded by the following library target:\n\n" +
             "- {loading_target}\n\n" +
             "App Intents are not supported within frameworks that aren't " +
             "directly loaded by an app/extension.".format(
                 loading_target = str(rule_label),
                 framework_target = str(dep_target.label),
             ))
    if AppleRunfilesInfo in dep_target:
        fail((
            "Target '{parent}' of kind '{kind}' includes '{dep}', which " +
            "provides AppleRunfilesInfo. apple_runfiles_data targets are not " +
            "supported within frameworks that aren't directly loaded by a " +
            "test or app target."
        ).format(
            dep = str(dep_target.label),
            kind = rule_kind,
            parent = str(rule_label),
        ))

def _framework_provider_aspect_impl(target, ctx):
    """Implementation of the framework provider propagation aspect."""
    if AppleFrameworkImportInfo in target:
        return []

    apple_framework_infos = []
    apple_embedded_framework_infos = []
    apple_resource_validation_infos = []
    apple_dsym_bundle_infos = []
    apple_linkmap_infos = []

    for attribute in _propagation_attrs(ctx):
        if not hasattr(ctx.rule.attr, attribute):
            continue
        targets = getattr(ctx.rule.attr, attribute)
        if not targets:
            continue
        for dep_target in targets:
            if AppleFrameworkBundleInfo in dep_target and attribute != "frameworks":
                # Framework from data/resources using the fragile objc_library API.
                _validate_runtime_framework(
                    dep_target = dep_target,
                    from_source_target = False,
                    rule_kind = ctx.rule.kind,
                    rule_label = ctx.label,
                )

            if AppleEmbeddedFrameworkBundleInfo in dep_target:
                apple_embedded_framework_infos.append(
                    dep_target[AppleEmbeddedFrameworkBundleInfo],
                )
            if AppleResourceValidationInfo in dep_target:
                apple_resource_validation_infos.append(
                    dep_target[AppleResourceValidationInfo],
                )
            if AppleFrameworkImportInfo in dep_target:
                apple_framework_infos.append(dep_target[AppleFrameworkImportInfo])
            if AppleDsymBundleInfo in dep_target:
                apple_dsym_bundle_infos.append(dep_target[AppleDsymBundleInfo])
            if AppleLinkmapInfo in dep_target:
                apple_linkmap_infos.append(dep_target[AppleLinkmapInfo])

    providers = []

    if AppleFrameworkBundleInfo in target:
        if AppleEmbeddedFrameworkBundleInfo not in target:
            # Framework from data/resources using the fragile objc_library API.
            _validate_runtime_framework(
                dep_target = target,
                from_source_target = True,
                rule_kind = ctx.rule.kind,
                rule_label = ctx.label,
            )
            apple_embedded_framework_infos.append(
                AppleEmbeddedFrameworkBundleInfo(
                    frameworks = depset([
                        f
                        for f in target[DefaultInfo].files.to_list()
                        # Never ever bundle dSYMs or linkmaps since they should never, ever belong
                        # in processing "files". This goes for any "framework" outputs that do not
                        # belong in the shipping framework bundle itself.
                        if not f.basename.endswith(".dSYM") and f.extension != "linkmap"
                    ]),
                    signed_frameworks = depset(),
                ),
            )
        if AppleBundleInfo in target:
            target_apple_bundle_info = struct(
                apple_bundle_info = target[AppleBundleInfo],
                target_label = str(target.label),
            )
            apple_resource_validation_infos.append(
                AppleResourceValidationInfo(
                    direct_target_bundle_infos = [target_apple_bundle_info],
                    transitive_target_bundle_infos = depset([target_apple_bundle_info]),
                ),
            )

    if AppleFrameworkImportInfo not in target:
        apple_framework_info = merge_apple_framework_import_info(apple_framework_infos)
        if (apple_framework_info.binary_imports or
            apple_framework_info.bundling_imports or
            apple_framework_info.signature_files or
            apple_framework_info.stub_binary_imports):
            providers.append(apple_framework_info)

    if AppleEmbeddedFrameworkBundleInfo not in target and apple_embedded_framework_infos:
        framework_depsets = [
            x.frameworks
            for x in apple_embedded_framework_infos
            if hasattr(x, "frameworks") and x.frameworks
        ]
        signed_framework_depsets = [
            x.signed_frameworks
            for x in apple_embedded_framework_infos
            if hasattr(x, "signed_frameworks") and x.signed_frameworks
        ]
        if framework_depsets or signed_framework_depsets:
            providers.append(
                AppleEmbeddedFrameworkBundleInfo(
                    frameworks = depset(transitive = framework_depsets),
                    signed_frameworks = depset(transitive = signed_framework_depsets),
                ),
            )

    if AppleResourceValidationInfo not in target and apple_resource_validation_infos:
        providers.append(
            AppleResourceValidationInfo(
                direct_target_bundle_infos = [],
                transitive_target_bundle_infos = depset(
                    transitive = [
                        x.transitive_target_bundle_infos
                        for x in apple_resource_validation_infos
                    ],
                ),
            ),
        )

    if AppleDsymBundleInfo not in target and apple_dsym_bundle_infos:
        providers.append(
            new_appledsymbundleinfo(
                direct_dsyms = [],
                transitive_dsyms = depset(
                    transitive = [x.transitive_dsyms for x in apple_dsym_bundle_infos],
                ),
            ),
        )

    if AppleLinkmapInfo not in target and apple_linkmap_infos:
        providers.append(
            new_applelinkmapinfo(
                direct_linkmaps = [],
                transitive_linkmaps = depset(
                    transitive = [x.transitive_linkmaps for x in apple_linkmap_infos],
                ),
            ),
        )

    return providers

framework_provider_aspect = aspect(
    implementation = _framework_provider_aspect_impl,
    attr_aspects = _propagation_attrs,
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
