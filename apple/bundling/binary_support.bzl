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

"""Binary creation support functions."""

load(
    "@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
    "entitlements",
    "entitlements_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:provider_support.bzl",
    "provider_support",
)


def _get_binary_provider(ctx, provider_key):
  """Returns the provider from a rule's binary dependency.

  Bundling rules depend on binary rules via the "deps" attribute, which
  canonically supports a label list. This function validates that the
  "deps" attribute has only a single value, as is expected for bundling
  rules, before extracting and returning the provider of the given key.

  Args:
    ctx: The Skylark context.
    provider_key: The key of the provider to return.
  Returns:
    The provider propagated by the single "deps" target of the current rule.
  """
  if len(ctx.attr.deps) != 1:
    fail("Only one dependency (a binary target) should be specified " +
         "as a bundling rule dependency")
  providers = provider_support.matching_providers(
      ctx.attr.deps[0], provider_key)
  if providers:
    if len(providers) > 1:
      fail("Expected only one binary provider")
    return providers[0]
  return None


def _create_stub_binary_target(
    name,
    platform_type,
    product_type_info,
    **kwargs):
  """Creates a binary target for a bundle by copying a stub from the SDK.

  Some Apple bundles may not need a binary target depending on their product
  type; for example, watchOS applications and iMessage sticker packs contain
  stub binaries copied from the platform SDK, rather than binaries with user
  code. This function creates an `apple_stub_binary` target (instead of
  `apple_binary`) that ensures that the platform transition is correct (for
  platform selection in downstream dependencies) but that does not cause any
  user code to be linked.

  Args:
    name: The name of the bundle target, from which the binary target's name
        will be derived.
    platform_type: The platform type for which the binary should be copied.
    product_type_info: The information about the product type's stub executable.
    **kwargs: The arguments that were passed into the top-level macro.
  Returns:
    A modified copy of `**kwargs` that should be passed to the bundling rule.
  """
  bundling_args = dict(kwargs)

  apple_binary_name = "%s.apple_binary" % name
  minimum_os_version = kwargs.get("minimum_os_version")

  # Remove the deps so that we only pass them to the binary, not to the
  # bundling rule.
  deps = bundling_args.pop("deps", [])

  native.apple_stub_binary(
      name = apple_binary_name,
      minimum_os_version = minimum_os_version,
      platform_type = platform_type,
      xcenv_based_path = product_type_info.stub_path,
      deps = deps,
      tags = ["manual"] + kwargs.get("tags", []),
      testonly = kwargs.get("testonly"),
      visibility = kwargs.get("visibility"),
  )

  bundling_args["binary"] = apple_binary_name
  bundling_args["deps"] = [apple_binary_name]

  # For device builds, make sure that the stub binary still gets signed with the
  # appropriate entitlements (and that they have their substitutions applied).
  entitlements_value = kwargs.get("entitlements")
  provisioning_profile = kwargs.get("provisioning_profile")
  if entitlements and provisioning_profile:
    entitlements_name = "%s_entitlements" % name
    entitlements(
        name = entitlements_name,
        bundle_id = kwargs.get("bundle_id"),
        entitlements = entitlements_value,
        platform_type = platform_type,
        provisioning_profile = provisioning_profile,
    )
    bundling_args["entitlements"] = entitlements_support.device_file_label(
        entitlements_name)

  return bundling_args


