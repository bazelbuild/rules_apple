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

load("//apple/bundling:file_support.bzl", "file_support")
load("//apple/bundling:platform_support.bzl",
     "platform_support")
load("//apple:utils.bzl", "bash_quote")


def _copy_stub_for_bundle(ctx, product_info):
  """Registers an action that copies a stub executable from the SDK.

  Args:
    ctx: The Skylark context.
    product_info: The product type info struct.
  Returns:
    A `File` that is a copy of the stub executable and has the same name as the
    bundle (just as a user-provided binary would).
  """
  file_path = '"' + product_info.stub_path + '"'
  stub_binary = file_support.intermediate(ctx, "%{name}.stub_binary")

  platform, _ = platform_support.platform_and_sdk_version(ctx)
  platform_name = platform.name_in_plist

  platform_support.xcode_env_action(
      ctx,
      inputs=[],
      outputs=[stub_binary],
      command=[
          "/bin/bash", "-c",
          ("set -e && " +
           "PLATFORM_DIR=\"${{DEVELOPER_DIR}}/Platforms/" +
           "{platform_name}.platform\" && " +
           "cp {file_path} {stub_binary}"
          ).format(
              file_path=file_path,
              platform_name=platform_name,
              stub_binary=stub_binary.path,
          ),
      ],
      mnemonic="CopyStubExecutable",
      no_sandbox=True,
  )

  return stub_binary


def _create_stub_zip_for_archive_merging(ctx, product_info):
  """Registers an action that creates a ZIP of a stub executable.

  When uploading an archive to Apple, product types that involve stub
  executables need those executables copied into appropriate locations inside
  the archive root. This function creates a ZIP with the correct file structure
  so that it can be propagated up to an application archive for merging.

  Args:
    ctx: The Skylark context.
    product_info: The product type info struct.
  Returns:
    A `File` that is the zip that should be merged into the archive root.
  """
  product_support_zip = ctx.new_file(ctx.label.name + "-Support.zip")
  product_support_path = bash_quote(product_support_zip.path)
  product_support_basename = product_support_zip.basename
  file_path = '"' + product_info.stub_path + '"'
  archive_path = bash_quote(product_info.archive_path)

  platform, _ = platform_support.platform_and_sdk_version(ctx)
  platform_name = platform.name_in_plist

  # TODO(b/23975430): Remove the /bin/bash workaround once this bug is fixed.
  platform_support.xcode_env_action(
      ctx,
      inputs=[],
      outputs=[product_support_zip],
      command=[
          "/bin/bash", "-c",
          ("set -e && " +
           "PLATFORM_DIR=\"${{DEVELOPER_DIR}}/Platforms/" +
           "{platform_name}.platform\" && " +
           "ZIPDIR=$(mktemp -d \"${{TMPDIR:-/tmp}}/support.XXXXXXXXXX\") && " +
           "trap \"rm -r ${{ZIPDIR}}\" EXIT && " +
           "pushd ${{ZIPDIR}} >/dev/null && " +
           "mkdir -p $(dirname {archive_path}) && " +
           "cp {file_path} {archive_path} && " +
           "zip -qX -r {product_support_basename} . && " +
           "popd >/dev/null && " +
           "mv ${{ZIPDIR}}/{product_support_basename} {product_support_path}"
          ).format(
              archive_path=archive_path,
              file_path=file_path,
              platform_name=platform_name,
              product_support_basename=product_support_basename,
              product_support_path=product_support_path,
          ),
      ],
      mnemonic = "ZipStubExecutable",
      no_sandbox=True,
  )

  return product_support_zip


# Define the loadable module that lists the exported symbols in this file.
product_actions = struct(
    copy_stub_for_bundle=_copy_stub_for_bundle,
    create_stub_zip_for_archive_merging=_create_stub_zip_for_archive_merging,
)
