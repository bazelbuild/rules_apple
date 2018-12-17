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
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:swift_support.bzl",
    "swift_runtime_linkopts",
)
load(
    "@build_bazel_rules_apple//common:providers.bzl",
    "providers",
)

def _get_binary_provider(deps, provider_key):
    """Returns the provider from a rule's binary dependency.

    Bundling rules depend on binary rules via the "deps" attribute, which
    canonically supports a label list. This function validates that the
    "deps" attribute has only a single value, as is expected for bundling
    rules, before extracting and returning the provider of the given key.

    Args:
      deps: The list of the target's dependencies.
      provider_key: The key of the provider to return.

    Returns:
      The provider propagated by the single "deps" target of the current rule.
    """
    matching_providers = providers.find_all(deps, provider_key)
    if matching_providers:
        if len(matching_providers) > 1:
            fail("Expected only one binary provider")
        return matching_providers[0]
    return None

def _create_swift_runtime_linkopts_target(
        name,
        deps,
        is_static,
        testonly = None):
    """Creates a build target to propagate Swift runtime linker flags.

    Args:
      name: The name of the base target.
      deps: The list of dependencies of the base target.
      is_static: True to use the static Swift runtime, or False to use the
          dynamic Swift runtime.
      testonly: Whether the target should be testonly.

    Returns:
      A build label that can be added to the deps of the binary target.
    """
    swift_runtime_linkopts_name = name + ".swift_runtime_linkopts"
    swift_runtime_linkopts(
        name = swift_runtime_linkopts_name,
        is_static = is_static,
        testonly = testonly,
        deps = deps,
    )
    return ":" + swift_runtime_linkopts_name

