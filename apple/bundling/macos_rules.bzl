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
    "@bazel_skylib//lib:dicts.bzl",
    "dicts"
)
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
    "@build_bazel_rules_apple//apple/bundling:debug_symbol_actions.bzl",
    "debug_symbol_actions",
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
    "MacosBundleBundleInfo",
    "MacosExtensionBundleInfo",
)
load(
    "@build_bazel_rules_apple//common:path_utils.bzl",
    "path_utils",
)
load(
    "@build_bazel_rules_apple//common:providers.bzl",
    "providers",
)

# Attributes that are common to all macOS bundles.
_COMMON_MACOS_BUNDLE_ATTRS = {
  "additional_contents": attr.label_keyed_string_dict(
      allow_files=True,
  ),
}


def _additional_contents_bundlable_files(ctx, file_map):
  """Gathers the additional Contents files in a macOS bundle.

  This function takes the label-keyed dictionary represented by `file_map` and
  gathers the files from all of those targets, transforming them into bundlable
  file objects that place the file in the appropriate subdirectory of the
  bundle's Contents folder.

  Args:
    ctx: The rule context.
    file_map: The label-keyed dictionary.
  Returns:
    A `depset` of bundlable files gathered from the targets.
  """
  bundlable_files = []

  for target, contents_subdir in file_map.items():
    bundlable_files.extend([bundling_support.contents_file(
        ctx, f, contents_subdir + "/" + path_utils.owner_relative_path(f),
    ) for f in target.files])

  return depset(bundlable_files)


def _macos_application_impl(ctx):
  """Implementation of the macos_application rule."""

  app_icons = ctx.files.app_icons
  if app_icons:
    bundling_support.ensure_single_asset_type(
        app_icons, ["appiconset"], "app_icons")

  additional_resource_sets = []
  additional_resources = depset(app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  # TODO(b/36557429): Add support for macOS frameworks.
  embedded_bundles = [
      bundling_support.embedded_bundle(
          "PlugIns", extension, verify_has_child_plist=True)
      for extension in ctx.attr.extensions
  ]

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).binary
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacosApplicationArchive", "macOS application",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_bundlable_files=_additional_contents_bundlable_files(
          ctx, ctx.attr.additional_contents),
      additional_resource_sets=additional_resource_sets,
      embedded_bundles=embedded_bundles,
      deps_objc_providers=[deps_objc_provider],
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
    additional_attrs=dicts.add(
        _COMMON_MACOS_BUNDLE_ATTRS,
        {
            "app_icons": attr.label_list(allow_files=True),
            # The default extension comes from the product type so it is not
            # repeated here.
            "bundle_extension": attr.string(),
            "extensions": attr.label_list(
                providers=[[AppleBundleInfo, MacosExtensionBundleInfo]],
            ),
        },
    ),
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(
        ".provisionprofile", requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(allowed=["mac"]),
    needs_pkginfo=True,
    path_formats=rule_factory.macos_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.macos,
    product_type=rule_factory.product_type(
        apple_product_type.application,
        values=[
            apple_product_type.application,
            apple_product_type.xpc_service,
        ],
    ),
)


