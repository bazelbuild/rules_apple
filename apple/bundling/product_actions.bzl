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

"""Actions to manipulate support files for Apple product types."""

load(
    "@bazel_skylib//lib:shell.bzl",
    "shell"
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)


def _create_stub_zip_for_archive_merging(ctx, stub_binary, stub_descriptor):
  """Registers an action that creates a ZIP of a stub executable.

  When uploading an archive to Apple, product types that involve stub
  executables need those executables copied into appropriate locations inside
  the archive root. This function creates a ZIP with the correct file structure
  so that it can be propagated up to an application archive for merging.

  Args:
    ctx: The Skylark context.
    stub_binary: The stub binary executable to ZIP.
    stub_descriptor: The stub descriptor.

  Returns:
    A `File` that is the zip that should be merged into the archive root.
  """
  product_support_zip = ctx.actions.declare_file(
      ctx.label.name + "-Support.zip")
  product_support_path = shell.quote(product_support_zip.path)
  product_support_basename = product_support_zip.basename
  archive_path = shell.quote(stub_descriptor.path_in_archive)

  platform = platform_support.platform(ctx)
  platform_name = platform.name_in_plist

  # TODO(b/23975430): Remove the /bin/bash workaround once this bug is fixed.
  platform_support.xcode_env_action(
      ctx,
      inputs=[stub_binary],
      outputs=[product_support_zip],
      command=[
          "/bin/bash", "-c",
          ("set -e && " +
           "PLATFORM_DIR=\"${{DEVELOPER_DIR}}/Platforms/" +
           "{platform_name}.platform\" && " +
           "ZIPDIR=$(mktemp -d \"${{TMPDIR:-/tmp}}/support.XXXXXXXXXX\") && " +
           "trap \"rm -r ${{ZIPDIR}}\" EXIT && " +
           "mkdir -p ${{ZIPDIR}}/$(dirname {archive_path}) && " +
           "cp {file_path} ${{ZIPDIR}}/{archive_path} && " +
           "pushd ${{ZIPDIR}} >/dev/null && " +
           "zip -qX -r {product_support_basename} . && " +
           "popd >/dev/null && " +
           "mv ${{ZIPDIR}}/{product_support_basename} {product_support_path}"
          ).format(
              archive_path=archive_path,
              file_path=shell.quote(stub_binary.path),
              platform_name=platform_name,
              product_support_basename=product_support_basename,
              product_support_path=product_support_path,
          ),
      ],
      mnemonic="ZipStubExecutable",
      no_sandbox=True,
  )

  return product_support_zip


# Define the loadable module that lists the exported symbols in this file.
product_actions = struct(
    create_stub_zip_for_archive_merging=_create_stub_zip_for_archive_merging,
)
