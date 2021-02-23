# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Actions that manipulate entitlements and provisioning profiles."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_support_toolchain.bzl",
    "apple_support_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//apple:common.bzl",
    "entitlements_validation_mode",
)

AppleEntitlementsInfo = provider(
    doc = """
Propagates information about entitlements to the bundling rules.

This provider is an internal implementation detail of the bundling rules and
should not be used directly by users.
""",
    fields = {
        "final_entitlements": """
A `File` representing the `.entitlements` file that should be used
during code signing. May be `None` if there are no entitlements.
""",
    },
)

def _tool_validation_mode(*, is_device, rules_mode):
    """Returns the tools validation_mode to use.

    Args:
      is_device: True if this is a device build, False otherwise.
      rules_mode: The validation_mode attribute of the rule.

    Returns:
      The value to use the for the validation_mode in the entitlement
      options of the tool.
    """

    # In the current implementation of the "rules", things actually
    # are macros that expand to be a few targets. So when an
    # entitlements() is created by the macros, they just have access to
    # the kwargs, so the default has to be repeated here.
    if not rules_mode:
        rules_mode = entitlements_validation_mode.loose

    value = {
        entitlements_validation_mode.error: "error",
        entitlements_validation_mode.warn: "warn",
        entitlements_validation_mode.loose: "error" if is_device else "warn",
        entitlements_validation_mode.skip: "skip",
    }[rules_mode]

    return value

def _new_entitlements_artifact(*, actions, extension, label_name):
    """Returns a new file artifact for entitlements.

    This function creates a new file in an "entitlements" directory in the
    target's location whose name is the target's name with the given extension.

    Args:
      actions: The actions provider from `ctx.actions`.
      extension: The file extension (including the leading dot).
      label_name: The name of the target.

    Returns:
      The requested file object.
    """
    return actions.declare_file(
        "entitlements/%s%s" % (label_name, extension),
    )

def _include_debug_entitlements(*, platform_prerequisites):
    """Returns a value indicating whether debug entitlements should be used.

    Debug entitlements are used if the --device_debug_entitlements command-line
    option indicates that they should be included.

    Debug entitlements are also not used on macOS.

    Args:
      platform_prerequisites: Struct containing information on the platform being targeted.

    Returns:
      True if the debug entitlements should be included, otherwise False.
    """
    if platform_prerequisites.platform_type == apple_common.platform_type.macos:
        return False
    add_debugger_entitlement = defines.bool_value(
        config_vars = platform_prerequisites.config_vars,
        default = None,
        define_name = "apple.add_debugger_entitlement",
    )
    if add_debugger_entitlement != None:
        return add_debugger_entitlement
    if not platform_prerequisites.objc_fragment.uses_device_debug_entitlements:
        return False
    return True

def _include_app_clip_entitlements(*, product_type):
    """Returns a value indicating whether app clip entitlements should be used.

    Args:
      product_type: The product type identifier used to describe the current bundle type.

    Returns:
      True if the app clip entitlements should be included, otherwise False.
    """
    return product_type == apple_product_type.app_clip

def _extract_signing_info(
        *,
        actions,
        entitlements,
        platform_prerequisites,
        provisioning_profile,
        provisioning_profile_tool,
        rule_label):
    """Inspects the current context and extracts the signing information.

    Args:
      actions: The actions provider from `ctx.actions`.
      entitlements: The entitlements file to sign with. Can be `None` if one was not provided.
      platform_prerequisites: Struct containing information on the platform being targeted.
      provisioning_profile: File for the provisioning profile.
      provisioning_profile_tool: A tool used to extract info from a provisioning profile.
      rule_label: The label of the target being analyzed.

    Returns:
      A `struct` with two items: the entitlements file to use, a
      profile_metadata file.
    """
    profile_metadata = None

    if provisioning_profile:
        profile_metadata = _new_entitlements_artifact(
            actions = actions,
            extension = ".profile_metadata",
            label_name = rule_label.name,
        )
        outputs = [profile_metadata]
        control = {
            "profile_metadata": profile_metadata.path,
            "provisioning_profile": provisioning_profile.path,
            "target": str(rule_label),
        }
        if not entitlements:
            # No entitlements, extract the default one from the profile.
            entitlements = _new_entitlements_artifact(
                actions = actions,
                extension = ".extracted_entitlements",
                label_name = rule_label.name,
            )
            control["entitlements"] = entitlements.path
            outputs.append(entitlements)

        control_file = _new_entitlements_artifact(
            actions = actions,
            extension = "provisioning_profile_tool-control",
            label_name = rule_label.name,
        )
        actions.write(
            output = control_file,
            content = struct(**control).to_json(),
        )

        apple_support.run(
            actions = actions,
            apple_fragment = platform_prerequisites.apple_fragment,
            arguments = [control_file.path],
            executable = provisioning_profile_tool,
            # Since the tools spawns openssl and/or security tool, it doesn't
            # support being sandboxed.
            execution_requirements = {"no-sandbox": "1"},
            inputs = [control_file, provisioning_profile],
            mnemonic = "ExtractFromProvisioningProfile",
            outputs = outputs,
            xcode_config = platform_prerequisites.xcode_version_config,
            xcode_path_wrapper = platform_prerequisites.xcode_path_wrapper,
        )

    return struct(
        entitlements = entitlements,
        profile_metadata = profile_metadata,
    )

