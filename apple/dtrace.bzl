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

"""Bazel rules for working with dtrace."""

load("@bazel_skylib//lib:paths.bzl",
     "paths")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "apple_action",
     "label_scoped_path")
load("@build_bazel_rules_apple//common:path_utils.bzl",
     "path_utils")

def _dtrace_compile_impl(ctx):
  """Implementation for dtrace_compile."""
  output_hdrs = []

  for src in ctx.files.srcs:
    owner_relative_path = path_utils.owner_relative_path(src)
    label_scoped_owner_path = label_scoped_path(ctx.label, owner_relative_path)
    hdr = ctx.actions.declare_file(
        paths.replace_extension(label_scoped_owner_path, ".h"))
    output_hdrs.append(hdr)
    apple_action(
        ctx,
        inputs=[src],
        outputs=[hdr],
        mnemonic="dtraceCompile",
        executable="/usr/sbin/dtrace",
        arguments=["-h", "-s", src.path, "-o", hdr.path],
        use_default_shell_env=False,
        progress_message=("Compiling dtrace probes %s" % (src.basename)))

  return [DefaultInfo(files=depset(output_hdrs))]

dtrace_compile = rule(
    implementation=_dtrace_compile_impl,
    attrs={
        "srcs": attr.label_list(allow_files=[".d"], allow_empty=False),
    },
    output_to_genfiles=True,
)
"""
Compiles
[dtrace files with probes](https://www.ibm.com/developerworks/aix/library/au-dtraceprobes.html)
to generate header files to use those probes in C languages. The header files
generated will have the same name as the source files but with a .h extension.

Args:
  srcs: dtrace(.d) sources.
"""
