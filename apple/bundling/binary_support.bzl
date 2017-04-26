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

load("@build_bazel_rules_apple//apple/bundling:entitlements.bzl",
     "entitlements",
     "entitlements_support")


def _create_binary(
    name,
    platform_type,
    sdk_frameworks=[],
    **kwargs):
  """Creates a binary target for a bundle.

  This function also wraps the entitlements handling logic. It returns a
  modified copy of the given keyword arguments that has `binary` and
  `entitlements` attributes added if necessary and removes other
  binary-specific options (such as `linkopts`).

  Some Apple bundles may not need a binary target depending on their product
  type; for example, watchOS applications and iMessage sticker packs contain
  stub binaries copied from the platform SDK, rather than binaries with user
  code. This function creates the target anyway (because `apple_binary` is where
  the platform transition occurs, which allows dependencies to select on it
  properly), but the bundler will not use the binary artifact if it is not
  needed; in these cases, even though the target will be created in the graph,
  it will not actually be linked.

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
      features = kwargs.get("features"),
      linkopts = linkopts,
      platform_type = platform_type,
      sdk_frameworks = sdk_frameworks,
      deps = deps + entitlements_deps,
      dylibs = kwargs.get("frameworks"),
      tags = kwargs.get("tags"),
      testonly = kwargs.get("testonly"),
      visibility = kwargs.get("visibility"),
  )
  bundling_args["binary"] = apple_binary_name

  return bundling_args


# Define the loadable module that lists the exported symbols in this file.
binary_support = struct(
    create_binary=_create_binary,
)
