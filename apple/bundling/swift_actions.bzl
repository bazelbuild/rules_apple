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

"""Actions used to copy Swift libraries into the bundle."""

load("//apple/bundling:file_support.bzl", "file_support")
load("//apple/bundling:platform_support.bzl",
     "platform_support")


def _zip_swift_dylibs(ctx):
  """Registers an action that creates a ZIP that contains Swift dylibs.

  This action scans the binary associated with the target being built and
  determines which Swift dynamic libraries need to be included in that
  bundle. Some bundle types, like applications, will bundle them in their
  Frameworks directory (as well as an archive-root SwiftSupport directory for
  release builds); others, like extensions, will simply propagate them to the
  host application.

  Args:
    ctx: The Skylark context.
  Returns:
    A `File` object representing the ZIP file containing the Swift dylibs.
  """
  platform, _ = platform_support.platform_and_sdk_version(ctx)

  xcrun_args = []
  if ctx.fragments.apple.xcode_toolchain:
    xcrun_args += ["--toolchain", ctx.fragments.apple.xcode_toolchain]

  zip_file = file_support.intermediate(ctx, "%{name}.swiftlibs.zip")
  platform_support.xcode_env_action(
      ctx,
      inputs=[ctx.file.binary],
      outputs=[zip_file],
      executable=ctx.executable._swiftstdlibtoolwrapper,
      arguments=xcrun_args + [
          "--output_zip_path",
          zip_file.path,
          "--bundle_path",
          ".",
          "--platform",
          platform.name_in_plist.lower(),
          "--scan-executable",
          ctx.file.binary.path,
      ],
      mnemonic="SwiftStdlibCopy",
      no_sandbox=True,
  )
  return zip_file


# Define the loadable module that lists the exported symbols in this file.
swift_actions = struct(
    zip_swift_dylibs=_zip_swift_dylibs,
)
