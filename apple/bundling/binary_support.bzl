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

load("//apple/bundling:entitlements.bzl",
     "entitlements",
     "entitlements_support")
load("//apple/bundling:product_support.bzl",
     "product_support")


def _create_binary_if_necessary(
    name,
    platform_type,
    sdk_frameworks=[],
    **kwargs):
  """Creates a binary target if necessary for a bundle.

  This function also wraps the entitlements handling logic. It returns a
  modified copy of the given keyword arguments that has `binary` and
  `entitlements` attributes added if necessary and removes other
  binary-specific options (such as `linkopts`).

  Some Apple bundles may not need a binary target depending on their product
  type; for example, watchOS applications and iMessage sticker packs contain
  stub binaries copied from the platform SDK, rather than binaries with user
  code.

  This function must be called from one of the top-level application or
  extension macros, because it invokes a rule to create a target. As such, it
  cannot be called within rule implementation functions.

  Args:
    name: The name of the bundle target, from which the binary target's name
        will be derived.
    platform_type: The platform type for which the binary should be built.
    sdk_frameworks: Additional SDK frameworks that should be linked with the
        final binary.
    **kwargs: The arguments that were passed into the top-level macro.
  Returns:
    A modified copy of `**kwargs` that should be passed to the bundling rule.
  """
  bundling_args = dict(kwargs)

  # If a user provides a "binary" attribute of their own, it is ignored and
  # silently overwritten below. Instead of allowing this, we should fail fast
  # to prevent confusion.
  if "binary" in bundling_args:
    fail("Do not provide your own binary; one will be linked from your deps.",
         attr="binary")

  entitlements_value = bundling_args.pop("entitlements", None)
  linkopts = bundling_args.pop("linkopts", [])
  provisioning_profile = kwargs.get("provisioning_profile")

  if provisioning_profile:
    # Generate the debug and device entitlements regardless of whether we're
    # creating a binary or using a stub.
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

  # Now, figure out if the product type uses a stub binary. If not, create the
  # target for the user's binary.
  product_info = None
  product_type = (kwargs.get("product_type") or
                  bundling_args.pop("_product_type", None))
  if product_type:
    product_info = product_support.product_type_info(product_type)

  if not product_info:
    deps = kwargs.get("deps", [])
    dylibs = kwargs.get("frameworks")
    if not deps:
      fail("This target must provide deps because it is of a product type " +
           "that requires a user binary.")

    # Link the executable from any library deps and sources provided.
    apple_binary_name = "%s.apple_binary" % name
    linkopts += ["-rpath", "@executable_path/../../Frameworks"]

    # Pass the entitlements target as an extra dependency to the binary rule
    # to pick up the extra linkopts (if any) propagated by it.
    native.apple_binary(
        name = apple_binary_name,
        srcs = entitlements_srcs,
        features = kwargs.get("features"),
        linkopts = linkopts,
        platform_type = platform_type,
        sdk_frameworks = sdk_frameworks,
        deps = deps + entitlements_deps,
        dylibs = dylibs,
        tags = kwargs.get("tags"),
        testonly = kwargs.get("testonly"),
        visibility = kwargs.get("visibility"),
    )
    bundling_args["binary"] = apple_binary_name

  return bundling_args


# Define the loadable module that lists the exported symbols in this file.
binary_support = struct(
    create_binary_if_necessary=_create_binary_if_necessary,
)
