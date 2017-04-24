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

load("//apple/bundling:platform_support.bzl",
     "platform_support")
load("//apple/bundling:plist_actions.bzl", "plist_actions")
load("//apple/bundling:plist_support.bzl", "plist_support")
load("//apple:utils.bzl", "apple_action")
load("//apple:utils.bzl", "bash_quote")


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
        provisioning profile.
    output_entitlements: The file to which the substituted entitlements should
        be written.
  """
  bundle_id = ctx.attr.bundle_id

  ctx.action(
      inputs=[input_entitlements, team_prefix_file],
      outputs=[output_entitlements],
      command=(
          "set -e && " +
          "PREFIX=\"$(cat " + bash_quote(team_prefix_file.path) + ")\" && " +
          "sed " +
          "-e \"s#${PREFIX}\\.\\*#${PREFIX}." + bundle_id + "#g\" " +
          "-e \"s#\\$(AppIdentifierPrefix)#${PREFIX}.#g\" " +
          "-e \"s#\\$(CFBundleIdentifier)#" + bundle_id + "#g\" " +
          bash_quote(input_entitlements.path) +
          " > " + bash_quote(output_entitlements.path)
      ),
      mnemonic = "SubstituteAppleEntitlements",
  )


def _include_debug_entitlements(ctx):
  """Returns a value indicating whether debug entitlements should be used.

  Debug entitlements are used if the _debug_entitlements attribute is present
  and if the --device_debug_entitlements command-line option indicates that
  they should be included.

  Args:
    ctx: The Skylark context.
  Returns:
    True if the debug entitlements should be included, otherwise False.
  """
  uses_debug_entitlements = ctx.fragments.objc.uses_device_debug_entitlements
  return uses_debug_entitlements and ctx.file._debug_entitlements


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
  __TEXT,__entitlements.

  This rule generates both the entitlements file to be embedded into the code
  signature, and a source file that should be compiled in to the binary to
  generate the proper section in the simulator build. This file contains
  preprocessor guards to ensure that its contents are only included during
  simulator builds, so it is safe to add to the binary's `srcs`
  unconditionally (this is necessary because the macro that invokes this rule
  does not have access to enough contextual information to make that decision
  on its own).

  Additionally, this rule propagates an `objc` provider. For optimized device
  builds (i.e., release builds), the provider is empty. For simulator builds,
  it contains additional `linkopts` that are necessary to ensure that the
  generated entitlements function is linked into the appropriate Mach-O
  segment. For this reason, in addition to the source file above, the target
  generated by this rule must also be added as an extra `deps` of the binary
  target so that the correct linker flags are included.

  Args:
    ctx: The Skylark context.
  Returns:
    A `struct` containing the `objc` provider that propagates the additional
    linker options, if necessary.
  """
  is_device = platform_support.is_device_build(ctx)
  if not ctx.file.provisioning_profile and is_device:
    fail("The provisioning_profile attribute must be set for device builds.")

  team_prefix_file = _extract_team_prefix_action(ctx)

  # Use the entitlements from the target if given; otherwise, extract them from
  # the provisioning profile.
  entitlements_needing_substitution = (
      ctx.file.entitlements or _extract_entitlements_action(ctx))

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
        merged_entitlements=ctx.outputs.device_entitlements)
  else:
    substituted_entitlements = ctx.outputs.device_entitlements

  _substitute_entitlements_action(ctx, entitlements_needing_substitution,
                                  team_prefix_file,
                                  substituted_entitlements)

  symbol_function = "void %s(){}" % (_simulator_function(ctx.label.name))
  device_path = bash_quote(ctx.outputs.device_entitlements.path)
  simulator_path = bash_quote(ctx.outputs.simulator_source.path)
  ctx.action(
      inputs=[ctx.outputs.device_entitlements],
      outputs=[ctx.outputs.simulator_source],
      # Add the empty function that we require to enforce linkage then
      # add the commented out plist text
      # and the the plist text as assembly bytes wrapped in
      # an #ifdef that only brings them in for simulator builds.
      command=(
          "set -e && " +
          "echo " +
          "\"#include <TargetConditionals.h>\n\n" + symbol_function +
          "\n\n#if TARGET_OS_SIMULATOR\n\" >> "
          + simulator_path + " && " +
          " cat " + device_path + " | sed -e 's:^:// :' " +
          " >> " + simulator_path + " && " +  "xxd -i " + device_path +
          " | sed -e '1 s/^.*$/" +
          "__asm(\".section __TEXT,__entitlements\");__asm(\".byte /'" +
          " -e 's/$/ \\\\/' -e '$d' | sed -e '$ s/^.*$/\");/'" +
          " >> " + simulator_path + " && " +
          "echo \"\n#endif  // TARGET_OS_SIMULATOR\n\" >> " + simulator_path
      ),
      mnemonic = "GenerateSimulatorEntitlementsSource",
  )

  # Only propagate linkopts for simulator builds. We need to prevent the -u
  # option from being added to release builds because it is incompatible with
  # Bitcode, if users have that enabled as well.
  if not is_device:
    return struct(objc=apple_common.new_objc_provider(
        linkopt=depset(_link_opts(ctx.label.name), order="topological"),
    ))
  else:
    return struct(objc=apple_common.new_objc_provider())


