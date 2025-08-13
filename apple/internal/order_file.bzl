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

"""
A rule for providing support for order files during build.
"""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _concatenate_files(*, actions, files, name):
    """Concatenates multiple files together.

    Args:
      actions: The ctx.actions associated with the rule.
      files: The files that should be concatenated. Order will be preserved.
      name: The ctx.attr.name associated with the rule.

    Returns:
      A declared file that contains the concatenated output.
    """

    out_file = actions.declare_file("%s_concat.order" % name)

    actions.run_shell(
        inputs = files,
        outputs = [out_file],
        progress_message = "Concatenating order files into %s" % out_file.short_path,
        arguments = [out_file.path] + [f.path for f in files],
        command = "cat ${@:2} > \"$1\"",
        mnemonic = "OrderFileConcatenation",
    )

    return out_file

def _dedup_file(*, actions, file, name):
    """Removes duplicate lines from a file.

    Args:
      actions: The ctx.actions associated with the rule.
      file: The file that should have its duplicate lines removed. Order will be preserved.
      name: The ctx.attr.name associated with the rule.

    Returns:
      A declared file that contains the deduplicated output.
    """

    out_file = actions.declare_file("%s_dedup.order" % name)

    actions.run_shell(
        inputs = [file],
        outputs = [out_file],
        progress_message = "Deduping order files into %s" % out_file.short_path,
        arguments = [file.path, out_file.path],
        command = "awk '!x[$$0]++' \"$1\" > \"$2\"",
        mnemonic = "OrderFileDeduplication",
    )

    return out_file

def _link_order_file(*, label, order_file, stats):
    """Returns a provider that will inject an order file during linking of the iOS application.

    Args:
      label: Label of the current target creating the order file.
      order_file: The final order file to be used during linking.
      stats: A boolean indicating whether to log stats about how the linker used the order file.
    """

    linkopts = ["-Wl,-order_file,%s" % order_file.path]
    if stats:
        linkopts.append("-Wl,-order_file_statistics")
    return CcInfo(
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset([
                cc_common.create_linker_input(
                    owner = label,
                    user_link_flags = linkopts,
                    additional_inputs = depset([order_file]),
                ),
            ]),
        ),
    )

def _order_file_impl(ctx):
    """Prepares a list of order files for inclusion into an iOS Application.

    Order files optimize the order of symbols in the binary, thus improving performance of the
    application. This method will concatenate multiple order files together, remove duplicate lines
    and prepare the linker commands necessary to apply the order files to the binary.

    Full details on the contents of order files are available at
    https://developer.apple.com/documentation/xcode/build-settings-reference#Order-File
    With additional details on how to generate an order file at
    https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/ImprovingLocality.html

    Args:
      ctx: The ctx associated with the rule.

    Returns:
      An array of Info objects for consumption by later stages of build.
    """

    if ctx.var["COMPILATION_MODE"] != "opt":
        # Apple's guidance: Generally you should not specify an order file in Debug or Development
        # configurations, as this will make the linked binary less readable to the debugger.
        # Use them only in Release or Deployment configurations.
        return [CcInfo()]

    concatenated_order_file = _concatenate_files(
        name = ctx.attr.name,
        actions = ctx.actions,
        files = ctx.files.srcs,
    )
    deduped_order_file = _dedup_file(
        name = ctx.attr.name,
        actions = ctx.actions,
        file = concatenated_order_file,
    )

    linker_cc_info = _link_order_file(
        label = ctx.label,
        order_file = deduped_order_file,
        stats = ctx.attr.stats,
    )

    return [
        linker_cc_info,
    ]

# This (apple_)order_file rule will inject order files into your application dependencies.
#
# See additional documentation in `_order_file_impl` above.
#
# Use like any other dependency in your BUILD. For example:
#
# apple_order_file(
#   name = "app_order_file"
#   srcs = [
#     "my_file.order",
#     "my_second_order_file.order",
#   ]
# )
#
# ios_application(
#   name = "app",
#   deps = [":app_order_file"],
# )
#
order_file = rule(
    implementation = _order_file_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "The raw text order files to be used in the iOS application.",
        ),
        "stats": attr.bool(
            default = False,
            doc = "Indicate whether to log stats about how the linker used the order file.",
        ),
    },
)
