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
    "@build_bazel_rules_apple//apple/bundling:linker_support.bzl",
    "linker_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:plist_actions.bzl",
    "plist_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:plist_support.bzl",
    "plist_support",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "apple_action",
    "bash_quote",
)


AppleEntitlementsInfo = provider()
"""Propagates information about entitlements to the bundling rules.

This provider is an internal implementation detail of the bundling rules and
should not be used directly by users.

Args:
  signing_entitlements: A `File` representing the `.entitlements` file that
      should be used during code signing of device builds. May be `None` if
      there are no entitlements or if this is a simulator build where the
      entitlements are embedded in the binary instead of being applied during
      signing.
"""


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
  return ctx.new_file("entitlements/%s%s" % (ctx.label.name, extension))


def _extract_team_prefix_action(ctx):
  """Extracts the team prefix from the target's provisioning profile.

  Args:
    ctx: The Skylark context.
  Returns:
    The file containing the team prefix extracted from the provisioning
    profile.
  """
  provisioning_profile = ctx.file.provisioning_profile
  extract_plist_cmd = plist_support.extract_provisioning_plist_command(
      ctx, provisioning_profile)
  team_prefix_file = _new_entitlements_artifact(ctx, ".team_prefix_file")

  # TODO(b/23975430): Remove the /bin/bash workaround once this bug is fixed.
  apple_action(
      ctx,
      inputs=[provisioning_profile],
      outputs=[team_prefix_file],
      command=[
          "/bin/bash", "-c",
          ("set -e && " +
           "PLIST=$(mktemp -t teamprefix.plist) && " +
           "trap \"rm ${PLIST}\" EXIT && " +
           extract_plist_cmd + " > ${PLIST} && " +
           "/usr/libexec/PlistBuddy -c " +
           "'Print ApplicationIdentifierPrefix:0' " +
           "${PLIST} > " + bash_quote(team_prefix_file.path)),
      ],
      mnemonic = "ExtractAppleTeamPrefix",
      no_sandbox = True,  # "security" tool requires this
  )

  return team_prefix_file


def _extract_entitlements_action(ctx):
  """Extracts entitlements from the target's provisioning profile.

  Args:
    ctx: The Skylark context.
  Returns:
    The file containing the extracted entitlements.
  """
  provisioning_profile = ctx.file.provisioning_profile
  extract_plist_cmd = plist_support.extract_provisioning_plist_command(
      ctx, provisioning_profile)
  extracted_entitlements_file = _new_entitlements_artifact(
      ctx, ".entitlements_with_variables")

  # TODO(b/23975430): Remove the /bin/bash workaround once this bug is fixed.
  apple_action(
      ctx,
      inputs=[provisioning_profile],
      outputs=[extracted_entitlements_file],
      command=[
          "/bin/bash", "-c",
          ("set -e && " +
           "PLIST=$(mktemp -t entitlements.plist) && " +
           "trap \"rm ${PLIST}\" EXIT && " +
           extract_plist_cmd + " > ${PLIST} && " +
           "/usr/libexec/PlistBuddy -x -c 'Print Entitlements' " +
           "${PLIST} > " + bash_quote(extracted_entitlements_file.path)),
      ],
      mnemonic = "ExtractAppleEntitlements",
      no_sandbox = True,  # "security" tool requires this
  )

  return extracted_entitlements_file


def _substitute_entitlements_action(ctx,
                                    input_entitlements,
                                    team_prefix_file,
                                    output_entitlements):
  """Creates actions to substitute values in the entitlements file.

  Args:
    ctx: The Skylark context.
    input_entitlements: The entitlements file with placeholders that must be
        substituted.
    team_prefix_file: The file containing the team prefix extracted from the
        provisioning profile, or None if this value should not be substituted.
    output_entitlements: The file to which the substituted entitlements should
        be written.
  """
  bundle_id = ctx.attr.bundle_id

  inputs = [input_entitlements]
  if team_prefix_file:
    inputs.append(team_prefix_file)

  command_line = "set -e && "
  if team_prefix_file:
    command_line += ("PREFIX=\"$(cat " + bash_quote(team_prefix_file.path) +
                     ")\" && ")
  command_line += "sed "
  if bundle_id:
    command_line += ("-e \"s#${PREFIX}\\.\\*#${PREFIX}." + bundle_id + "#g\" " +
                     "-e \"s#\\$(CFBundleIdentifier)#" + bundle_id + "#g\" ")
  if team_prefix_file:
    command_line += "-e \"s#\\$(AppIdentifierPrefix)#${PREFIX}.#g\" "

  command_line += (bash_quote(input_entitlements.path) +
                   " > " + bash_quote(output_entitlements.path))

  ctx.action(
      inputs=inputs,
      outputs=[output_entitlements],
      command=command_line,
      mnemonic = "SubstituteAppleEntitlements",
  )