def _create_linked_binary_target(
    name,
    platform_type,
    linkopts,
    sdk_frameworks=[],
    extension_safe=False,
    **kwargs):
  """Creates a binary target for a bundle by linking user code.

  This function also wraps the entitlements handling logic. It returns a
  modified copy of the given keyword arguments that has `binary` and
  `entitlements` attributes added if necessary and removes other
  binary-specific options (such as `linkopts`).

  Args:
    name: The name of the bundle target, from which the binary target's name
        will be derived.
    platform_type: The platform type for which the binary should be built.
    sdk_frameworks: Additional SDK frameworks that should be linked with the
        final binary.
    extension_safe: If true, compiles and links this framework with
        '-application-extension', restricting the binary to use only
        extension-safe APIs. False by default.
    **kwargs: The arguments that were passed into the top-level macro.
  Returns:
    A modified copy of `**kwargs` that should be passed to the bundling rule.
  """
  bundling_args = dict(kwargs)

  entitlements_value = bundling_args.pop("entitlements", None)
  minimum_os_version = kwargs.get("minimum_os_version")
  provisioning_profile = kwargs.get("provisioning_profile")

  if provisioning_profile:
    entitlements_name = "%s_entitlements" % name
    entitlements(
        name = entitlements_name,
        bundle_id = kwargs.get("bundle_id"),
        entitlements = entitlements_value,
        platform_type = platform_type,
        provisioning_profile = provisioning_profile,
    )
    bundling_args["entitlements"] = entitlements_support.device_file_label(
        entitlements_name)
    entitlements_srcs = [
        entitlements_support.simulator_file_label(entitlements_name)
    ]
    entitlements_deps = [":" + entitlements_name]
  else:
    entitlements_srcs = []
    entitlements_deps = []

  # Remove the deps so that we only pass them to the binary, not to the
  # bundling rule.
  deps = bundling_args.pop("deps", [])

  # Link the executable from any library deps and sources provided. Pass the
  # entitlements target as an extra dependency to the binary rule to pick up the
  # extra linkopts (if any) propagated by it.
  apple_binary_name = "%s.apple_binary" % name
  linkopts += ["-rpath", "@executable_path/../../Frameworks"]
  native.apple_binary(
      name = apple_binary_name,
      srcs = entitlements_srcs,
      dylibs = kwargs.get("frameworks"),
      extension_safe = extension_safe,
      features = kwargs.get("features"),
      linkopts = linkopts,
      minimum_os_version = minimum_os_version,
      platform_type = platform_type,
      sdk_frameworks = sdk_frameworks,
      deps = deps + entitlements_deps,
      tags = ["manual"] + kwargs.get("tags", []),
      testonly = kwargs.get("testonly"),
      visibility = kwargs.get("visibility"),
  )
  bundling_args["binary"] = apple_binary_name
  bundling_args["deps"] = [apple_binary_name]

  return bundling_args


def _create_binary(name, platform_type, **kwargs):
  """Creates a binary target for a bundle.

  This function checks the desired product type of the bundle and creates either
  an `apple_binary` or `apple_stub_binary` depending on what the product type
  needs. It must be called from one of the top-level application or extension
  macros, because it invokes a rule to create a target. As such, it cannot be
  called within rule implementation functions.

  Args:
    name: The name of the bundle target, from which the binary target's name
        will be derived.
    platform_type: The platform type for which the binary should be built.
    **kwargs: The arguments that were passed into the top-level macro.
  Returns:
    A modified copy of `**kwargs` that should be passed to the bundling rule.
  """
  args_copy = dict(kwargs)

  linkopts = args_copy.pop("linkopts", [])
  sdk_frameworks = args_copy.pop("sdk_frameworks", [])
  extension_safe = args_copy.pop("extension_safe", False)

  # If a user provides a "binary" attribute of their own, it is ignored and
  # silently overwritten below. Instead of allowing this, we should fail fast
  # to prevent confusion.
  if "binary" in args_copy:
    fail("Do not provide your own binary; one will be linked from your deps.",
         attr="binary")

  # Note the pop/get difference here. If the attribute is present as "private",
  # we want to pop it off so that it does not get passed down to the underlying
  # bundling rule (this is the macro's way of giving us default information in
  # the rule that we don't have access to yet). If the argument is present
  # without the underscore, then we leave it in so that the bundling rule can
  # access the value the user provided in their build target (if any).
  product_type = args_copy.pop("_product_type", None)
  if not product_type:
    product_type = args_copy.get("product_type")

  product_type_info = product_support.product_type_info(product_type)
  if product_type_info and product_type_info.stub_path:
    return _create_stub_binary_target(
        name, platform_type, product_type_info, **args_copy)
  else:
    return _create_linked_binary_target(
        name, platform_type, linkopts, sdk_frameworks, extension_safe,
        **args_copy)


# Define the loadable module that lists the exported symbols in this file.
binary_support = struct(
    create_binary=_create_binary,
    get_binary_provider=_get_binary_provider,
)
