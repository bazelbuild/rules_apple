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

"""Implementation of the aspect that propagates SwiftConstValuesInfo providers."""

load(
    "@build_bazel_rules_apple//apple/hints:app_extension_point_hint.bzl",
    "AppExtensionPointHintInfo",
)
load(
    "@build_bazel_rules_apple//apple/hints:extension_foundation_hint.bzl",
    "ExtensionFoundationHintInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:cc_info_support.bzl",
    "cc_info_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_extension_point_info.bzl",
    "AppExtensionPointInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsHintInfo",
    "AppIntentsInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:extension_foundation_info.bzl",
    "ExtensionFoundationInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_swift//swift:providers.bzl",
    "SwiftInfo",
)

visibility([
    "@build_bazel_rules_apple//apple/internal/...",
])

_SUPPORTED_FRAMEWORKS = [
    "AppIntents",
    "ExtensionFoundation",
]

def _verify_swift_const_values_dependency(*, target):
    """Verifies that the target has a dependency on a supported framework."""
    sdk_frameworks = cc_info_support.get_sdk_frameworks(
        deps = [target],
        include_weak = True,
    ).to_list()
    if set(sdk_frameworks).isdisjoint(_SUPPORTED_FRAMEWORKS):
        fail("""
Target '{target_label}' does not depend on any of the supported frameworks for Swift const values \
generation: {supported_frameworks}

Instead it depends on the following system frameworks:
{sdk_frameworks}

Swift const values generation requires a dependency on at least one supported framework.
""".format(
            target_label = target.label,
            sdk_frameworks = ", ".join(sdk_frameworks),
            supported_frameworks = ", ".join(_SUPPORTED_FRAMEWORKS),
        ))

def _find_valid_module_name(*, label, target):
    """Verifies that the target has a single module name and returns it.

    Args:
        label: The label of the target.
        target: The target to find the module name for.

    Returns:
        The module name of the target, if one can be found. If not, or if multiple were found, raise
        a user-actionable error.
    """
    module_names = set([x.name for x in target[SwiftInfo].direct_modules if x.swift])
    if len(module_names) > 1:
        # TODO(b/427503530): This should allow for choosing client error messaging between App
        # Intents vs ExtensionFoundation.
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
    return module_names.pop()

def _generate_metadata_bundle_inputs(
        *,
        direct_app_intents_modules,
        files,
        framework_typename_file,
        is_static_metadata,
        label,
        module_name,
        target):
    """Helper to generate the metadata bundle inputs struct for the SwiftConstValuesInfo provider.

    Args:
        direct_app_intents_modules: The direct module dependencies with other App Intents hinted
            modules that were found on this target.
        files: The files from the rule being evaluated by the aspect.
        framework_typename_file: File handle to the validated framework typename output for this
            target.
        is_static_metadata: Whether the target provides static metadata App Intents, rather than act
            as a "main" metadata App Intents target owned exclusively by a single bundle rule.
        label: The label of the target.
        module_name: The module name of the target.
        target: The target to generate the metadata bundle inputs for.

    Returns:
        A struct containing the metadata bundle inputs assuming that the inputs represent a direct
        dependency for the SwiftConstValuesInfo provider.
    """
    return struct(
        direct_app_intents_modules = direct_app_intents_modules,
        framework_typename_file = framework_typename_file,
        module_name = module_name,
        is_static_metadata = is_static_metadata,
        owner = str(label),
        swift_source_files = [f for f in files.srcs if f.extension == "swift"],
        swiftconstvalues_files = getattr(
            target[OutputGroupInfo],
            "const_values",
            depset(),
        ).to_list() if OutputGroupInfo in target else [],
    )

_SWIFT_CONST_VALUES_ASPECT_ATTRS = [
    # keep sorted
    "deps",
    "implementation_deps",
    "private_deps",
]

