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
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_runtime_linkopts",
)
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
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
        include_entitlements = True,
        is_stub = False,
        link_swift_statically = False,
        is_test = False,
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
      include_entitlements: True/False, indicates whether to include an entitlements target.
          Defaults to True.
      is_stub: True/False, indicates whether the function is being called for a bundle that uses a
          stub executable.
      link_swift_statically: True/False, indicates whether the static versions of the Swift standard
          libraries should be used during linking. Only used if include_swift_linkopts is True.
      is_test: True/False, indicates if test specific linker flags should be propagated.
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

    deps = bundling_args.get("deps", [])

    if not is_stub:
        # Propagate the linker flags that dynamically link the Swift runtime, if Swift was used. If
        # it wasn't, this target propagates no linkopts.
        additional_deps.append(
            _create_swift_runtime_linkopts_target(
                name,
                deps,
                link_swift_statically,
                is_test,
                tags = tags,
                testonly = testonly,
            ),
        )

    all_deps = deps + additional_deps
    if all_deps:
        bundling_args["deps"] = all_deps

    return bundling_args

def _create_binary(
        name,
        platform_type,
        product_type,
        binary_type = "executable",
        bundle_loader = None,
        extension_safe = False,
        link_swift_statically = False,
        sdk_frameworks = [],
        suppress_entitlements = False,
        target_name_template = "%s.__internal__.apple_binary",
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
      product_type: The product type of the bundle for which the binary will be built.
      binary_type: The type of binary to create. Can be "executable",
          "loadable_bundle" or "dylib".
      bundle_loader: Label to an apple_binary target that will act as the
          bundle_loader for this apple_binary. Can only be set if binary_type is
          "loadable_bundle".
      extension_safe: If true, compiles and links this framework with
          '-application-extension', restricting the binary to use only
          extension-safe APIs. False by default.
      link_swift_statically: True/False, indicates whether the static versions of
          the Swift standard libraries should be used during linking.
      sdk_frameworks: Additional SDK frameworks that should be linked with the
          final binary.
      suppress_entitlements: True/False, indicates that the entitlements() should
          be suppressed.
      target_name_template: A string that will be used to derive the name of the
          `apple_binary` target. This string must contain a single `%s`, which
          will be replaced by the name of the bundle target.
      **kwargs: The arguments that were passed into the top-level macro.

    Returns:
      A modified copy of `**kwargs` that should be passed to the bundling rule.
    """
    bundling_args = dict(kwargs)

    rule_descriptor = rule_support.rule_descriptor_no_ctx(platform_type, product_type)

    linkopts = kwargs.pop("linkopts", [])
    linkopts = linkopts + collections.before_each("-rpath", rule_descriptor.rpaths)
    linkopts = linkopts + rule_descriptor.extra_linkopts

    minimum_os_version = kwargs.get("minimum_os_version")
    provisioning_profile = kwargs.get("provisioning_profile")
    tags = bundling_args.get("tags", None)
    testonly = bundling_args.get("testonly", None)

    if suppress_entitlements:
        entitlements_deps = []
    else:
        entitlements_value = bundling_args.pop("entitlements", None)
        entitlements_name = "%s_entitlements" % name
        entitlements(
            name = entitlements_name,
            bundle_id = kwargs.get("bundle_id"),
            entitlements = entitlements_value,
            platform_type = platform_type,
            provisioning_profile = provisioning_profile,
            testonly = testonly,
            validation_mode = kwargs.get("entitlements_validation"),
        )
        bundling_args["entitlements"] = ":" + entitlements_name
        entitlements_deps = [":" + entitlements_name]

    # Remove the deps so that we only pass them to the binary, not to the
    # bundling rule.
    deps = bundling_args.pop("deps", [])

    # Propagate the linker flags that dynamically link the Swift runtime, if
    # Swift was used. If it wasn't, this target propagates no linkopts.
    swift_linkopts_deps = [
        _create_swift_runtime_linkopts_target(
            name,
            deps,
            link_swift_statically,
            is_test = testonly or False,
            tags = tags,
            testonly = testonly,
        ),
    ]

    # Link the executable from any library deps provided. Pass the entitlements
    # target as an extra dependency to the binary rule to pick up the extra
    # linkopts (if any) propagated by it.
    apple_binary_name = target_name_template % name
    native.apple_binary(
        name = apple_binary_name,
        binary_type = binary_type,
        bundle_loader = bundle_loader,
        dylibs = kwargs.get("frameworks"),
        extension_safe = extension_safe,
        features = kwargs.get("features"),
        linkopts = linkopts,
        minimum_os_version = minimum_os_version,
        platform_type = platform_type,
        sdk_frameworks = sdk_frameworks,
        deps = deps + entitlements_deps + swift_linkopts_deps,
        tags = ["manual", "notap"] + kwargs.get("tags", []),
        testonly = testonly,
        visibility = kwargs.get("visibility"),
    )
    bundling_args["deps"] = [":" + apple_binary_name]

    return bundling_args

# Define the loadable module that lists the exported symbols in this file.
binary_support = struct(
    add_entitlements_and_swift_linkopts = _add_entitlements_and_swift_linkopts,
    create_binary = _create_binary,
)
