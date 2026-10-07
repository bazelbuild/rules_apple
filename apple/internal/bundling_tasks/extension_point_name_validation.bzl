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

"""Bundling Task implementation for extension point name validation."""

load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)

visibility(["@build_bazel_rules_apple//apple/internal/..."])

def _extension_point_name_validation_bundling_task_impl(
        *,
        actions,
        app_extension_point_providers,
        apple_xplat_toolchain_info,
        bundle_id,
        extension_foundation_providers,
        label,
        output_discriminator,
        xplat_exec_group):
    """Implementation for the extension point name validation bundling task."""
    validation_outputs = []

    extension_bundle_ids = []
    for ext_provider in extension_foundation_providers:
        # First validate the ExtensionFoundation bindings on the extension targets to check that
        # they are referencing a set of extension points that should be defined on the host app.
        if (ext_provider.product_type != apple_product_type.extensionkit_extension or
            not ext_provider.bundle_id):
            continue
        ext_swiftconstvalues = ext_provider.swiftconstvalues_files.to_list()
        if not ext_swiftconstvalues:
            continue
        extension_bundle_id = ext_provider.bundle_id
        if extension_bundle_id in extension_bundle_ids:
            continue
        extension_bundle_ids.append(extension_bundle_id)
        validation_output = intermediates.file(
            actions = actions,
            file_name = "{ext_bundle_id}_extension_point_binding_validation.txt".format(
                ext_bundle_id = extension_bundle_id.replace(".", "_"),
            ),
            output_discriminator = output_discriminator,
            target_name = label.name,
        )
        args = actions.args()
        args.add("check-extension-point-name")
        args.add("--extension-bundle-id", extension_bundle_id)
        args.add("--application-bundle-id", bundle_id)
        args.add_all("--swiftconstvalues", ext_swiftconstvalues)
        args.add("--output", validation_output)
        actions.run(
            executable = apple_xplat_toolchain_info.swift_const_values_validation_tool,
            arguments = [args],
            inputs = ext_swiftconstvalues,
            outputs = [validation_output],
            exec_group = xplat_exec_group,
            mnemonic = "ExtensionPointNameAppBindingValidation",
        )
        validation_outputs.append(validation_output)

    app_swiftconstvalues = [
        f
        for provider in app_extension_point_providers
        for point in provider.extension_points.to_list()
        for f in point.swiftconstvalues_files.to_list()
    ]
    if app_swiftconstvalues:
        for ext_bundle_id in extension_bundle_ids:
            # Then validate the ExtensionFoundation definitions that declare extensions on the app
            # target and its exclusively owned dependencies.
            validation_output = intermediates.file(
                actions = actions,
                file_name = "{ext_bundle_id}_extension_point_definition_validation.txt".format(
                    ext_bundle_id = ext_bundle_id.replace(".", "_"),
                ),
                output_discriminator = output_discriminator,
                target_name = label.name,
            )
            args = actions.args()
            args.add("check-extension-point-name")
            args.add("--extension-bundle-id", ext_bundle_id)
            args.add_all("--swiftconstvalues", app_swiftconstvalues)
            args.add("--output", validation_output)
            actions.run(
                executable = apple_xplat_toolchain_info.swift_const_values_validation_tool,
                arguments = [args],
                inputs = app_swiftconstvalues,
                outputs = [validation_output],
                exec_group = xplat_exec_group,
                mnemonic = "ExtensionPointNameExtensionDefinitionValidation",
            )
            validation_outputs.append(validation_output)

    return struct(
        providers = [],
        output_groups = {"_validation": depset(validation_outputs)} if validation_outputs else {},
    )

def extension_point_name_validation_bundling_task(
        *,
        actions,
        app_extension_point_providers = [],
        apple_xplat_toolchain_info,
        bundle_id,
        extension_foundation_providers = [],
        label,
        output_discriminator = None,
        xplat_exec_group):
    """Constructor for the extension point name validation bundling task."""
    return lambda *args, **kwargs: _extension_point_name_validation_bundling_task_impl(
        actions = actions,
        app_extension_point_providers = app_extension_point_providers,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_id = bundle_id,
        extension_foundation_providers = extension_foundation_providers,
        label = label,
        output_discriminator = output_discriminator,
        xplat_exec_group = xplat_exec_group,
        *args,
        **kwargs
    )