def _validate_swift_const_values_aspect_hints(
        *,
        actions,
        has_aspect_hint,
        const_values,
        hint_protocols,
        swift_const_values_validation_tool,
        target_label,
        xplat_exec_group,
        conformance,
        mnemonic,
        suffix):
    framework_typename_file = actions.declare_file(
        "%s_%s.txt" % (target_label.name, suffix),
    )

    swiftconstvalues_files = const_values.to_list()
    validation_inputs = list(swiftconstvalues_files)

    args = actions.args()
    args.add("check-aspect-hints")
    for f in swiftconstvalues_files:
        args.add("--swiftconstvalues-file", f)
    args.add("--output-path", framework_typename_file)

    for protocol in hint_protocols:
        args.add("--hint-protocol", protocol)

    args.add("--required-conformance", conformance)

    if has_aspect_hint:
        args.add("--has-aspect-hint")

    actions.run(
        executable = swift_const_values_validation_tool,
        arguments = [args],
        inputs = validation_inputs,
        outputs = [framework_typename_file],
        exec_group = xplat_exec_group,
        mnemonic = mnemonic,
        progress_message = (
            "Validating aspect hint for {target_label} ({mnemonic})".format(
                target_label = target_label,
                mnemonic = mnemonic,
            )
        ),
    )

    return framework_typename_file

def _swift_const_values_hint_info(aspect_hints, provider_type, hint_name):
    """Returns the requested hint provider if it exists, ensuring no duplicates."""
    hint_target = None
    for hint in aspect_hints:
        if provider_type in hint:
            if hint_target:
                fail(("Conflicting {hint_name} from aspect hints " +
                      "'{hint1}' and '{hint2}'. Only one is allowed.").format(
                    hint_name = hint_name,
                    hint1 = str(hint_target.label),
                    hint2 = str(hint.label),
                ))
            hint_target = hint
    return hint_target[provider_type] if hint_target else None

