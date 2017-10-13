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

"""Support functions for plist-based operations."""

load("@build_bazel_rules_apple//apple:utils.bzl", "apple_action")
load("@build_bazel_rules_apple//apple/bundling:mock_support.bzl", "mock_support")
load("@build_bazel_rules_apple//apple:utils.bzl", "bash_quote")


def _extract_provisioning_plist_command(ctx, provisioning_profile):
  """Returns the shell command to extract a plist from a provisioning profile.

  Args:
    ctx: The Skylark context.
    provisioning_profile: The `File` representing the provisioning profile.
  Returns:
    The shell command used to extract the plist.
  """
  if mock_support.is_provisioning_mocked(ctx):
    # If provisioning is mocked, treat the provisioning profile as a plain XML
    # plist without a signature.
    return "cat " + bash_quote(provisioning_profile.path)
  else:
    extract_plist_cmd = ("security cms -D -i " +
            bash_quote(provisioning_profile.path))
    return ("( " +
            "STDERR=$(mktemp -t openssl.stderr) && " +
            "trap \"rm -f ${STDERR}\" EXIT && " +
            extract_plist_cmd + " 2> ${STDERR} || " +
            "( >&2 echo 'Could not extract plist from provisioning profile' " +
            " && >&2 cat ${STDERR} && exit 1 ) " +
            ")")


def _plisttool_action(ctx, inputs, outputs, control_file, mnemonic=None):
  """Registers an action that invokes `plisttool`.

  This function is a low-level helper that simply invokes `plisttool` with the
  given arguments. It is intended to be called by other functions that register
  actions for more specific resources, like Info.plist files or entitlements
  (which is why it is in a `plist_support.bzl` rather than
  `plist_actions.bzl`).

  Args:
    ctx: The Skylark context.
    inputs: Any `File`s that should be treated as inputs to the underlying
        action.
    outputs: Any `File`s that should be treated as outputs of the underlying
        action.
    control_file: The `File` containing the control struct to be passed to
        plisttool.
    mnemonic: The mnemonic to display when the action executes. Defaults to
        None.
  """
  apple_action(
      ctx,
      inputs=inputs + [control_file],
      outputs=outputs,
      executable=ctx.executable._plisttool,
      arguments=[control_file.path],
      mnemonic=mnemonic,
  )


# Define the loadable module that lists the exported symbols in this file.
plist_support = struct(
    extract_provisioning_plist_command=_extract_provisioning_plist_command,
    plisttool_action=_plisttool_action,
)
