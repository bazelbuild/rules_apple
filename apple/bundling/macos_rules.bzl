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

"""Rule implementations for creating macOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:macos.bzl instead. Bazel rules receive their name at
*definition* time based on the name of the global to which they are assigned.
We want the user to call macros that have the same name, to get automatic
binary creation, entitlements support, and other features--which requires a
wrapping macro because rules cannot invoke other rules.
"""

load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundler.bzl",
    "bundler",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
    "entitlements",
    "entitlements_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
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
    "AppleBundleInfo",
    "AppleBundleVersionInfo",
    "AppleResourceSet",
    "MacosApplicationBundleInfo",
    "MacosExtensionBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "merge_dictionaries",
)


def _macos_application_impl(ctx):
  """Implementation of the macos_application rule."""
  additional_resource_sets = []
  additional_resources = depset(ctx.files.app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  # TODO(b/36557429): Add support for macOS frameworks.
  embedded_bundles = [
      bundling_support.embedded_bundle(
          "PlugIns", extension[AppleBundleInfo], verify_bundle_id=True)
      for extension in ctx.attr.extensions
  ]

  binary_artifact = binary_support.get_binary_provider(
      ctx, apple_common.AppleExecutableBinary).binary
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacosApplicationArchive", "macOS application",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
  )

  # TODO(b/36556789): Add support for "bazel run".
  return struct(
      files=additional_outputs,
      providers=[
          MacosApplicationBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


macos_application = rule_factory.make_bundling_rule(
    _macos_application_impl,
    additional_attrs={
        "app_icons": attr.label_list(allow_files=True),
        "extensions": attr.label_list(
            providers=[[AppleBundleInfo, MacosExtensionBundleInfo]],
        ),
    },
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(
        ".provisionprofile", requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(allowed=["mac"]),
    path_formats=rule_factory.macos_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.macos,
    product_type=rule_factory.product_type(apple_product_type.application),
)


def _macos_command_line_application_impl(ctx):
  """Implementation of the macos_command_line_application rule."""
  output_path = ctx.outputs.executable.path

  # It's not hermetic to sign the binary that was built by the apple_binary
  # target that this rule takes as an input, so we copy it and then execute the
  # code signing commands on that copy in the same action.
  path_to_sign = codesigning_support.path_to_sign(output_path)
  signing_commands = codesigning_support.signing_command_lines(
      ctx, [path_to_sign], ctx.file.entitlements)

  platform_support.xcode_env_action(
      ctx,
      inputs=[ctx.file.binary],
      outputs=[ctx.outputs.executable],
      command=["/bin/bash", "-c",
               "cp {input_binary} {output_binary}".format(
                   input_binary=ctx.file.binary.path,
                   output_binary=output_path,
               ) + "\n" + signing_commands,
              ],
      mnemonic="SignBinary",
  )

  return []


macos_command_line_application = rule(
    _macos_command_line_application_impl,
    attrs=merge_dictionaries(
        rule_factory.common_tool_attributes,
        rule_factory.code_signing_attributes(rule_factory.code_signing(
            ".provisionprofile", requires_signing_for_device=False)
        ), {
            "binary": attr.label(
                mandatory=True,
                providers=[apple_common.AppleExecutableBinary],
                single_file=True,
            ),
            "bundle_id": attr.string(mandatory=False),
            "infoplists": attr.label_list(
                allow_files=[".plist"],
                mandatory=False,
                non_empty=False,
            ),
            "minimum_os_version": attr.string(mandatory=False),
            "version": attr.label(providers=[[AppleBundleVersionInfo]]),
            "_platform_type": attr.string(
                default=str(apple_common.platform_type.macos),
            ),
        }),
    executable=True,
    fragments=["apple", "objc"],
)


def _macos_extension_impl(ctx):
  """Implementation of the macos_extension rule."""
  additional_resource_sets = []
  additional_resources = depset(ctx.files.app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  binary_artifact = binary_support.get_binary_provider(
      ctx, apple_common.AppleExecutableBinary).binary
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacosExtensionArchive", "macOS extension",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_resource_sets=additional_resource_sets,
  )

  return struct(
      files=additional_outputs,
      providers=[
          MacosExtensionBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


macos_extension = rule_factory.make_bundling_rule(
    _macos_extension_impl,
    additional_attrs={
        "app_icons": attr.label_list(allow_files=True),
    },
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(
        ".provisionprofile", requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(allowed=["mac"]),
    path_formats=rule_factory.macos_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.macos,
    product_type=rule_factory.product_type(apple_product_type.app_extension),
    propagates_frameworks=True,
)