def _include_debug_entitlements(ctx):
  """Returns a value indicating whether debug entitlements should be used.

  Debug entitlements are used if the _debug_entitlements attribute is present
  and if the --device_debug_entitlements command-line option indicates that
  they should be included.

  Debug entitlements are also not used on macOS.

  Args:
    ctx: The Skylark context.
  Returns:
    True if the debug entitlements should be included, otherwise False.
  """
  if platform_support.platform_type(ctx) == apple_common.platform_type.macos:
    return False
  if not ctx.fragments.objc.uses_device_debug_entitlements:
    return False
  if not ctx.file._debug_entitlements:
    return False
  return True


def _register_merge_entitlements_action(ctx,
                                        input_entitlements,
                                        merged_entitlements):
  """Merges the given entitlements files into a single file.

  Args:
    ctx: The Skylark context.
    input_entitlements: The entitlements files to be merged.
    merged_entitlements: The File where the merged entitlements will be
        written.
  """
  control = struct(
      plists=[f.path for f in input_entitlements],
      output=merged_entitlements.path,
      binary=False,
  )
  control_file = ctx.new_file("%s.merge-entitlements-control" % ctx.label.name)
  ctx.file_action(
      output=control_file,
      content=control.to_json()
  )

  plist_support.plisttool_action(
      ctx,
      inputs=input_entitlements,
      outputs=[merged_entitlements],
      control_file=control_file,
      mnemonic="MergeEntitlementsFiles",
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
  is_device = platform_support.is_device_build(ctx)

  if ctx.file.provisioning_profile:
    team_prefix_file = _extract_team_prefix_action(ctx)
    # Use the entitlements from the target if given; otherwise, extract them
    # from the provisioning profile.
    entitlements_needing_substitution = (
        ctx.file.entitlements or _extract_entitlements_action(ctx))
  else:
    team_prefix_file = None
    entitlements_needing_substitution = ctx.file.entitlements

  uses_debug_entitlements = _include_debug_entitlements(ctx)

  # If we don't have any entitlements (explicit, from the provisioning profile,
  # or debug ones), then create an empty .c file and return empty providers.
  if not entitlements_needing_substitution and not uses_debug_entitlements:
    return struct(
        objc=apple_common.new_objc_provider(),
        providers=[AppleEntitlementsInfo(signing_entitlements=None)],
    )

  if entitlements_needing_substitution:
    final_entitlements = ctx.new_file("%s.entitlements" % ctx.label.name)

    # The ordering of this can be slightly confusing because the actions aren't
    # registered in the same order that they would be executed (because
    # registering actions just builds the dependency graph). If debug
    # entitlements are not being included, we simply make substitutions in the
    # target's entitlements and write that to the final entitlements file. If
    # debug entitlements are included, then we make the substitutions in the
    # target's entitlements, merge that with the debug entitlements, and the
    # result is used as the final entitlements.
    if _include_debug_entitlements(ctx):
      substituted_entitlements = _new_entitlements_artifact(ctx, ".substituted")

      _register_merge_entitlements_action(
          ctx,
          input_entitlements=[
              substituted_entitlements,
              ctx.file._debug_entitlements
          ],
          merged_entitlements=final_entitlements)
    else:
      substituted_entitlements = final_entitlements

    _substitute_entitlements_action(ctx,
                                    entitlements_needing_substitution,
                                    team_prefix_file,
                                    substituted_entitlements)
  else:
    final_entitlements = ctx.file._debug_entitlements

  # Only propagate linkopts for simulator builds to embed the entitlements into
  # the binary; for device builds, the entitlements are applied during signing.
  if not is_device:
    return struct(
        objc=linker_support.sectcreate_objc_provider(
            "__TEXT", "__entitlements", final_entitlements
        ),
        providers=[AppleEntitlementsInfo(signing_entitlements=None)],
    )
  else:
    return struct(
        objc=apple_common.new_objc_provider(),
        providers=[
            AppleEntitlementsInfo(signing_entitlements=final_entitlements)
        ],
    )


entitlements = rule(
    implementation=_entitlements_impl,
    attrs={
        "bundle_id": attr.string(
            mandatory=False,
        ),
        "_debug_entitlements": attr.label(
            cfg="host",
            allow_files=True,
            single_file=True,
            default=Label("@bazel_tools//tools/objc:device_debug_entitlements.plist"),
        ),
        "entitlements": attr.label(
            allow_files=[".entitlements", ".plist"],
            single_file=True,
        ),
        "_plisttool": attr.label(
            cfg="host",
            default=Label(
                "@build_bazel_rules_apple//tools/plisttool"),
            executable=True,
        ),
        # Used to pass the platform type through from the calling rule.
        "platform_type": attr.string(),
        "provisioning_profile": attr.label(
            allow_files=[".mobileprovision", ".provisionprofile"],
            single_file=True,
        ),
    },
    fragments=["apple", "objc"],
)
