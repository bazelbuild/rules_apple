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
    "@build_bazel_rules_apple//apple/internal:entitlement_rules.bzl",
    "entitlements",
)

def _add_entitlements(
        name,
        platform_type,
        product_type,
        include_entitlements = True,
        is_stub = False,
        **kwargs):
    """Adds entitlements targets for a bundle target.

    This function creates an entitlements target to ensure that a binary
    created using the `link_multi_arch_binary` API or by copying a stub
    executable gets signed appropriately.

    Args:
      name: The name of the bundle target, from which the targets' names
          will be derived.
      platform_type: The platform type of the bundle.
      product_type: The product type of the bundle.
      include_entitlements: True/False, indicates whether to include an entitlements target.
          Defaults to True.
      is_stub: True/False, indicates whether the function is being called for a bundle that uses a
          stub executable.
      **kwargs: The arguments that were passed into the top-level macro.

    Returns:
      A modified copy of `**kwargs` that should be passed to the bundling rule.
    """
    bundling_args = dict(kwargs)
    tags = bundling_args.get("tags", None)
    testonly = bundling_args.get("testonly", None)

    additional_deps = []
    if include_entitlements:
        entitlements_value = bundling_args.get("entitlements")
        provisioning_profile = bundling_args.get("provisioning_profile")
        entitlements_name = "%s_entitlements" % name
        entitlements(
            name = entitlements_name,
            bundle_id = bundling_args.get("bundle_id"),
            entitlements = entitlements_value,
            platform_type = platform_type,
            product_type = product_type,
            provisioning_profile = provisioning_profile,
            tags = tags,
            testonly = testonly,
            validation_mode = bundling_args.get("entitlements_validation"),
        )

        # Replace the `entitlements` attribute with the preprocessed entitlements.
        bundling_args["entitlements"] = ":" + entitlements_name

        if not is_stub:
            # Also add the target as a dependency if the target is not a stub, since it may
            # propagate linkopts.
            additional_deps.append(":{}".format(entitlements_name))

    all_deps = bundling_args.get("deps", []) + additional_deps
    if all_deps:
        bundling_args["deps"] = all_deps

    return bundling_args

# Define the loadable module that lists the exported symbols in this file.
binary_support = struct(
    add_entitlements = _add_entitlements,
)
