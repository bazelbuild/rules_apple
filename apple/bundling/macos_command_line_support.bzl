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
# limitations under the Lice

"""Internal helper definitions used by macOS command line rules."""

load(
    "@build_bazel_rules_apple//apple/bundling:plist_actions.bzl",
    "plist_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleVersionInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "bash_quote",
    "merge_dictionaries",
)

# The stub function that is linked into the executable to cause the inline
# asm in the file to be pulled in.
_EMBEDDED_PLIST_SYMBOL = "__BAZEL_INFOPLIST_LINKAGE__"


def _create_infoplist_section_file(ctx, infoplist):
  """Creates a C source file that embeds an Info.plist in a special section.

  This is not currently compatible with Bitcode (because it requires the -u
  linker option). We acknowledge this for now because it's highly unlikely that
  someone is going to build a macOS command line tool with Bitcode enabled.

  TODO(b/63662425): Replace this logic with the
  `-sectcreate __TEXT __info_plist` linker flags once link_inputs are passed to
  CROSSTOOL correctly.

  Args:
    ctx: The rule context.
    infoplist: The `File` representing the plist to be embedded.
  """
  symbol_function = "void %s(){}" % _EMBEDDED_PLIST_SYMBOL
  infoplist_path = bash_quote(infoplist.path)

  source_path = bash_quote(ctx.outputs.section_source.path)
  ctx.action(
      inputs=[infoplist],
      outputs=[ctx.outputs.section_source],
      command=(
          "set -e && " +
          "echo " +
          "\"" + symbol_function + "\n\n\" >> " + source_path + " && " +
          "xxd -i " + infoplist_path + " | sed -e '1 s/^.*$/" +
          "__asm(\".section __TEXT,__info_plist\");__asm(\".byte /'" +
          " -e 's/$/ \\\\/' -e '$d' | sed -e '$ s/^.*$/\");/'" +
          " >> " + source_path + " && " +
          "echo \"\n\" >> " + source_path
      ),
      mnemonic = "GenerateInfoPlistSectionSource",
  )


def _infoplist_linkopts():
  """Returns the linkopts needed to link the Info.plist section into the binary.

  Returns:
    The linkopts needed to link the Info.plist section into the binary.
  """
  return ["-u", "_" + _EMBEDDED_PLIST_SYMBOL]


def _infoplist_source_label(name):
  return name + ".infoplist_section.c"


def _macos_command_line_infoplist_impl(ctx):
  """Implementation of the internal `macos_command_line_infoplist` rule.

  This rule is an internal implementation detail of
  `macos_command_line_application` and should not be used directly by clients.
  It merges Info.plists as would occur for a bundle but then propagates an
  `objc` provider with the necessary linkopts to embed the plist in a binary.

  Args:
    ctx: The rule context.
  Returns:
    A `struct` containing the `objc` provider that should be propagated to a
    binary that should have this plist embedded.
  """
  bundle_id = ctx.attr.bundle_id
  infoplists = ctx.files.infoplists
  if ctx.attr.version and AppleBundleVersionInfo in ctx.attr.version:
    version = ctx.attr.version[AppleBundleVersionInfo]
  else:
    version = None

  if not bundle_id and not infoplists and not version:
    fail("Internal error: at least one of bundle_id, infoplists, or version " +
         "should have been provided")

  plist_results = plist_actions.merge_infoplists(
      ctx,
      None,
      infoplists,
      bundle_id=bundle_id,
      executable_bundle=True,
      exclude_executable_name=True)
  merged_infoplist = plist_results.output_plist

  _create_infoplist_section_file(ctx, merged_infoplist)

  return struct(
      objc=apple_common.new_objc_provider(
          linkopt=depset(_infoplist_linkopts(), order="topological"),
      ))


macos_command_line_infoplist = rule(
    _macos_command_line_infoplist_impl,
    attrs=merge_dictionaries(
        rule_factory.common_tool_attributes,
        {
            "bundle_id": attr.string(mandatory=False),
            "infoplists": attr.label_list(
                allow_files=[".plist"],
                mandatory=False,
                non_empty=False,
            ),
            "minimum_os_version": attr.string(mandatory=False),
            "version": attr.label(providers=[[AppleBundleVersionInfo]]),
            "_allowed_families": attr.string_list(default=["mac"]),
            "_needs_pkginfo": attr.bool(default=False),
            "_platform_type": attr.string(
                default=str(apple_common.platform_type.macos),
            ),
            "_product_type": attr.string(default=apple_product_type.tool),
        }),
    fragments=["apple", "objc"],
    outputs={"section_source": _infoplist_source_label("%{name}")},
)


# Define the loadable module that lists the exported symbols in this file.
macos_command_line_support = struct(
    infoplist_source_label=_infoplist_source_label,
)