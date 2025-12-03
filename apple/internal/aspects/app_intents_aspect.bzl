# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Implementation of the aspect that propagates AppIntentsInfo providers."""

load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load("@build_bazel_rules_apple//apple/internal:cc_info_support.bzl", "cc_info_support")
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsHintInfo",
    "AppIntentsInfo",
)
load(
    "@build_bazel_rules_swift//swift:module_name.bzl",
    "derive_swift_module_name",
)
load(
    "@build_bazel_rules_swift//swift:providers.bzl",
    "SwiftInfo",
)

visibility("@build_bazel_rules_apple//apple/internal/...")

def _verify_app_intents_dependency(*, target):
    """Verifies that the target has a dependency on the AppIntents framework."""

    sdk_frameworks = cc_info_support.get_sdk_frameworks(deps = [target], include_weak = True)
    if "AppIntents" not in sdk_frameworks.to_list():
        fail(
            "Target '%s' does not depend on the AppIntents framework. " % target.label +
            "Instead found the following system frameworks: %s" % sdk_frameworks.to_list(),
        )

def _find_valid_module_name(*, label, target):
    """Verifies that the target has a single module name and returns it.

    Args:
        label: The label of the target.
        target: The target to find the module name for.

    Returns:
        The module name of the target, if one can be found. If not, or if multiple were found, raise
        a user-actionable error.
    """
    module_names = collections.uniq([x.name for x in target[SwiftInfo].direct_modules if x.swift])
    if not module_names:
        module_names = [derive_swift_module_name(label)]

    if len(module_names) > 1:
        fail("""
Found the following module names in the swift_library target {label} defining App Intents: \
{intents_module_names}

App Intents must have only one module name for metadata generation to work correctly.
""".format(
            module_names = ", ".join(module_names),
            label = str(label),
        ))
    elif len(module_names) == 0:
        fail("""
Could not find a module name for the swift_library target {label}. One is required for App Intents \
metadata generation.
""".format(
            label = str(label),
        ))
    return module_names[0]

def _generate_metadata_bundle_inputs(
        *,
        direct_app_intents_modules,
        files,
        is_static_metadata,
        label,
        module_name,
        target):
    """Helper to generate the metadata bundle inputs struct for the AppIntentsInfo provider.

    Args:
        direct_app_intents_modules: The direct module dependencies with other App Intents hinted
            modules that were found on this target.
        files: The files from the rule being evaluated by the aspect.
        is_static_metadata: Whether the target provides static metadata App Intents, rather than act
            as a "main" metadata App Intents target owned exclusively by a single bundle rule.
        label: The label of the target.
        module_name: The module name of the target.
        target: The target to generate the metadata bundle inputs for.

    Returns:
        A struct containing the metadata bundle inputs assuming that the inputs represent a direct
        dependency for the AppIntentsInfo provider.
    """
    return struct(
        direct_app_intents_modules = direct_app_intents_modules,
        module_name = module_name,
        is_static_metadata = is_static_metadata,
        owner = str(label),
        swift_source_files = [f for f in files.srcs if f.extension == "swift"],
        swiftconstvalues_files = target[OutputGroupInfo]["const_values"].to_list(),
    )

def _legacy_app_intents_aspect_impl(target, ctx):
    """Legacy implementation of the App Intents aspect to support `app_intents` bundle attrs."""

    if ctx.rule.kind != "swift_library":
        return []

    _verify_app_intents_dependency(target = target)

    label = ctx.label
    module_name = _find_valid_module_name(label = label, target = target)

    return [
        AppIntentsInfo(
            metadata_bundle_inputs = depset(
                [
                    _generate_metadata_bundle_inputs(
                        direct_app_intents_modules = [],
                        files = ctx.rule.files,
                        is_static_metadata = False,
                        label = label,
                        module_name = module_name,
                        target = target,
                    ),
                ],
                order = "postorder",
            ),
        ),
    ]

legacy_app_intents_aspect = aspect(
    implementation = _legacy_app_intents_aspect_impl,
    doc = "Collects App Intents metadata dependencies from a single swift_library target.",
)

_APP_INTENTS_ATTR_ASPECTS = ["deps", "private_deps"]

def _app_intents_hint_info(aspect_hints):
    """Returns the AppIntentsHintInfo if the target has an AppIntentsHintInfo provider."""
    app_intents_hint_target = None
    for hint in aspect_hints:
        if AppIntentsHintInfo in hint:
            if app_intents_hint_target:
                fail(("Conflicting App Intents hint info from aspect hints " +
                      "'{hint1}' and '{hint2}'. Only one is allowed.").format(
                    hint1 = str(app_intents_hint_target.label),
                    hint2 = str(hint.label),
                ))
            app_intents_hint_target = hint
    return app_intents_hint_target[AppIntentsHintInfo] if app_intents_hint_target else None

def _app_intents_aspect_impl(target, ctx):
    """Implementation of the App Intents aspect for transitive App Intents processing."""

    app_intents_hint_info = None
    if SwiftInfo in target:
        app_intents_hint_info = _app_intents_hint_info(ctx.rule.attr.aspect_hints)

    transitive_metadata_bundle_inputs = []

    direct_app_intents_modules = []

    # Identify all of the transitive App IntentsInfo providers from the expected attributes.
    for attr in _APP_INTENTS_ATTR_ASPECTS:
        for deps_target in getattr(ctx.rule.attr, attr, []):
            if AppIntentsInfo not in deps_target:
                continue
            app_intents_info = deps_target[AppIntentsInfo]

            # Collect all of the transitive dependencies to forward in the provider.
            transitive_metadata_bundle_inputs.append(
                app_intents_info.metadata_bundle_inputs,
            )

            # Don't collect direct module dependencies if this target doesn't define App Intents.
            if not app_intents_hint_info:
                continue

            # Collect all of the direct module dependencies to establish dependencies for bundles.
            if SwiftInfo not in deps_target:
                continue
            direct_swift_module_names = [
                x.name
                for x in deps_target[SwiftInfo].direct_modules
                if x.swift
            ]
            direct_app_intents_modules.extend([
                metadata_bundle_input.module_name
                for metadata_bundle_input in app_intents_info.metadata_bundle_inputs.to_list()
                if metadata_bundle_input.module_name in direct_swift_module_names
            ])

    # If this target is a swift_library with the App Intents hint, verify it's correct and generate
    # a provider to define required dependencies to generate a metadata bundle for this target.
    if app_intents_hint_info:
        _verify_app_intents_dependency(target = target)
        label = ctx.label
        module_name = _find_valid_module_name(label = label, target = target)
        direct_metadata_bundle_input = _generate_metadata_bundle_inputs(
            direct_app_intents_modules = direct_app_intents_modules,
            files = ctx.rule.files,
            is_static_metadata = app_intents_hint_info.static_metadata,
            label = label,
            module_name = module_name,
            target = target,
        )
        return [AppIntentsInfo(
            metadata_bundle_inputs = depset(
                [direct_metadata_bundle_input],
                transitive = transitive_metadata_bundle_inputs,
                order = "postorder",
            ),
        )]

    # If we only have transitive inputs, propagate them up the graph.
    if transitive_metadata_bundle_inputs:
        return [AppIntentsInfo(
            metadata_bundle_inputs = depset(
                transitive = transitive_metadata_bundle_inputs,
                order = "postorder",
            ),
        )]

    return []

app_intents_aspect = aspect(
    implementation = _app_intents_aspect_impl,
    attr_aspects = _APP_INTENTS_ATTR_ASPECTS,
    doc = "Collects App Intents metadata dependencies from swift_library targets.",
)
