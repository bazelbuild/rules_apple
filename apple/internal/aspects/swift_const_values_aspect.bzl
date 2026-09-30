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

_SWIFT_CONST_VALUES_ASPECT_ATTRS = [
    # keep sorted
    "deps",
    "implementation_deps",
    "private_deps",
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

def _swift_module_names(target):
    """Returns the set of Swift module names directly provided by the given target."""
    return set([x.name for x in target[SwiftInfo].direct_modules if x.swift])

def _find_valid_module_name(*, api_names, target):
    """Verifies that the target has a single Swift module name and returns it.

    Args:
        api_names: A list of user-facing names of the APIs (e.g. "App Intents",
            "ExtensionFoundation") whose metadata generation requires the module name. Used to
            provide accurate, user-actionable error messages.
        target: The target to find the module name for.

    Returns:
        The module name of the target, if one can be found. If not, or if multiple were found, raise
        a user-actionable error.
    """
    module_names = _swift_module_names(target)
    if len(module_names) == 1:
        return module_names.pop()

    apis = " and ".join(api_names)
    if module_names:
        fail("""
Found the following module names in the swift_library target {label} defining {apis}: \
{module_names}

{apis} must have only one module name for metadata generation to work correctly.
""".format(
            apis = apis,
            label = str(target.label),
            module_names = ", ".join(sorted(module_names)),
        ))
    fail("""
Could not find a module name for the swift_library target {label}. One is required for {apis} \
metadata generation.
""".format(
        apis = apis,
        label = str(target.label),
    ))

def _hint_info(*, aspect_hints, hint_name, provider):
    """Returns the requested hint provider if it exists, ensuring no duplicates."""
    hint_target = None
    for hint in aspect_hints:
        if provider in hint:
            if hint_target:
                fail((
                    "Conflicting {hint_name} from aspect hints '{hint1}' and '{hint2}'. " +
                    "Only one is allowed."
                ).format(
                    hint_name = hint_name,
                    hint1 = str(hint_target.label),
                    hint2 = str(hint.label),
                ))
            hint_target = hint
    return hint_target[provider] if hint_target else None

def _const_gather_protocols(*, framework_name, sdk_module_target):
    """Returns the fully qualified const gather protocols vended by an SDK framework's module.

    Args:
        framework_name: The name of the SDK framework (and its Swift module), e.g. "AppIntents".
        sdk_module_target: The target providing the SwiftInfo for the SDK framework.

    Returns:
        A list of protocol names qualified by the framework name, or an empty list if the framework
        does not declare any const gather protocols.
    """
    for module in sdk_module_target[SwiftInfo].direct_modules:
        if module.name == framework_name and module.const_gather_protocols:
            return [
                "{}.{}".format(framework_name, protocol)
                for protocol in module.const_gather_protocols
            ]
    return []

def _validate_aspect_hints(
        *,
        actions,
        const_values,
        has_aspect_hint,
        hint_protocols,
        mnemonic,
        output_suffix,
        required_conformance,
        target_label,
        xplat_toolchain_info):
    """Registers an action validating a target's aspect hints against its Swift const values.

    Args:
        actions: The actions object from the aspect context.
        const_values: A depset of the target's `.swiftconstvalues` files.
        has_aspect_hint: Whether the target has an aspect hint for the framework being validated.
        hint_protocols: The fully qualified const gather protocols of the framework being validated.
        mnemonic: The mnemonic for the validation action.
        output_suffix: The suffix of the validation action's output file name.
        required_conformance: The fully qualified protocol that a type must conform to for the
            target to require the aspect hint.
        target_label: The label of the target being validated.
        xplat_toolchain_info: The Apple cross-platform toolchain info provider.

    Returns:
        The File containing the validated framework typename output for this target.
    """
    framework_typename_file = actions.declare_file(
        "{}_{}.txt".format(target_label.name, output_suffix),
    )

    args = actions.args()
    args.add("check-aspect-hints")
    args.add_all(const_values, before_each = "--swiftconstvalues-file")
    args.add("--output-path", framework_typename_file)
    args.add_all(hint_protocols, before_each = "--hint-protocol")
    args.add("--required-conformance", required_conformance)
    if has_aspect_hint:
        args.add("--has-aspect-hint")

    actions.run(
        executable = xplat_toolchain_info.swift_const_values_validation_tool,
        arguments = [args],
        inputs = const_values,
        outputs = [framework_typename_file],
        exec_group = apple_toolchain_utils.get_xplat_exec_group(),
        mnemonic = mnemonic,
        progress_message = "Validating aspect hint for {} ({})".format(target_label, mnemonic),
    )

    return framework_typename_file

def _swift_const_values_aspect_impl(target, ctx):
    """Implementation of the Swift const values aspect for transitive metadata processing."""
    app_intents_hint = None
    extension_foundation_hint = None
    app_extension_point_hint = None
    const_values = None
    module_name = None
    app_intents_typename_file = None
    validation_outputs = []

    if SwiftInfo in target:
        aspect_hints = ctx.rule.attr.aspect_hints
        app_intents_hint = _hint_info(
            aspect_hints = aspect_hints,
            hint_name = "App Intents hint info",
            provider = AppIntentsHintInfo,
        )
        extension_foundation_hint = _hint_info(
            aspect_hints = aspect_hints,
            hint_name = "Extension Foundation hint info",
            provider = ExtensionFoundationHintInfo,
        )
        app_extension_point_hint = _hint_info(
            aspect_hints = aspect_hints,
            hint_name = "App Extension Point hint info",
            provider = AppExtensionPointHintInfo,
        )

        if app_intents_hint or extension_foundation_hint or app_extension_point_hint:
            _verify_swift_const_values_dependency(target = target)

        module_name_api_names = []
        if app_intents_hint:
            module_name_api_names.append("App Intents")
        if app_extension_point_hint:
            module_name_api_names.append("ExtensionFoundation")
        if module_name_api_names:
            module_name = _find_valid_module_name(
                api_names = module_name_api_names,
                target = target,
            )

        if OutputGroupInfo in target:
            const_values = getattr(target[OutputGroupInfo], "const_values", None)

        if const_values:
            xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)

            if xplat_toolchain_info.build_settings.validate_app_intents:
                app_intents_protocols = _const_gather_protocols(
                    framework_name = "AppIntents",
                    sdk_module_target = ctx.attr._app_intents_sdk_module,
                )
                if app_intents_protocols:
                    app_intents_typename_file = _validate_aspect_hints(
                        actions = ctx.actions,
                        const_values = const_values,
                        has_aspect_hint = app_intents_hint != None,
                        hint_protocols = app_intents_protocols,
                        mnemonic = "AppIntentsValidation",
                        output_suffix = "app_intents_validation",
                        required_conformance = "AppIntents.AppIntentsPackage",
                        target_label = target.label,
                        xplat_toolchain_info = xplat_toolchain_info,
                    )
                    validation_outputs.append(app_intents_typename_file)

            extension_foundation_protocols = _const_gather_protocols(
                framework_name = "ExtensionFoundation",
                sdk_module_target = ctx.attr._extension_foundation_sdk_module,
            )
            if extension_foundation_protocols:
                validation_outputs.append(_validate_aspect_hints(
                    actions = ctx.actions,
                    const_values = const_values,
                    has_aspect_hint = (
                        extension_foundation_hint != None or app_extension_point_hint != None
                    ),
                    hint_protocols = extension_foundation_protocols,
                    mnemonic = "ExtensionFoundationValidation",
                    output_suffix = "extension_foundation_validation",
                    required_conformance = "ExtensionFoundation.AppExtension",
                    target_label = target.label,
                    xplat_toolchain_info = xplat_toolchain_info,
                ))

    # Identify all of the transitive providers from the expected attributes.
    transitive_metadata_bundle_inputs = []
    transitive_extension_foundation = []
    transitive_app_extension_point = []
    direct_app_intents_modules = []
    for attr in _SWIFT_CONST_VALUES_ASPECT_ATTRS:
        for dep in getattr(ctx.rule.attr, attr, []):
            if AppIntentsInfo in dep:
                metadata_bundle_inputs = dep[AppIntentsInfo].metadata_bundle_inputs
                transitive_metadata_bundle_inputs.append(metadata_bundle_inputs)

                # Don't collect direct module dependencies if the target doesn't define App Intents.
                if app_intents_hint and SwiftInfo in dep:
                    dep_module_names = _swift_module_names(dep)
                    direct_app_intents_modules.extend([
                        metadata_bundle_input.module_name
                        for metadata_bundle_input in metadata_bundle_inputs.to_list()
                        if metadata_bundle_input.module_name in dep_module_names
                    ])
            if ExtensionFoundationInfo in dep:
                transitive_extension_foundation.append(
                    dep[ExtensionFoundationInfo].swiftconstvalues_files,
                )
            if AppExtensionPointInfo in dep:
                transitive_app_extension_point.append(
                    dep[AppExtensionPointInfo].extension_points,
                )

    providers = []

    direct_metadata_bundle_inputs = []
    if app_intents_hint:
        direct_metadata_bundle_inputs.append(struct(
            direct_app_intents_modules = direct_app_intents_modules,
            framework_typename_file = app_intents_typename_file,
            is_static_metadata = app_intents_hint.static_metadata,
            module_name = module_name,
            owner = str(ctx.label),
            swift_source_files = [f for f in ctx.rule.files.srcs if f.extension == "swift"],
            swiftconstvalues_files = const_values.to_list() if const_values else [],
        ))
    if direct_metadata_bundle_inputs or transitive_metadata_bundle_inputs:
        providers.append(AppIntentsInfo(
            metadata_bundle_inputs = depset(
                direct_metadata_bundle_inputs,
                transitive = transitive_metadata_bundle_inputs,
                order = "postorder",
            ),
        ))

    direct_extension_foundation = []
    if extension_foundation_hint and const_values:
        direct_extension_foundation.append(const_values)
    if direct_extension_foundation or transitive_extension_foundation:
        providers.append(ExtensionFoundationInfo(
            swiftconstvalues_files = depset(
                transitive = direct_extension_foundation + transitive_extension_foundation,
                order = "postorder",
            ),
        ))

    direct_app_extension_points = []
    if app_extension_point_hint and const_values:
        direct_app_extension_points.append(struct(
            module_name = module_name,
            owner = str(ctx.label),
            swiftconstvalues_files = const_values,
        ))
    if direct_app_extension_points or transitive_app_extension_point:
        providers.append(AppExtensionPointInfo(
            extension_points = depset(
                direct_app_extension_points,
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
    doc = """\
Collects Swift const values metadata (App Intents, ExtensionFoundation, and app extension points) \
from swift_library targets.""",
)