def _macos_bundle_impl(ctx):
  """Implementation of the macos_bundle rule."""
  app_icons = ctx.files.app_icons
  if app_icons:
    bundling_support.ensure_single_asset_type(
        app_icons, ["appiconset"], "app_icons")

  additional_resource_sets = []
  additional_resources = depset(app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  # TODO(b/36557429): Add support for macOS frameworks.

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleLoadableBundleBinary).binary
  deps_objc_providers = providers.find_all(ctx.attr.deps, "objc")
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacosBundleArchive", "macOS executable bundle",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_bundlable_files=_additional_contents_bundlable_files(
          ctx, ctx.attr.additional_contents),
      additional_resource_sets=additional_resource_sets,
      deps_objc_providers=deps_objc_providers,
  )

  # TODO(b/36556789): Add support for "bazel run".
  return struct(
      files=additional_outputs,
      providers=[
          MacosBundleBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


macos_bundle = rule_factory.make_bundling_rule(
    _macos_bundle_impl,
    additional_attrs=dicts.add(
        _COMMON_MACOS_BUNDLE_ATTRS,
        {
            "app_icons": attr.label_list(allow_files=True),
            # The default extension comes from the product type so it is not
            # repeated here.
            "bundle_extension": attr.string(),
        },
    ),
    archive_extension=".zip",
    binary_providers=[apple_common.AppleLoadableBundleBinary],
    code_signing=rule_factory.code_signing(
        ".provisionprofile", requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(allowed=["mac"]),
    path_formats=rule_factory.macos_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.macos,
    product_type=rule_factory.product_type(
        apple_product_type.bundle,
        values=[
            apple_product_type.bundle,
            apple_product_type.kernel_extension,
            apple_product_type.spotlight_importer,
        ],
    ),
)


def _macos_command_line_application_impl(ctx):
  """Implementation of the macos_command_line_application rule."""
  output_path = ctx.outputs.executable.path

  outputs = []

  debug_outputs = ctx.attr.binary[apple_common.AppleDebugOutputs]
  if debug_outputs:
    # Create a .dSYM bundle with the expected name next to the binary in the
    # output directory.
    if ctx.fragments.objc.generate_dsym:
      symbol_bundle = debug_symbol_actions.create_symbol_bundle(ctx,
          debug_outputs, ctx.label.name)
      outputs.extend(symbol_bundle)

    if ctx.fragments.objc.generate_linkmap:
      linkmaps = debug_symbol_actions.collect_linkmaps(ctx, debug_outputs,
          ctx.label.name)
      outputs.extend(linkmaps)

  # It's not hermetic to sign the binary that was built by the apple_binary
  # target that this rule takes as an input, so we copy it and then execute the
  # code signing commands on that copy in the same action.
  path_to_sign = codesigning_support.path_to_sign(output_path)
  signing_commands = codesigning_support.signing_command_lines(
      ctx, [path_to_sign], None)

  inputs = [ctx.file.binary]

  platform_support.xcode_env_action(
      ctx,
      inputs=inputs,
      outputs=[ctx.outputs.executable],
      command=["/bin/bash", "-c",
               "cp {input_binary} {output_binary}".format(
                   input_binary=ctx.file.binary.path,
                   output_binary=output_path,
               ) + "\n" + signing_commands,
              ],
      mnemonic="SignBinary",
  )

  outputs.append(ctx.outputs.executable)
  return [DefaultInfo(files=depset(direct=outputs))]


macos_command_line_application = rule(
    _macos_command_line_application_impl,
    attrs=dicts.add(
        rule_factory.common_tool_attributes,
        rule_factory.code_signing_attributes(rule_factory.code_signing(
            ".provisionprofile", requires_signing_for_device=False)
        ), {
            # TODO(b/73292865): Replace "binary" with "deps" when Tulsi
            # migrates off of "binary".
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
  app_icons = ctx.files.app_icons
  if app_icons:
    bundling_support.ensure_single_asset_type(
        app_icons, ["appiconset"], "app_icons")

  additional_resource_sets = []
  additional_resources = depset(app_icons)
  if additional_resources:
    additional_resource_sets.append(AppleResourceSet(
        resources=additional_resources,
    ))

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).binary
  deps_objc_provider = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleExecutableBinary).objc
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacosExtensionArchive", "macOS extension",
      ctx.attr.bundle_id,
      binary_artifact=binary_artifact,
      additional_bundlable_files=_additional_contents_bundlable_files(
          ctx, ctx.attr.additional_contents),
      additional_resource_sets=additional_resource_sets,
      deps_objc_providers=[deps_objc_provider],
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
    additional_attrs=dicts.add(
        _COMMON_MACOS_BUNDLE_ATTRS,
        {
            "app_icons": attr.label_list(allow_files=True),
        },
    ),
    archive_extension=".zip",
    code_signing=rule_factory.code_signing(
        ".provisionprofile", requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(allowed=["mac"]),
    path_formats=rule_factory.macos_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.macos,
    product_type=rule_factory.product_type(
        apple_product_type.app_extension, private=True,
    ),
    propagates_frameworks=True,
)
