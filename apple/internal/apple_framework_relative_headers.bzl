# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Implementation of apple_framework_relative_headers."""

load(
    "@build_bazel_rules_apple//apple/bundling:file_actions.bzl", 
    "file_actions"
)

def _apple_framework_relative_headers_impl(ctx):
  """Implementation for apple_framework_relative_headers rule."""
  output_dir = ctx.attr.framework_name + "_apple_framework_relative_headers"

  outputs = []
  for f in ctx.files.hdrs:
    framework_path =  "/".join([output_dir, ctx.attr.framework_name, f.basename])
    framework_header_file = ctx.actions.declare_file(framework_path)
    file_actions.symlink(ctx, f, framework_header_file)
    outputs.append(framework_header_file)

  include_dir = "/".join([
      ctx.configuration.bin_dir.path,
      ctx.label.workspace_root,
      ctx.label.package,
      output_dir
  ])
  return [
      apple_common.new_objc_provider(
          header=depset(outputs),
          include=depset([include_dir]),
      ),
      DefaultInfo(files=depset(outputs)),
  ]


apple_framework_relative_headers = rule(
    _apple_framework_relative_headers_impl,
    attrs = {
        "hdrs": attr.label_list(allow_files=[".h"], allow_empty=False),
        "framework_name": attr.string(mandatory=True),
        "_realpath": attr.label(
            cfg="host",
            allow_files=True,
            single_file=True,
            default=Label("@bazel_tools//tools/objc:realpath"),
        ),
    },
)
"""Creates a directory structure suitable for framework-relative import
statements.

For example, one would be able to #import <Foo/Bar.h> given the following rules:

    apple_framework_relative_headers(
      name = "FooFrameworkHeaders",
      hdrs = ["Source/Bar.h"],
      framework_name = "Foo",
    )

    objc_library(
      ...
      deps = [":FooFrameworkHeaders"],
    )

Args:
  hdrs: The list of header files.
  framework_name: The name of the framework.
"""