def _device_file_label(name):
  """Derive the name for the `*.entitlements` file for a device build.

  Args:
    name: The name of the rule that the label applies to.
  Returns:
    The name for the `*.entitlements` file for a device build.
  """
  return name + ".entitlements"


def _simulator_file_label(name):
  """Derive the name for the entitlements source file for a simulator build.

  Args:
    name: The name of the rule that the label applies to.
  Returns:
    The name for the `*.entitlements.c` file for a simulator build.
  """
  return _device_file_label(name) + ".c"


def _sanitize_for_c_symbol(string):
  """Sanitizes a string so that it is a valid C symbol.

  The algorithm replaces non-C-symbol characters with an underscore. It is not
  bijective, because for this particular use case we do not need it to be
  reversible or unique; only one entitlements symbol is ever generated per
  target.

  Args:
    string: The string to sanitize.
  Returns:
    The sanitized string.
  """
  sanitized_chars = []
  for i in range(len(string)):
    ch = string[i]
    if not (ch.isalnum() or ch == "_"):
      sanitized_chars.append("_")
    else:
      sanitized_chars.append(ch)
  return "".join(sanitized_chars)


def _simulator_function(name):
  """Derive the name of the function to force linkage.

  The Mach-O section that we need in our simulator binary is compiled into
  a archive (.a) file. We need to force the linker to pull this section into
  the actual binary. The only way to do this is to actually link in function
  from the .a. We generate an empty function that we then ask the linker to
  link in for us (using the link commands generated by the `link_opts` macro).

  Args:
    name: The name of the rule that the label applies to.
  Returns:
    The name of a function to enforce linkage.
  """
  return "__ENTITLEMENTS_LINKAGE__" + _sanitize_for_c_symbol(name)


def _link_opts(name):
  """Derive the link options required to pull in our Mach-O section.

  Returns the link options that should be passed into the linker to get it
  to link in our empty function which in turn will pull in our Mach-O segment.

  Note that the symbol is prefixed with a _ because of C linkage rules.

  Args:
    name: The name of the rule that the label applies to.
  Returns:
    The link options required to pull in our Mach-O segment appropriately
  """
  return [ "-u", "_" + _simulator_function(name) ]


entitlements = rule(
    implementation=_entitlements_impl,
    attrs={
        "bundle_id": attr.string(
            mandatory=True,
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
            single_file=True,
            default=Label("//apple/bundling:plisttool"),
        ),
        # Used to pass the platform type through from the calling rule.
        "platform_type": attr.string(),
        "provisioning_profile": attr.label(
            allow_files=[".mobileprovision", ".provisionprofile"],
            single_file=True,
        ),
    },
    fragments=["apple", "objc"],
    outputs={
        "device_entitlements": _device_file_label("%{name}"),
        "simulator_source": _simulator_file_label("%{name}"),
    },
)


# Define the loadable module that lists the exported macros in this file.
# Note that the entitlements rule is exported separately.
entitlements_support = struct(
    device_file_label=_device_file_label,
    simulator_file_label=_simulator_file_label,
)