def _swift_const_values_aspect_impl(target, ctx):
    """Implementation of the App Intents aspect for transitive metadata processing."""

    app_intents_hint = None
    extension_foundation_hint = None
    app_extension_point_hint = None
    validation_outputs = []
    framework_typename_file = None
    const_values = None

    if SwiftInfo in target:
        aspect_hints = ctx.rule.attr.aspect_hints
        app_intents_hint = _swift_const_values_hint_info(
            aspect_hints,
            AppIntentsHintInfo,
            "App Intents hint info",
        )
        extension_foundation_hint = _swift_const_values_hint_info(
            aspect_hints,
            ExtensionFoundationHintInfo,
            "Extension Foundation hint info",
        )
        app_extension_point_hint = _swift_const_values_hint_info(
            aspect_hints,
            AppExtensionPointHintInfo,
            "App Extension Point hint info",
        )

        if app_intents_hint or extension_foundation_hint or app_extension_point_hint:
            _verify_swift_const_values_dependency(target = target)

        const_values = None
        if OutputGroupInfo in target:
            const_values = getattr(target[OutputGroupInfo], "const_values", None)

        apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
        if const_values:
            app_intents_protocols = []
            if apple_xplat_toolchain_info.build_settings.validate_app_intents:
                for module in ctx.attr._app_intents_sdk_module[SwiftInfo].direct_modules:
                    if module.name == "AppIntents" and module.const_gather_protocols:
                        app_intents_protocols.extend(
                            ["AppIntents." + p for p in module.const_gather_protocols],
                        )
                        break

            if app_intents_protocols:
                framework_typename_file = _validate_swift_const_values_aspect_hints(
                    actions = ctx.actions,
                    has_aspect_hint = app_intents_hint != None,
                    const_values = const_values,
                    hint_protocols = app_intents_protocols,
                    swift_const_values_validation_tool = (
                        apple_xplat_toolchain_info.swift_const_values_validation_tool
                    ),
                    target_label = target.label,
                    xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx),
                    conformance = "AppIntents.AppIntentsPackage",
                    mnemonic = "AppIntentsValidation",
                    suffix = "app_intents_validation",
                )
                validation_outputs.append(framework_typename_file)

            extension_foundation_protocols = []
            for module in ctx.attr._extension_foundation_sdk_module[SwiftInfo].direct_modules:
                if module.name == "ExtensionFoundation" and module.const_gather_protocols:
                    extension_foundation_protocols.extend(
                        ["ExtensionFoundation." + p for p in module.const_gather_protocols],
                    )
                    break

            if extension_foundation_protocols:
                extension_foundation_typename_file = _validate_swift_const_values_aspect_hints(
                    actions = ctx.actions,
                    has_aspect_hint = (
                        extension_foundation_hint != None
                    ) or (
                        app_extension_point_hint != None
                    ),
                    const_values = const_values,
                    hint_protocols = extension_foundation_protocols,
                    swift_const_values_validation_tool = (
                        apple_xplat_toolchain_info.swift_const_values_validation_tool
                    ),
                    target_label = target.label,
                    xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx),
                    conformance = "ExtensionFoundation.AppExtension",
                    mnemonic = "ExtensionFoundationValidation",
                    suffix = "extension_foundation_validation",
                )
                validation_outputs.append(extension_foundation_typename_file)

    transitive_metadata_bundle_inputs = []
    transitive_extension_foundation = []
    transitive_app_extension_point = []

    direct_app_intents_modules = []

    # Identify all of the transitive providers from the expected attributes.
    for attr in _SWIFT_CONST_VALUES_ASPECT_ATTRS:
        for deps_target in getattr(ctx.rule.attr, attr, []):
            if AppIntentsInfo in deps_target:
                app_intents_info = deps_target[AppIntentsInfo]
                transitive_metadata_bundle_inputs.append(app_intents_info.metadata_bundle_inputs)

                # Don't collect direct module dependencies if the target doesn't define App Intents.
                if app_intents_hint and SwiftInfo in deps_target:
                    direct_swift_module_names = [
                        x.name
                        for x in deps_target[SwiftInfo].direct_modules
                        if x.swift
                    ]
                    metadata_bundle_inputs = app_intents_info.metadata_bundle_inputs.to_list()
                    direct_app_intents_modules.extend([
                        metadata_bundle_input.module_name
                        for metadata_bundle_input in metadata_bundle_inputs
                        if metadata_bundle_input.module_name in direct_swift_module_names
                    ])
            if ExtensionFoundationInfo in deps_target:
                transitive_extension_foundation.append(
                    deps_target[ExtensionFoundationInfo].swiftconstvalues_files,
                )
            if AppExtensionPointInfo in deps_target:
                transitive_app_extension_point.append(
                    deps_target[AppExtensionPointInfo].extension_points,
                )

    providers = []
    if app_intents_hint:
        label = ctx.label
        module_name = _find_valid_module_name(label = label, target = target)
        direct_metadata_bundle_input = _generate_metadata_bundle_inputs(
            direct_app_intents_modules = direct_app_intents_modules,
            files = ctx.rule.files,
            framework_typename_file = framework_typename_file,
            is_static_metadata = app_intents_hint.static_metadata,
            label = label,
            module_name = module_name,
            target = target,
        )
        providers.append(AppIntentsInfo(
            metadata_bundle_inputs = depset(
                [direct_metadata_bundle_input],
                transitive = transitive_metadata_bundle_inputs,
                order = "postorder",
            ),
        ))
    elif transitive_metadata_bundle_inputs:
        providers.append(AppIntentsInfo(
            metadata_bundle_inputs = depset(
                transitive = transitive_metadata_bundle_inputs,
                order = "postorder",
            ),
        ))

    direct_extension_foundation = []
    if extension_foundation_hint:
        if const_values:
            direct_extension_foundation.append(const_values)

    if direct_extension_foundation or transitive_extension_foundation:
        providers.append(ExtensionFoundationInfo(
            swiftconstvalues_files = depset(
                transitive = direct_extension_foundation + transitive_extension_foundation,
                order = "postorder",
            ),
        ))

    direct_app_extension_point = []
    if app_extension_point_hint:
        label = ctx.label
        module_name = _find_valid_module_name(label = label, target = target)
        if const_values:
            direct_app_extension_point.append(struct(
                module_name = module_name,
                swiftconstvalues_files = const_values,
                owner = str(label),
            ))

    if direct_app_extension_point or transitive_app_extension_point:
        providers.append(AppExtensionPointInfo(
            extension_points = depset(
                direct_app_extension_point,
                transitive = transitive_app_extension_point,
                order = "postorder",
            ),
        ))

    if validation_outputs:
        providers.append(OutputGroupInfo(_validation = depset(validation_outputs)))

    return providers

swift_const_values_aspect = aspect(
    implementation = _swift_const_values_aspect_impl,
    attr_aspects = _SWIFT_CONST_VALUES_ASPECT_ATTRS,
    attrs = {
    },
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    required_aspect_hints_providers = [
        [AppExtensionPointHintInfo],
        [AppIntentsHintInfo],
        [ExtensionFoundationHintInfo],
    ],
    doc = "Collects App Intents metadata dependencies from swift_library targets.",
)
