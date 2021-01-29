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
load(
    "@build_bazel_rules_apple//apple/internal:exported_symbols_lists_rules.bzl",
    "exported_symbols_lists",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_runtime_linkopts",
)

def _create_swift_runtime_linkopts_target(
        name,
        deps,
        is_static,
        is_test,
        tags,
        testonly):
    """Creates a build target to propagate Swift runtime linker flags.

    Args:
      name: The name of the base target.
      deps: The list of dependencies of the base target.
      is_static: True to use the static Swift runtime, or False to use the
          dynamic Swift runtime.
      is_test: True to make sure test specific linkopts are propagated.
      tags: Tags to add to the created targets.
      testonly: Whether the target should be testonly.

    Returns:
      A build label that can be added to the deps of the binary target.
    """
    swift_runtime_linkopts_name = name + ".swift_runtime_linkopts"
    swift_runtime_linkopts(
        name = swift_runtime_linkopts_name,
        is_static = is_static,
        is_test = is_test,
        testonly = testonly,
        tags = tags,
        deps = deps,
    )
    return ":" + swift_runtime_linkopts_name

def _add_entitlements_and_swift_linkopts(
        name,
        platform_type,
        product_type,
        include_entitlements = True,
        is_stub = False,
        link_swift_statically = False,
        is_test = False,
        exported_symbols_lists = None,
        **kwargs):
    """Adds entitlements and Swift linkopts targets for a bundle target.

    This function creates an entitlements target to ensure that a binary
    created using the `link_multi_arch_binary` API or by copying a stub
    executable gets signed appropriately.

    Similarly, for bundles with user-provided binaries, this function also
    adds any Swift linkopts that are necessary for it to link correctly.

    Args:
      name: The name of the bundle target, from which the targets' names
          will be derived.
      platform_type: The platform type of the bundle.
      product_type: The product type of the bundle.
      include_entitlements: True/False, indicates whether to include an entitlements target.
          Defaults to True.
      is_stub: True/False, indicates whether the function is being called for a bundle that uses a
          stub executable.
      link_swift_statically: True/False, indicates whether the static versions of the Swift standard
          libraries should be used during linking. Only used if include_swift_linkopts is True.
      is_test: True/False, indicates if test specific linker flags should be propagated.
      exported_symbols_lists: A list of text files representing exported symbols lists that should
          be linked with thefinal binary.
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

    exported_symbols_list_deps = _add_exported_symbols_lists(
        name,
        exported_symbols_lists,
    )

    deps = bundling_args.get("deps", [])

    if not is_stub:
        # Propagate the linker flags that dynamically link the Swift runtime, if Swift was used. If
        # it wasn't, this target propagates no linkopts.
        additional_deps.append(
            _create_swift_runtime_linkopts_target(
                name,
                deps,
                link_swift_statically,
                bool(is_test or testonly),
                tags = tags,
                testonly = testonly,
            ),
        )

    all_deps = deps + additional_deps + exported_symbols_list_deps
    if all_deps:
        bundling_args["deps"] = all_deps

    return bundling_args

def _add_exported_symbols_lists(name, exported_symbols_lists_value):
    """Adds one or more exported symbols lists to a bundle target.

    These lists are references to files that provide a list of global symbol names that will remain
    as global symbols in the output file. All other global symbols will be treated as if they were
    marked as __private_extern__ (aka visibility=hidden) and will not be global in the output file.
    See the man page documentation for ld(1) on macOS for more details.

    Args:
      name: The name of the bundle target, from which the binary target's name will be derived.
      exported_symbols_lists_value: A list of text files representing exported symbols lists that
          should be linked with thefinal binary.

    Returns:
      A modified copy of `**kwargs` that should be passed to the bundling rule.
    """
    if exported_symbols_lists_value:
        exported_symbols_lists_name = "%s_exported_symbols_lists" % name
        exported_symbols_lists(
            name = exported_symbols_lists_name,
            lists = exported_symbols_lists_value,
        )
        exported_symbols_list_deps = [":" + exported_symbols_lists_name]
    else:
        exported_symbols_list_deps = []

    return exported_symbols_list_deps

# Define the loadable module that lists the exported symbols in this file.
binary_support = struct(
    add_entitlements_and_swift_linkopts = _add_entitlements_and_swift_linkopts,
)
