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

"""Actions to manipulate bitcode outputs."""

load("@build_bazel_rules_apple//apple/bundling:file_support.bzl",
     "file_support")
load("@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
     "file_actions")
load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
     "binary_support")
load("@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
     "platform_support")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "join_commands")


def _zip_bitcode_symbols_maps(ctx, binary_artifact):
  """Creates an archive with bitcode symbol maps.

  The archive contains bitcode symbol map files produced by the linker and is
  structured in a way suitable for submitting to App Store. Example:

    BCSymbolMaps/
    |-- 02975B9D-8273-316D-84B4-A0BA7E102282.bcsymbolmap
    |-- DBB46D9A-7B2A-3911-9DDA-15E88DEA3545.bcsymbolmap

    Each file is named with the UUID of its corresponding binary.

  This function assumes that the target has a user-provided binary in the
  `binary` attribute. It is the responsibility of the caller to check this.

  Args:
    ctx: The Skylark context.
    binary_artifact: The binary artifact being generated for the current rule.

  Returns:
    A `File` object representing the ZIP file containing the bitcode symbol
    maps, or `None` if no bitcode symbols were found.
  """
  outputs_map = binary_support.get_binary_provider(
      ctx.attr.deps,
      apple_common.AppleDebugOutputs
  ).outputs_map

  # TODO(b/36174487): Iterate over .items() once the Map/dict problem is fixed.
  copy_commands = []
  bitcode_symbol_inputs = []
  for arch in outputs_map:
    bitcode_symbols = outputs_map[arch].get("bitcode_symbols")
    if not bitcode_symbols:
      continue

    bitcode_symbol_inputs.append(bitcode_symbols)
    # Get the UUID of the arch slice and use that to name the bcsymbolmap file.
    copy_commands.append(
        ("cp {bcmap} " +
         "${{{{ZIPDIR}}}}/$(dwarfdump -u -arch {arch} {binary} " +
         "| cut -d' ' -f2).bcsymbolmap").format(
             arch=arch,
             binary=binary_artifact.path,
             bcmap=bitcode_symbols.path))

  if not bitcode_symbol_inputs:
    return None

  zip_file = file_support.intermediate(ctx, "%{name}.bcsymbolmaps.zip")

  platform_support.xcode_env_action(
      ctx,
      inputs=[binary_artifact] + bitcode_symbol_inputs,
      outputs=[zip_file],
      command=["/bin/bash", "-c",
               ("set -e && " +
                "ZIPDIR=$(mktemp -d \"${{TMPDIR:-/tmp}}/support.XXXXXXXXXX\") && " +
                "trap \"rm -r ${{ZIPDIR}}\" EXIT && " +
                join_commands(copy_commands) + " && " +
                "pushd ${{ZIPDIR}} >/dev/null && " +
                "zip -qX -r {zip_name} . && " +
                "popd >/dev/null && " +
                "cp ${{ZIPDIR}}/{zip_name} {zip_path}"
               ).format(zip_name=zip_file.basename, zip_path=zip_file.path)
              ],
      mnemonic="BitcodeSymbolsCopy",
  )

  return zip_file


# Define the loadable module that lists the exported symbols in this file.
bitcode_actions = struct(
    zip_bitcode_symbols_maps=_zip_bitcode_symbols_maps,
)
