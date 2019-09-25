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

def _tool_validation_mode(rules_mode, is_device):
    """Returns the tools validation_mode to use.

    Args:
      rules_mode: The validation_mode attribute of the rule.
      is_device: True if this is a device build, False otherwise.

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

def _new_entitlements_artifact(ctx, extension):
    """Returns a new file artifact for entitlements.

    This function creates a new file in an "entitlements" directory in the
    target's location whose name is the target's name with the given extension.

    Args:
      ctx: The Skylark context.
      extension: The file extension (including the leading dot).

    Returns:
      The requested file object.
    """
    return ctx.actions.declare_file(
        "entitlements/%s%s" % (ctx.label.name, extension),
    )

def _include_debug_entitlements(ctx):
    """Returns a value indicating whether debug entitlements should be used.

    Debug entitlements are used if the --device_debug_entitlements command-line
    option indicates that they should be included.

    Debug entitlements are also not used on macOS.

    Args:
      ctx: The Skylark context.

    Returns:
      True if the debug entitlements should be included, otherwise False.
    """
    if platform_support.platform_type(ctx) == apple_common.platform_type.macos:
        return False
    add_debugger_entitlement = defines.bool_value(
        ctx,
        "apple.add_debugger_entitlement",
        None,
    )
    if add_debugger_entitlement != None:
        return add_debugger_entitlement
    if not ctx.fragments.objc.uses_device_debug_entitlements:
        return False
    return True

def _extract_signing_info(ctx):
    """Inspects the current context and extracts the signing information.

    Args:
      ctx: The Skylark context.

    Returns:
      A `struct` with two items: the entitlements file to use, a
      profile_metadata file.
    """
    entitlements = ctx.file.entitlements
    profile_metadata = None

    provisioning_profile = ctx.file.provisioning_profile
    if provisioning_profile:
        profile_metadata = _new_entitlements_artifact(ctx, ".profile_metadata")
        outputs = [profile_metadata]
        control = {
            "profile_metadata": profile_metadata.path,
            "provisioning_profile": provisioning_profile.path,
            "target": str(ctx.label),
        }
        if not entitlements:
            # No entitlements, extract the default one from the profile.
            entitlements = _new_entitlements_artifact(ctx, ".extracted_entitlements")
            control["entitlements"] = entitlements.path
            outputs.append(entitlements)

        control_file = _new_entitlements_artifact(
            ctx,
            "provisioning_profile_tool-control",
        )
        ctx.actions.write(
            output = control_file,
            content = struct(**control).to_json(),
        )

        apple_support.run(
            ctx,
            inputs = [control_file, provisioning_profile],
            outputs = outputs,
            executable = ctx.executable._provisioning_profile_tool,
            arguments = [control_file.path],
            mnemonic = "ExtractFromProvisioningProfile",
            # Since the tools spawns openssl and/or security tool, it doesn't
            # support being sandboxed.
            execution_requirements = {"no-sandbox": "1"},
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
      ctx: The Skylark context.

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
    bundle_id = ctx.attr.bundle_id
    bundling_support.validate_bundle_id(bundle_id)

    signing_info = _extract_signing_info(ctx)
    plists = []
    forced_plists = []
    if signing_info.entitlements:
        plists.append(signing_info.entitlements)
    if _include_debug_entitlements(ctx):
        get_task_allow = {"get-task-allow": True}
        forced_plists.append(struct(**get_task_allow))

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
    is_device = platform_support.is_device_build(ctx)

    entitlements_options = {
        "bundle_id": bundle_id,
    }
    if signing_info.profile_metadata:
        inputs.append(signing_info.profile_metadata)
        entitlements_options["profile_metadata_file"] = signing_info.profile_metadata.path
        entitlements_options["validation_mode"] = _tool_validation_mode(
            ctx.attr.validation_mode,
            is_device,
        )

    control = struct(
        plists = [f.path for f in plists],
        forced_plists = forced_plists,
        entitlements_options = struct(**entitlements_options),
        output = final_entitlements.path,
        target = str(ctx.label),
        variable_substitutions = struct(CFBundleIdentifier = ctx.attr.bundle_id),
    )
    control_file = _new_entitlements_artifact(ctx, "plisttool-control")
    ctx.actions.write(
        output = control_file,
        content = control.to_json(),
    )

    resource_actions.plisttool_action(
        ctx,
        inputs = inputs,
        outputs = [final_entitlements],
        control_file = control_file,
        mnemonic = "ProcessEntitlementsFiles",
    )

    # Only propagate linkopts for simulator builds to embed the entitlements into
    # the binary; for device builds, the entitlements are applied during signing.
    if not is_device:
        return [
            linking_support.sectcreate_objc_provider(
                "__TEXT",
                "__entitlements",
                final_entitlements,
            ),
            AppleEntitlementsInfo(final_entitlements = final_entitlements),
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