def _add_entitlements_and_swift_linkopts(
        name,
        platform_type,
        is_stub = False,
        link_swift_statically = False,
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
      is_stub: True/False, indicates whether the function is being called for a
          bundle that uses a stub executable.
      link_swift_statically: True/False, indicates whether the static versions of
          the Swift standard libraries should be used during linking.
      **kwargs: The arguments that were passed into the top-level macro.

    Returns:
      A modified copy of `**kwargs` that should be passed to the bundling rule.
    """
    bundling_args = dict(kwargs)
    testonly = bundling_args.get("testonly", None)

    entitlements_value = kwargs.get("entitlements")
    provisioning_profile = kwargs.get("provisioning_profile")
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

    entitlements_deps = [] if is_stub else [":" + entitlements_name]

    # This is required by the configuration transition on the 'deps' attribute
    # of the bundling rule.
    bundling_args["platform_type"] = platform_type

    # Propagate the linker flags that dynamically link the Swift runtime, if
    # Swift was used. If it wasn't, this target propagates no linkopts.
    deps = bundling_args.get("deps", [])

    if is_stub:
        swift_linkopts_deps = []
    else:
        swift_linkopts_deps = [
            _create_swift_runtime_linkopts_target(
                name,
                deps,
                link_swift_statically,
                testonly = testonly,
            ),
        ]

    bundling_args["deps"] = deps + entitlements_deps + swift_linkopts_deps

    return bundling_args

def _create_linked_binary_target(
        name,
        platform_type,
        linkopts,
        binary_type = "executable",
        sdk_frameworks = [],
        extension_safe = False,
        bundle_loader = None,
        link_swift_statically = False,
        suppress_entitlements = False,
        target_name_template = "%s.apple_binary",
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
      linkopts: Extra linking options to be passed to the binary target.
      binary_type: The type of binary to create. Can be "executable",
          "loadable_bundle" or "dylib".
      sdk_frameworks: Additional SDK frameworks that should be linked with the
          final binary.
      extension_safe: If true, compiles and links this framework with
          '-application-extension', restricting the binary to use only
          extension-safe APIs. False by default.
      bundle_loader: Label to an apple_binary target that will act as the
          bundle_loader for this apple_binary. Can only be set if binary_type is
          "loadable_bundle".
      link_swift_statically: True/False, indicates whether the static versions of
          the Swift standard libraries should be used during linking.
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

    minimum_os_version = kwargs.get("minimum_os_version")
    provisioning_profile = kwargs.get("provisioning_profile")
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
            testonly = testonly,
        ),
    ]

    # TODO(b/62481675): Move these linkopts to CROSSTOOL features.
    additional_linkopts = ["-rpath", "@executable_path/../../Frameworks"]
    if bundling_args.get("product_type") == apple_product_type.kernel_extension:
        additional_linkopts = []

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
        linkopts = linkopts + additional_linkopts,
        minimum_os_version = minimum_os_version,
        platform_type = platform_type,
        sdk_frameworks = sdk_frameworks,
        deps = deps + entitlements_deps + swift_linkopts_deps,
        tags = ["manual"] + kwargs.get("tags", []),
        testonly = testonly,
        visibility = kwargs.get("visibility"),
    )
    bundling_args["binary"] = apple_binary_name
    bundling_args["deps"] = [":" + apple_binary_name]

    return bundling_args

def _create_binary(
        name,
        platform_type,
        link_swift_statically = False,
        suppress_entitlements = False,
        **kwargs):
    """Creates a binary target for a bundle.

    This function creates either an `apple_binary`. It must be called from one of the top-level
    application or extension macros, because it invokes a rule to create a target. As such, it
    cannot be called within rule implementation functions.

    Args:
      name: The name of the bundle target, from which the binary target's name
          will be derived.
      platform_type: The platform type for which the binary should be built.
      link_swift_statically: True/False, indicates whether the static versions of
          the Swift standard libraries should be used during linking.
      suppress_entitlements: True/False, indicates that the entitlements() should
          be suppressed.
      **kwargs: The arguments that were passed into the top-level macro.

    Returns:
      A modified copy of `**kwargs` that should be passed to the bundling rule.
    """
    args_copy = dict(kwargs)

    binary_type = args_copy.pop("binary_type", "executable")
    linkopts = args_copy.pop("linkopts", [])
    sdk_frameworks = args_copy.pop("sdk_frameworks", [])
    extension_safe = args_copy.pop("extension_safe", False)
    bundle_loader = args_copy.pop("bundle_loader", None)

    # If a user provides a "binary" attribute of their own, it is ignored and
    # silently overwritten below. Instead of allowing this, we should fail fast
    # to prevent confusion.
    if "binary" in args_copy:
        fail(
            "Do not provide your own binary; one will be linked from your deps.",
            attr = "binary",
        )

    # Note the pop/get difference here. If the attribute is present as "private",
    # we want to pop it off so that it does not get passed down to the underlying
    # bundling rule (this is the macro's way of giving us default information in
    # the rule that we don't have access to yet). If the argument is present
    # without the underscore, then we leave it in so that the bundling rule can
    # access the value the user provided in their build target (if any).
    product_type = args_copy.pop("_product_type", None)
    if not product_type:
        product_type = args_copy.get("product_type")

    product_type_descriptor = product_support.product_type_descriptor(
        product_type,
    )

    if product_type_descriptor and product_type_descriptor.bundle_extension == ".kext":
        # KEXTs are of file type MH_KEXT_BUNDLE, not MH_BUNDLE.
        # Use "executable" and the kernel_extension feature to set the proper link flags.
        binary_type = "executable"

        # Disables c++ stdlib and Foundation linking. Adds -kext linker flag.
        features = args_copy.get("features", [])
        features += ["kernel_extension"]
        args_copy["features"] = features
    return _create_linked_binary_target(
        name,
        platform_type,
        linkopts,
        binary_type,
        sdk_frameworks,
        extension_safe,
        bundle_loader,
        link_swift_statically = link_swift_statically,
        suppress_entitlements = suppress_entitlements,
        **args_copy
    )

# Define the loadable module that lists the exported symbols in this file.
binary_support = struct(
    add_entitlements_and_swift_linkopts = _add_entitlements_and_swift_linkopts,
    create_binary = _create_binary,
    create_linked_binary_target = _create_linked_binary_target,
    get_binary_provider = _get_binary_provider,
)