def _entitlements_impl(ctx):
    """Creates actions to create files used for code signing.

    Entitlements are generated based on a plist-format entitlements file passed
    into the target's entitlements attribute, or extracted from the provisioning
    profile if that attribute is not present. The team prefix is extracted from
    the provisioning profile and the following substitutions are performed on the
    entitlements:

    - "PREFIX.*" -> "PREFIX.BUNDLE_ID" (where BUNDLE_ID is the target's bundle
      ID)
    - "$(AppIdentifierPrefix)" -> "PREFIX."
    - "$(CFBundleIdentifier)" -> "BUNDLE_ID"

    For a device build the entitlements are part of the code signature.
    For a simulator build the entitlements are written into a Mach-O section
    __TEXT,__entitlements. Because this rule propagates an `objc` provider for the
    simulator case, the target generated by this rule must also be added as an
    extra dependency of the binary target so that the correct linker flags are
    used in that case.

    Args:
      ctx: The Starlark context.

    Returns:
      A `struct` containing the `objc` provider that propagates the additional
      linker options if necessary for simulator builds, and the internal
      `AppleEntitlementsInfo` provider used elsewhere during bundling.
    """

    # Things can fail in odd ways without a bundle id, so ensure that it is provided.
    # NOTE: bundler.run() also does the validation, but because entitlements are
    # linked into a segment for some build, the output of this rule is an input to
    # almost all the bundling code, so a bad bundle id actually gets here. In an ideal
    # world, validation wouldn't have to happen here.
    actions = ctx.actions
    bundle_id = ctx.attr.bundle_id
    bundling_support.validate_bundle_id(bundle_id)

    deps = getattr(ctx.attr, "deps", None)
    uses_swift = swift_support.uses_swift(deps) if deps else False

    # Only need as much platform information as this rule is able to give, for entitlement file
    # processing.
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        config_vars = ctx.var,
        device_families = None,
        disabled_features = ctx.disabled_features,
        explicit_minimum_os = None,
        features = ctx.features,
        objc_fragment = ctx.fragments.objc,
        platform_type_string = str(ctx.fragments.apple.single_arch_platform.platform_type),
        uses_swift = uses_swift,
        xcode_path_wrapper = None,
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    signing_info = _extract_signing_info(
        actions = actions,
        entitlements = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        provisioning_profile = ctx.file.provisioning_profile,
        provisioning_profile_tool = ctx.executable._provisioning_profile_tool,
        rule_label = ctx.label,
    )
    plists = []
    forced_plists = []
    if signing_info.entitlements:
        plists.append(signing_info.entitlements)
    if _include_debug_entitlements(platform_prerequisites = platform_prerequisites):
        get_task_allow = {"get-task-allow": True}
        forced_plists.append(struct(**get_task_allow))
    if _include_app_clip_entitlements(product_type = ctx.attr.product_type):
        app_clip = {"com.apple.developer.on-demand-install-capable": True}
        forced_plists.append(struct(**app_clip))

    inputs = list(plists)

    # If there is no entitlements to use; return empty info.
    if not inputs:
        return [
            apple_common.new_objc_provider(),
            AppleEntitlementsInfo(final_entitlements = None),
        ]

    final_entitlements = ctx.actions.declare_file(
        "%s.entitlements" % ctx.label.name,
    )

    entitlements_options = {
        "bundle_id": bundle_id,
    }
    if signing_info.profile_metadata:
        inputs.append(signing_info.profile_metadata)
        entitlements_options["profile_metadata_file"] = signing_info.profile_metadata.path
        entitlements_options["validation_mode"] = _tool_validation_mode(
            is_device = platform_prerequisites.platform.is_device,
            rules_mode = ctx.attr.validation_mode,
        )

    control = struct(
        plists = [f.path for f in plists],
        forced_plists = forced_plists,
        entitlements_options = struct(**entitlements_options),
        output = final_entitlements.path,
        target = str(ctx.label),
        variable_substitutions = struct(CFBundleIdentifier = ctx.attr.bundle_id),
    )
    control_file = _new_entitlements_artifact(
        actions = actions,
        extension = "plisttool-control",
        label_name = ctx.label.name,
    )
    ctx.actions.write(
        output = control_file,
        content = control.to_json(),
    )

    resource_actions.plisttool_action(
        actions = actions,
        control_file = control_file,
        inputs = inputs,
        mnemonic = "ProcessEntitlementsFiles",
        outputs = [final_entitlements],
        platform_prerequisites = platform_prerequisites,
        resolved_plisttool = apple_support_toolchain_utils.resolve_tools_for_executable(
            attr_name = "_plisttool",
            rule_ctx = ctx,
        ),
    )

    # Only propagate linkopts for simulator builds to embed the entitlements into
    # the binary; for device builds, the entitlements are applied during signing.
    if not platform_prerequisites.platform.is_device:
        simulator_entitlements = None
        if _include_debug_entitlements(platform_prerequisites = platform_prerequisites):
            simulator_entitlements = ctx.actions.declare_file(
                "%s.simulator.entitlements" % ctx.label.name,
            )
            simulator_control = struct(
                plists = [],
                forced_plists = [struct(**{"com.apple.security.get-task-allow": True})],
                output = simulator_entitlements.path,
                target = str(ctx.label),
            )
            simulator_control_file = _new_entitlements_artifact(
                actions = actions,
                extension = "simulator-plisttool-control",
                label_name = ctx.label.name,
            )
            ctx.actions.write(
                output = simulator_control_file,
                content = simulator_control.to_json(),
            )
            resource_actions.plisttool_action(
                actions = actions,
                control_file = simulator_control_file,
                inputs = [],
                mnemonic = "ProcessSimulatorEntitlementsFile",
                outputs = [simulator_entitlements],
                platform_prerequisites = platform_prerequisites,
                resolved_plisttool = apple_support_toolchain_utils.resolve_tools_for_executable(
                    attr_name = "_plisttool",
                    rule_ctx = ctx,
                ),
            )

        return [
            linking_support.sectcreate_objc_provider(
                "__TEXT",
                "__entitlements",
                final_entitlements,
            ),
            AppleEntitlementsInfo(final_entitlements = simulator_entitlements),
        ]
    else:
        return [
            apple_common.new_objc_provider(),
            AppleEntitlementsInfo(final_entitlements = final_entitlements),
        ]

entitlements = rule(
    implementation = _entitlements_impl,
    attrs = {
        "bundle_id": attr.string(
            mandatory = True,
        ),
        "entitlements": attr.label(
            allow_single_file = [".entitlements", ".plist"],
        ),
        # Used to pass the platform type through from the calling rule.
        "platform_type": attr.string(),
        # Used to pass the product type through from the calling rule.
        "product_type": attr.string(),
        "provisioning_profile": attr.label(
            allow_single_file = [".mobileprovision", ".provisionprofile"],
        ),
        "validation_mode": attr.string(),
        "_plisttool": attr.label(
            cfg = "host",
            default = Label(
                "@build_bazel_rules_apple//tools/plisttool",
            ),
            executable = True,
        ),
        "_provisioning_profile_tool": attr.label(
            cfg = "host",
            default = Label(
                "@build_bazel_rules_apple//tools/provisioning_profile_tool",
            ),
            executable = True,
        ),
        # This needs to be an attribute on the rule for platform_support
        # to access it.
        "_xcode_config": attr.label(default = configuration_field(
            fragment = "apple",
            name = "xcode_config_label",
        )),
    },
    fragments = ["apple", "objc"],
)
