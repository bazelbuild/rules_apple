# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Support for linking related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load("@build_bazel_apple_support//lib:lipo.bzl", "lipo")
load(
    "@build_bazel_apple_support//lib:providers.bzl",
    "ApplePlatformInfo",
)
load("@build_bazel_apple_support//xcode:providers.bzl", "XcodeVersionInfo")
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:compilation_support.bzl",
    "compilation_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:entitlements_support.bzl",
    "entitlements_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleExecutableBinaryInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_dynamic_framework_info.bzl",
    "AppleDynamicFrameworkInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_linked_images_info.bzl",
    "AppleLinkedImagesInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/private/rules_impl:objc_compilation_support.bzl", objc_compilation_support = "compilation_support")  # buildifier: disable=bzl-visibility

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

_DENIED_VERIFY_PLATFORM_VARIANTS_USERS = []

# Feature that makes linked binaries emit linkmaps and validate that no object file is linked into
# more than one of the images loaded into the same process; see
# `_register_duplicate_linked_objects_validation`.
_VALIDATE_DUPLICATE_LINKED_OBJECTS_FEATURE = "apple.validate_duplicate_linked_objects"

# Product types whose binaries always emit and propagate a linkmap, so that any binary that loads
# them can validate duplicate linked objects without requiring a build-wide setting. These are
# typically much smaller than application binaries, whose linkmaps are only emitted when the
# application validates.
_ALWAYS_EMIT_LINKMAP_PRODUCT_TYPES = [
    apple_product_type.dylib,
    apple_product_type.framework,
]

# Product types of `apple_binary` targets, which have no rule descriptor, by `binary_type`.
_APPLE_BINARY_PRODUCT_TYPES = {
    "dylib": apple_product_type.dylib,
}

def _archive_multi_arch_static_library(
        *,
        ctx,
        cc_configured_features,
        cc_toolchains):
    """Generates a (potentially multi-architecture) static library archive for Apple platforms.

    Rule context is a required parameter due to usage of the cc_common.configure_features API.

    Args:
        ctx: The Starlark rule context.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.

    Returns:
        A Starlark struct containing the following attributes:
            - output_groups: OutputGroupInfo provider from transitive CcInfo validation_artifacts.
            - outputs: List of structs containing the following attributes:
                - library: Artifact representing a linked static library.
                - architecture: Static library archive architecture (e.g. 'arm64', 'x86_64').
                - platform: Static library archive target Apple platform (e.g. 'ios', 'macos').
                - environment: Static library archive environment (e.g. 'device', 'simulator').
    """

    # Static frameworks don't link, so retention attributes (from `binary_linking_attrs`) would be
    # silently ignored.
    if _retained_avoid_deps(ctx).is_retaining:
        fail((
            "ERROR: `retained_avoid_deps_library_suffixes` / `retained_avoid_deps_libraries` are " +
            "not supported on static frameworks ({label}), which don't link a binary."
        ).format(label = ctx.label))

    split_deps = ctx.split_attr.deps
    split_avoid_deps = ctx.split_attr.avoid_deps

    outputs = []

    for split_transition_key, child_toolchain in cc_toolchains.items():
        cc_toolchain = child_toolchain[cc_common.CcToolchainInfo]
        common_variables = objc_compilation_support.build_common_variables(
            ctx = ctx,
            toolchain = cc_toolchain,
            use_pch = True,
            deps = split_deps[split_transition_key],
        )

        avoid_cc_linking_contexts = []

        if len(split_avoid_deps.keys()):
            for dep in split_avoid_deps[split_transition_key]:
                if CcInfo in dep:
                    avoid_cc_linking_contexts.append(dep[CcInfo].linking_context)

        name = ctx.label.name + "-" + cc_toolchain.target_gnu_system_name + "-fl"

        cc_linking_context = compilation_support.subtract_linking_contexts(
            owner = ctx.label,
            linking_contexts = common_variables.objc_linking_context.cc_linking_contexts,
            avoid_dep_linking_contexts = avoid_cc_linking_contexts,
        )
        linking_outputs = compilation_support.register_fully_link_action(
            cc_configured_features = cc_configured_features,
            cc_linking_context = cc_linking_context,
            common_variables = common_variables,
            name = name,
        )

        output = {
            "library": linking_outputs.library_to_link.static_library,
        }

        platform_info = child_toolchain[ApplePlatformInfo]
        output["platform"] = platform_info.target_os
        output["architecture"] = platform_info.target_arch
        output["environment"] = platform_info.target_environment

        outputs.append(struct(**output))

    header_tokens = []
    for _, deps in split_deps.items():
        for dep in deps:
            if CcInfo in dep:
                header_tokens.append(dep[CcInfo].compilation_context.validation_artifacts)

    output_groups = {"_validation": depset(transitive = header_tokens)}

    return struct(
        outputs = outputs,
        output_groups = OutputGroupInfo(**output_groups),
    )

def _find_xcframework_deps_for_current_platform(
        *,
        label,
        platform_info,
        xcframework_deps):
    """Returns the XCFrameworkDepsInfo providers for the current platform.

    This function checks the incoming list of providers and validates that they are compatible with
    the current platform. If no compatible providers are found, this will fail with user-actionable
    error messaging.

    Args:
        label: The label of the rule that is requesting the XCFrameworkDepsInfo.
        platform_info: The ApplePlatformInfo provider of the current platform.
        xcframework_deps: A list of `XCFrameworkDepsInfo` providers from the XCFramework's
            dependencies, which will be used to determine binary dependencies that should be avoided
            by the final linked binaries.

    Returns:
        A list of `XCFrameworkDepsInfo` providers for the current platform.
    """
    xcframework_deps_for_current_platform = [
        xcframework_dep
        for xcframework_dep in xcframework_deps
        if platform_info.target_os == xcframework_dep.target_os and
           (platform_info.target_environment == xcframework_dep.target_environment or
            platform_info.target_os == "macos")
    ]

    if xcframework_deps and not xcframework_deps_for_current_platform:
        fail("""
The referenced XCFrameworks to avoid at {rule_label} do not contain a framework for the current \
target environment "{target_environment}" and OS "{target_os}".

Check the rule definition for each of the dependencies to ensure that they have the same or a \
superset of matching target environments ("simulator" or "device") and OSes ("ios", "tvos", etc.).
""".format(
            rule_label = label,
            target_environment = platform_info.target_environment,
            target_os = platform_info.target_os,
        ))

    for xcframework_dep in xcframework_deps_for_current_platform:
        if platform_info.target_arch not in xcframework_dep.architectures:
            fail("""
Trying to build a framework binary with architecture {architecture}, but the target it \
depends on at {xcframework_dep_label} only supports these architectures for the target environment \
"{target_environment}" and OS "{target_os}":

{xcframework_architectures}

Check the rule definition for this dependency to ensure that it supports this given architecture for
the given target environment {target_environment} and OS {target_os}.
""".format(
                architecture = platform_info.target_arch,
                xcframework_dep_label = xcframework_dep.label,
                xcframework_architectures = xcframework_dep.architectures,
                target_environment = platform_info.target_environment,
                target_os = platform_info.target_os,
            ))

    return xcframework_deps_for_current_platform

def _normalize_label_string(label_string):
    """Returns a label string in the form `compilation_support` uses for library owners.

    Main repository labels become `//package:name`; external repository labels must use the
    canonical repository name and become `@@repo//package:name`.
    """
    for prefix in ("@@//", "@//"):
        if label_string.startswith(prefix):
            label_string = label_string[len(prefix) - 2:]
    if ":" not in label_string.partition("//")[2]:
        label_string = "{}:{}".format(label_string, label_string.rpartition("/")[2])
    return label_string

def _retained_avoid_deps(ctx):
    """Returns the avoided libraries a binary retains, from its retention attributes.

    Args:
        ctx: The rule context.

    Returns:
        A `struct` with the following fields:

        *   `is_retaining`: Whether any avoided library may be retained.
        *   `owners`: A `dict` whose keys are the normalized labels of the targets owning retained
            static libraries.
        *   `suffixes`: A `list` of basename suffixes of retained static libraries.
    """
    suffixes = list(getattr(ctx.attr, "retained_avoid_deps_library_suffixes", []))
    owners = {}
    for label_string in getattr(ctx.attr, "retained_avoid_deps_libraries", []):
        if not label_string.startswith("//") and not label_string.startswith("@"):
            fail((
                "ERROR: `retained_avoid_deps_libraries` of {label} must contain absolute labels " +
                "(e.g. `//package:target`), but got `{value}`."
            ).format(label = ctx.label, value = label_string))

        # Apparent repository names can't be mapped to the canonical names of library owners
        # here, so they would silently never match.
        if (label_string.startswith("@") and not label_string.startswith("@@") and
            not label_string.startswith("@//")):
            fail((
                "ERROR: `retained_avoid_deps_libraries` of {label} must name targets in other " +
                "repositories by their canonical repository name (e.g. `@@repo+//package:target`), " +
                "but got `{value}`."
            ).format(label = ctx.label, value = label_string))
        owners[_normalize_label_string(label_string)] = True
    return struct(
        is_retaining = bool(suffixes or owners),
        owners = owners,
        suffixes = suffixes,
    )

def _link_multi_arch_binary(
        *,
        ctx,
        avoid_deps = [],
        bundle_name,
        cc_configured_features,
        cc_toolchains,
        extra_linkopts = [],
        extra_linkopts_by_os = {},
        extra_link_inputs = [],
        generate_duplicate_linked_objects_linkmap = False,
        rule_descriptor,
        stamp = -1,
        variables_extension = {},
        xcframework_deps = []):
    """Links a (potentially multi-architecture) binary targeting Apple platforms.

    Args:
        ctx: The Starlark rule context.
        avoid_deps: A list of `Target`s representing dependencies of the binary but
            whose libraries should not be linked into the binary. This is the case for
            dependencies that will be found at runtime in another image, such as the
            bundle loader or any dynamic libraries/frameworks that will be loaded by
            this binary.
        bundle_name: The name of the bundle name that the linked binary will be a part of, if any.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        extra_linkopts: A list of strings: Extra linkopts to add to the linking action.
        extra_linkopts_by_os: A dictionary of OS to a list of strings: Extra linkopts to add to the
            linking action for a given OS.
        extra_link_inputs: A list of strings: Extra files to pass to the linker action.
        generate_duplicate_linked_objects_linkmap: Whether to generate a linkmap for each
            architecture for duplicate linked object validation, even if linkmaps were not
            requested with `--objc_generate_linkmap`.
        rule_descriptor: The rule descriptor if one exists for the given rule. For convenience, This
            will define additional parameters required for linking, such as the dSYM bundle name. If
            `None`, these additional parameters will not be set on the linked binary.
        stamp: Whether to include build information in the linked binary. If 1, build
            information is always included. If 0, build information is always excluded.
            If -1 (the default), then the behavior is determined by the --[no]stamp
            flag. This should be set to 0 when generating the executable output for
            test rules.
        variables_extension: A dictionary of user-defined variables to be added to the
            toolchain configuration when create link command line.
        xcframework_deps: A list of `XCFrameworkDepsInfo` providers from the XCFramework's
            dependencies, which will be used to determine binary dependencies that should be avoided
            by the final linked binaries.

    Returns:
        A `struct` which contains the following fields:
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` with the single key `_validation` and as valuea depset
            containing the validation artifacts from the compilation contexts of the CcInfo
            providers of the targets that were linked.
    """

    split_deps = ctx.split_attr.deps

    if split_deps and split_deps.keys() != cc_toolchains.keys():
        fail(("Split transition keys are different between 'deps' [%s] and " +
              "'_cc_toolchain_forwarder' [%s]") % (
            split_deps.keys(),
            cc_toolchains.keys(),
        ))

    avoid_cc_linking_contexts = [
        dep[AppleDynamicFrameworkInfo].framework_linking_context
        for dep in avoid_deps
        if AppleDynamicFrameworkInfo in dep
    ]
    avoid_cc_linking_contexts.extend([
        dep[AppleExecutableBinaryInfo].binary_linking_context
        for dep in avoid_deps
        if AppleExecutableBinaryInfo in dep
    ])

    linker_outputs = []

    # $(location...) is only used in one test, and tokenize only affects linkopts in one target
    additional_linker_inputs = getattr(ctx.attr, "additional_linker_inputs", [])
    attr_linkopts = [
        ctx.expand_location(opt, targets = additional_linker_inputs)
        for opt in getattr(ctx.attr, "linkopts", [])
    ]
    attr_linkopts = [token for opt in attr_linkopts for token in ctx.tokenize(opt)]

    multi_arch_build = len(cc_toolchains) > 1

    # Opt-in, per binary: keep the avoided `alwayslink = False` static libraries selected by the
    # `retained_avoid_deps_library_suffixes` / `retained_avoid_deps_libraries` attributes on the
    # link line (after the avoided dynamic libraries) instead of subtracting them, so that archive
    # members the avoided images did not link can still satisfy references from this binary. This
    # is meant for archives of many independent object files with only strong definitions, such
    # as generated ObjC protos built without `alwayslink`. Every other avoided library is
    # subtracted as usual.
    #
    # Retaining all `alwayslink = False` avoided libraries was considered and discarded: Apple ld
    # treats a weak definition exported by a dylib as overridable, so it loads an archive member
    # defining a symbol that an avoided framework only exports weakly ("strong override of a weak
    # dylib export" with `-why_load`). C++ libraries define many weak symbols (template
    # instantiations, inline functions, `ABSL_ATTRIBUTE_WEAK` hooks, tcmalloc's weak operator new
    # variants), so retaining them links a second copy of their archive members.
    #
    # Retention can still link a second copy of a member whose symbols the avoided images link but
    # do not export (e.g. hidden visibility or exported symbol lists), so it implies duplicate
    # linked object validation (see `_register_binary_linking_action`), which fails the build
    # instead of letting the duplicate go unnoticed.
    retained_avoid_deps = _retained_avoid_deps(ctx)

    for split_transition_key, child_toolchain in cc_toolchains.items():
        cc_toolchain = child_toolchain[cc_common.CcToolchainInfo]
        deps = split_deps.get(split_transition_key, [])
        platform_info = child_toolchain[ApplePlatformInfo]

        common_variables = objc_compilation_support.build_common_variables(
            ctx = ctx,
            toolchain = cc_toolchain,
            deps = deps,
            attr_linkopts = attr_linkopts,
        )

        xcframework_deps_for_current_platform = _find_xcframework_deps_for_current_platform(
            label = ctx.label,
            platform_info = platform_info,
            xcframework_deps = xcframework_deps,
        )

        avoid_split_cc_linking_contexts = [
            xcframework_dep.apple_dynamic_framework_info.framework_linking_context
            for xcframework_dep in xcframework_deps_for_current_platform
        ]

        split_linking_contexts = common_variables.objc_linking_context.cc_linking_contexts
        split_linking_contexts.extend(avoid_cc_linking_contexts)
        split_linking_contexts.extend(avoid_split_cc_linking_contexts)

        merged_cc_linking_context = cc_common.merge_linking_contexts(
            linking_contexts = split_linking_contexts,
        )

        subtracted_cc_linking_context = compilation_support.subtract_linking_contexts(
            owner = ctx.label,
            linking_contexts = split_linking_contexts,
            avoid_dep_linking_contexts = avoid_cc_linking_contexts +
                                         avoid_split_cc_linking_contexts,
            retained_library_owners = retained_avoid_deps.owners,
            retained_library_suffixes = retained_avoid_deps.suffixes,
        )

        additional_outputs = []
        extensions = {}

        dsym_output = None
        if ctx.fragments.cpp.apple_generate_dsym:
            dsym_bundle_name = "{bundle_name}{bundle_extension}.dSYM".format(
                bundle_name = bundle_name,
                bundle_extension = rule_descriptor.bundle_extension if rule_descriptor else "",
            )

            if multi_arch_build:
                dsym_output = intermediates.directory(
                    actions = ctx.actions,
                    target_name = bundle_name,
                    output_discriminator = cc_toolchain.target_gnu_system_name,
                    dir_name = dsym_bundle_name,
                )
            else:
                # Avoiding "intermediates" as this will be the only dSYM in a single arch build.
                dsym_output = ctx.actions.declare_directory(
                    dsym_bundle_name,
                )

            extensions["dsym_path"] = dsym_output.path  # dsym symbol file
            additional_outputs.append(dsym_output)

        linkmap = None
        duplicate_linked_objects_linkmap = None
        duplicate_linked_objects_linkopts = []
        if ctx.fragments.cpp.objc_generate_linkmap:
            linkmap = intermediates.file(
                actions = ctx.actions,
                target_name = ctx.label.name,
                output_discriminator = cc_toolchain.target_gnu_system_name,
                file_name = ctx.label.name + ".linkmap",
            )
            extensions["linkmap_exec_path"] = linkmap.path  # linkmap file
            additional_outputs.append(linkmap)
            duplicate_linked_objects_linkmap = linkmap
        elif generate_duplicate_linked_objects_linkmap:
            duplicate_linked_objects_linkmap = intermediates.file(
                actions = ctx.actions,
                target_name = ctx.label.name,
                output_discriminator = cc_toolchain.target_gnu_system_name,
                file_name = ctx.label.name + "_duplicate_linked_objects.linkmap",
            )
            duplicate_linked_objects_linkopts.append(
                "-Wl,-map,{}".format(duplicate_linked_objects_linkmap.path),
            )
            additional_outputs.append(duplicate_linked_objects_linkmap)

        main_binary_basename = outputs.main_binary_basename(bundle_name)

        platform_extra_linkopts = extra_linkopts + extra_linkopts_by_os.get(
            platform_info.target_os,
            [],
        ) + duplicate_linked_objects_linkopts

        executable = compilation_support.register_configuration_specific_link_actions(
            additional_outputs = additional_outputs,
            apple_platform_info = platform_info,
            attr_linkopts = attr_linkopts,
            bundle_name = bundle_name,
            common_variables = common_variables,
            cc_configured_features = cc_configured_features,
            cc_linking_context = subtracted_cc_linking_context,
            extra_link_args = platform_extra_linkopts,
            extra_link_inputs = extra_link_inputs,
            name = main_binary_basename,
            stamp = stamp,
            user_variable_extensions = variables_extension | extensions,
        )

        output = {
            "binary": executable,
            "platform": platform_info.target_os,
            "architecture": platform_info.target_arch,
            "environment": platform_info.target_environment,
            "dsym_output": dsym_output,
            "linking_context": merged_cc_linking_context,
            "linkmap": linkmap,
            "duplicate_linked_objects_linkmap": duplicate_linked_objects_linkmap,
        }

        linker_outputs.append(struct(**output))

    header_tokens = []
    for _, deps in split_deps.items():
        for dep in deps:
            if CcInfo in dep:
                header_tokens.append(dep[CcInfo].compilation_context.validation_artifacts)

    output_groups = {"_validation": depset(transitive = header_tokens)}

    return struct(
        output_groups = output_groups,
        outputs = linker_outputs,
    )

def _debug_outputs_by_architecture(link_outputs):
    """Returns debug outputs indexed by architecture from `register_binary_linking_action` output.

    Args:
        link_outputs: The dictionary of linking outputs found from the `outputs` field of
            `register_binary_linking_action`'s output struct.

    Returns:
        A `struct` containing three fields:

        *   `dsym_outputs`: A mapping of architectures to Files representing dSYM outputs for each
            architecture.
        *   `linkmaps`: A mapping of architectures to Files representing linkmaps for each
            architecture.
    """
    dsym_outputs = {}
    linkmaps = {}

    for link_output in link_outputs:
        dsym_outputs[link_output.architecture] = link_output.dsym_output
        linkmaps[link_output.architecture] = link_output.linkmap

    return struct(
        dsym_outputs = dsym_outputs,
        linkmaps = linkmaps,
    )

def _sectcreate_cc_info(segname, sectname, file):
    """Returns a CcInfo that propagates a section in a linked binary.

    This function creates a new CcInfo that contains the necessary linkopts
    to create a new section in the binary to which the provider is propagated; it
    is equivalent to the `ld` flag `-sectcreate segname sectname file`. This can
    be used, for example, to embed entitlements in a simulator executable (since
    they are not applied during code signing).

    Args:
      segname: The name of the segment in which the section will be created.
      sectname: The name of the section to create.
      file: The file whose contents will be used as the content of the section.

    Returns:
      A CcInfo that propagates the section linkopts.
    """

    linkopts = ["-Wl,-sectcreate,%s,%s,%s" % (segname, sectname, file.path)]
    return [
        CcInfo(
            linking_context = cc_common.create_linking_context(
                linker_inputs = depset([cc_common.create_linker_input(
                    owner = file.owner,
                    user_link_flags = linkopts,
                    additional_inputs = depset([file]),
                )]),
            ),
        ),
    ]

def _validate_platform_variants(*, cc_toolchains, label):
    """Validates that all requested architectures are device or simulator."""
    full_label = "//{package}:{name}".format(
        package = label.package,
        name = label.name,
    )
    if full_label in _DENIED_VERIFY_PLATFORM_VARIANTS_USERS:
        return
    expected_environment = None
    for split_transition_key, child_toolchain in cc_toolchains.items():
        actual_environment = child_toolchain[ApplePlatformInfo].target_environment
        if expected_environment != actual_environment:
            if expected_environment == None:
                expected_environment = actual_environment
            else:
                fail("""
ERROR: Attempted to build a universal binary with the following platforms, but their environments \
(device or simulator) are not consistent:

{split_transition_keys}

First mismatched environment was {actual_environment} from {split_transition_key}.

Expected all environments to be {expected_environment}.

All requested architectures must be either device or simulator architectures.""".format(
                    actual_environment = actual_environment,
                    expected_environment = expected_environment,
                    split_transition_key = split_transition_key,
                    split_transition_keys = ", ".join(cc_toolchains.keys()),
                ))

def _register_binary_linking_action(
        ctx,
        *,
        avoid_deps = [],
        bundle_name,
        bundle_loader = None,
        cc_configured_features,
        cc_toolchains,
        entitlements = None,
        exported_symbols_lists = [],
        extra_link_inputs = [],
        extra_linkopts = [],
        extra_linkopts_by_os = {},
        platform_prerequisites = None,
        rule_descriptor = None,
        stamp = -1,
        verify_platform_variants = True,
        xcframework_deps = []):
    """Registers linking actions using the Starlark Apple binary linking API.

    This method will add the linkopts as added on the rule descriptor, in addition to any extra
    linkopts given when invoking this method.

    Args:
        ctx: The rule context.
        avoid_deps: A list of `Target`s representing dependencies of the binary but whose
            symbols should not be linked into it.
        bundle_name: The name of the bundle name that the linked binary will be a part of, if any.
        bundle_loader: For Mach-O bundles, the `Target` whose binary will load this bundle.
            This target must propagate the `AppleExecutableBinaryInfo` provider.
            This simplifies the process of passing the bundle loader to all the arguments
            that need it: the binary will automatically be added to the linker inputs, its
            path will be added to linkopts via `-bundle_loader`, and the `apple_common.Objc`
            provider of its dependencies (obtained from the `AppleExecutableBinaryInfo` provider)
            will be passed as an additional `avoid_dep` to ensure that those dependencies are
            subtracted when linking the bundle's binary.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        entitlements: An optional `File` that provides the processed entitlements for the
            binary or bundle being built. If the build is targeting a simulator environment,
            the entitlements will be embedded in a special section of the binary; when
            targeting non-simulator environments, this file is ignored (it is assumed that
            the entitlements will be provided during code signing).
        exported_symbols_lists: List of `File`s containing exported symbols lists for the linker
            to control symbol resolution.
        extra_link_inputs: Extra Files to add to the linking action, expected to be referenced via
            extra_linkopts.
        extra_linkopts: Extra linkopts to add to the linking action.
        extra_linkopts_by_os: Extra linkopts to add to the linking action, keyed by the OS.
        platform_prerequisites: The platform prerequisites if one exists for the given rule. This
            will define additional linking sections for entitlements. If `None`, entitlements
            sections are not included.
        rule_descriptor: The rule descriptor if one exists for the given rule. For convenience, This
            will define additional parameters required for linking, such as `rpaths`. If `None`,
            these additional parameters will not be set on the linked binary.
        stamp: Whether to include build information in the linked binary. If 1, build
            information is always included. If 0, the default build information is always
            excluded. If -1, the default behavior is used, which may be overridden by the
            `--[no]stamp` flag. This should be set to 0 when generating the executable output
            for test rules.
        verify_platform_variants: Whether to verify that all requested architectures are device or
            simulator. True by default.
        xcframework_deps: A list of `XCFrameworkDepsInfo` providers from the XCFramework's
            dependencies, which will be used to determine binary dependencies that should be avoided
            by the final linked binaries.

    Returns:
        A `struct` which contains the following fields:

        *   `binary`: The final binary `File` that was linked. If only one architecture was
            requested, then it is a symlink to that single architecture binary. Otherwise, it
            is a new universal binary obtained by invoking `lipo`.
        *   `cc_info`: The CcInfo provider containing information about the targets that were
            linked.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` containing output groups that should be returned in the
            `OutputGroupInfo` provider of the calling rule.
        *   `providers`: A `list` of providers that should be returned by the calling rule, so that
            targets that load the linked binary into their process (e.g. as a framework or bundle
            loader) can validate it.
    """
    if verify_platform_variants:
        _validate_platform_variants(cc_toolchains = cc_toolchains, label = ctx.label)

    linkopts = []
    link_inputs = []

    # Add linkopts/linker inputs that are common to all the rules.
    for exported_symbols_list in exported_symbols_lists:
        linkopts.append(
            "-Wl,-exported_symbols_list,{}".format(exported_symbols_list.path),
        )
        link_inputs.append(exported_symbols_list)

    if entitlements and platform_prerequisites and not platform_prerequisites.platform.is_device:
        # Add an entitlements and a DER entitlements section, required of all Simulator builds that
        # define entitlements. This is never addressed by /usr/bin/codesign and must be done here.
        linkopts.append(
            "-Wl,-sectcreate,{segment},{section},{file}".format(
                segment = "__TEXT",
                section = "__entitlements",
                file = entitlements.path,
            ),
        )
        link_inputs.append(entitlements)

        der_entitlements = entitlements_support.generate_der_entitlements(
            actions = ctx.actions,
            apple_platform_info = platform_prerequisites.apple_platform_info,
            apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx),
            entitlements = entitlements,
            label_name = ctx.label.name,
            xcode_version_config = platform_prerequisites.xcode_version_config,
            xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(),
        )
        linkopts.append(
            "-Wl,-sectcreate,{segment},{section},{file}".format(
                segment = "__TEXT",
                section = "__ents_der",
                file = der_entitlements.path,
            ),
        )
        link_inputs.append(der_entitlements)

    if platform_prerequisites and platform_prerequisites.uses_swift:
        linkopts.append("-Wl,-rpath,/usr/lib/swift")

    # TODO(b/248317958): Migrate rule_descriptor.rpaths as direct inputs of the extra_linkopts arg
    # on this method.
    if rule_descriptor:
        linkopts.extend(["-Wl,-rpath,{}".format(rpath) for rpath in rule_descriptor.rpaths])

    linkopts.extend(extra_linkopts)
    link_inputs.extend(extra_link_inputs)

    all_avoid_deps = list(avoid_deps)
    if bundle_loader:
        bundle_loader_file = bundle_loader[AppleExecutableBinaryInfo].binary
        all_avoid_deps.append(bundle_loader)
        linkopts.extend(["-bundle_loader", bundle_loader_file.path])
        link_inputs.append(bundle_loader_file)

    # Retaining non-alwayslink avoided libraries can link an object file into this binary that an
    # avoided image also links, so it is only allowed together with the validation that catches it.
    # Retention only changes the link of a binary that avoids images (dynamic frameworks or a bundle
    # loader), so a retaining binary without them has nothing to validate.
    is_retaining = _retained_avoid_deps(ctx).is_retaining
    validate_duplicate_linked_objects = (
        _VALIDATE_DUPLICATE_LINKED_OBJECTS_FEATURE in cc_configured_features.enabled_features or
        (is_retaining and bool(all_avoid_deps))
    )
    if rule_descriptor:
        product_type = rule_descriptor.product_type
    else:
        product_type = _APPLE_BINARY_PRODUCT_TYPES.get(getattr(ctx.attr, "binary_type", None))

    # Libraries subtracted because of `xcframework_deps` (`apple_xcframework`'s `avoid_frameworks`)
    # can't be validated: `apple_xcframework` doesn't run or propagate the validation.
    if is_retaining and xcframework_deps:
        fail((
            "ERROR: `retained_avoid_deps_library_suffixes` / `retained_avoid_deps_libraries` are " +
            "not supported on apple_xcframework targets with `avoid_frameworks` ({label}), since " +
            "duplicate linked object validation can't run for them."
        ).format(label = ctx.label))

    # Frameworks and dylibs always emit a linkmap and propagate it, since they can't know whether a
    # binary that loads them validates. Other binaries (applications, extensions, test bundles)
    # only emit one when they validate, which also makes a validating application usable as the
    # bundle loader of a validating test bundle. A bundle that validates only because it retains
    # avoided libraries skips a bundle loader that doesn't validate, so objects duplicated between
    # the two are only detected when the bundle loader validates too.
    emit_linkmap = (
        validate_duplicate_linked_objects or
        product_type in _ALWAYS_EMIT_LINKMAP_PRODUCT_TYPES
    )

    linking_outputs = _link_multi_arch_binary(
        ctx = ctx,
        avoid_deps = all_avoid_deps,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchains,
        extra_linkopts = linkopts,
        extra_linkopts_by_os = extra_linkopts_by_os,
        extra_link_inputs = link_inputs,
        generate_duplicate_linked_objects_linkmap = emit_linkmap,
        rule_descriptor = rule_descriptor,
        stamp = stamp,
        xcframework_deps = xcframework_deps,
    )

    output_groups = linking_outputs.output_groups
    providers = []
    if emit_linkmap:
        validation = _register_duplicate_linked_objects_validation(
            ctx = ctx,
            link_outputs = linking_outputs.outputs,
            loaded_image_targets = all_avoid_deps,
            require_bundle_loader_linkmaps = (
                _VALIDATE_DUPLICATE_LINKED_OBJECTS_FEATURE in cc_configured_features.enabled_features
            ),
            validate = validate_duplicate_linked_objects,
        )
        providers.append(validation.linked_images_info)
        output_groups = outputs.merge_output_groups(output_groups, validation.output_groups)

    universal_binary = ctx.actions.declare_file("{}_lipobin".format(ctx.label.name))

    apple_platform_info = apple_support.platform_info_from_rule_ctx(ctx)

    _lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = [output.binary for output in linking_outputs.outputs],
        output = universal_binary,
        apple_platform_info = apple_platform_info,
        xcode_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )

    return struct(
        binary = universal_binary,
        outputs = linking_outputs.outputs,
        output_groups = output_groups,
        providers = providers,
    )

def _image_validation_argument(linked_image):
    return [
        "--image",
        linked_image.architecture,
        linked_image.linkmap.path,
        linked_image.image,
    ]

def _register_duplicate_linked_objects_validation(
        *,
        ctx,
        link_outputs,
        loaded_image_targets,
        require_bundle_loader_linkmaps = True,
        validate):
    """Propagates linkmaps and optionally validates that each object is linked into one image.

    The binary that was just linked and every image that rules_apple knows will be loaded into the
    same process (the dynamic frameworks it links against, transitively, and the bundle loader of a
    bundle) are checked with their ld64 linkmaps. If an archive member or object file is linked into
    more than one of these images, the validation action fails the build, since each image would
    have its own copy of the object's classes, globals and static initializers.

    Args:
        ctx: The rule context.
        link_outputs: The `outputs` of `_link_multi_arch_binary`, which must have been called with
            `generate_duplicate_linked_objects_linkmap = True`.
        loaded_image_targets: The `Target`s of the images loaded into the same process as the
            binary, i.e. the avoided dependencies of the binary.
        require_bundle_loader_linkmaps: Whether a loaded bundle loader (test host) without linkmaps
            fails the validation. If False, such a bundle loader is skipped, so objects duplicated
            between it and this binary are not detected. Frameworks always provide linkmaps.
        validate: Whether to register the validation action. If False, only the provider is
            returned (e.g. for frameworks, which always propagate their linkmaps).

    Returns:
        A `struct` with the following fields:

        *   `linked_images_info`: An `AppleLinkedImagesInfo` provider with the linkmaps of this
            binary and of every image loaded into the same process, to be propagated by the rule.
        *   `output_groups`: A `dict` with the `_validation` output group containing the output of
            the validation action, or an empty `dict` if not validating or if there are no other
            images to check.
    """
    label = str(ctx.label)
    loaded_linkmaps = []
    for target in loaded_image_targets:
        if AppleLinkedImagesInfo in target:
            loaded_linkmaps.append(target[AppleLinkedImagesInfo].linkmaps)
        elif validate and (
            AppleDynamicFrameworkInfo in target or
            (require_bundle_loader_linkmaps and AppleExecutableBinaryInfo in target)
        ):
            fail("""
ERROR: {target} is loaded into the same process as {label}, but it did not provide linkmaps for \
duplicate linked object validation. Frameworks always provide them; an application used as a \
bundle loader (test host) only provides them when it validates duplicate linked objects itself. \
Enable the `{feature}` feature on {target} too.
""".format(
                feature = _VALIDATE_DUPLICATE_LINKED_OBJECTS_FEATURE,
                label = label,
                target = target.label,
            ))

    linked_images_info = AppleLinkedImagesInfo(
        linkmaps = depset(
            [
                struct(
                    architecture = link_output.architecture,
                    image = label,
                    linkmap = link_output.duplicate_linked_objects_linkmap,
                )
                for link_output in link_outputs
            ],
            transitive = loaded_linkmaps,
        ),
    )

    if not validate or not loaded_linkmaps:
        # Not validating, or nothing else is known to be loaded into this process.
        return struct(linked_images_info = linked_images_info, output_groups = {})

    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    if not apple_xplat_toolchain_info.duplicate_linked_objects_tool:
        fail(
            "ERROR: The `{}` feature requires an Apple cross-platform tools toolchain that sets "
                .format(_VALIDATE_DUPLICATE_LINKED_OBJECTS_FEATURE) +
            "`duplicate_linked_objects_tool`.",
        )

    validation_output = intermediates.file(
        actions = ctx.actions,
        target_name = ctx.label.name,
        output_discriminator = None,
        file_name = "duplicate_linked_objects_validation.txt",
    )

    linked_images = linked_images_info.linkmaps
    args = ctx.actions.args()
    args.add("--target", label)
    args.add_all(linked_images, map_each = _image_validation_argument)
    args.add("--output", validation_output)

    ctx.actions.run(
        executable = apple_xplat_toolchain_info.duplicate_linked_objects_tool,
        arguments = [args],
        inputs = [linked_image.linkmap for linked_image in linked_images.to_list()],
        outputs = [validation_output],
        exec_group = apple_toolchain_utils.get_xplat_exec_group(),
        mnemonic = "AppleDuplicateLinkedObjectsValidation",
        progress_message = "Validating that no object file is linked into more than one image " +
                           "loaded with %{label}",
    )

    return struct(
        linked_images_info = linked_images_info,
        output_groups = {"_validation": depset([validation_output])},
    )

def _register_static_library_archive_action(
        *,
        ctx,
        cc_configured_features,
        cc_toolchains,
        verify_platform_variants = True):
    """Registers library archive actions using the Starlark Apple static library archive API.

    Args:
        ctx: The rule context.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        verify_platform_variants: Whether to verify that all requested architectures are device or
            simulator. True by default.

    Returns:
        A `struct` which contains the following fields:

        *   `library`: The final library `File` that was archived. If only one architecture was
            requested, then it is a symlink to that single architecture binary. Otherwise, it
            is a new universal library archive obtained by invoking `lipo`.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` containing output groups that should be returned in the
            `OutputGroupInfo` provider of the calling rule.
    """
    if verify_platform_variants:
        _validate_platform_variants(cc_toolchains = cc_toolchains, label = ctx.label)

    archive_outputs = _archive_multi_arch_static_library(
        ctx = ctx,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchains,
    )

    universal_library = ctx.actions.declare_file("{}_lipo.a".format(ctx.label.name))

    apple_platform_info = apple_support.platform_info_from_rule_ctx(ctx)

    _lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = [output.library for output in archive_outputs.outputs],
        output = universal_library,
        apple_platform_info = apple_platform_info,
        xcode_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )

    return struct(
        library = universal_library,
        outputs = archive_outputs.outputs,
        output_groups = archive_outputs.output_groups,
    )

def _lipo_or_symlink_inputs(*, actions, inputs, output, apple_platform_info, xcode_config):
    """Creates a universal binary with `lipo` if inputs > 1, symlinks otherwise.

    Args:
      actions: The rule context actions.
      inputs: Binary inputs to use for the lipo action.
      output: Binary output for universal binary or symlink.
      apple_platform_info: The ApplePlatformInfo provider used to configure
                      the action environment.
      xcode_config: The `XcodeVersionInfo` provider used to
                    configure the action environment.
    """
    if len(inputs) > 1:
        lipo.create(
            actions = actions,
            inputs = inputs,
            output = output,
            apple_platform_info = apple_platform_info,
            xcode_config = xcode_config,
        )
    else:
        # Symlink if there was only a single architecture created; it's faster.
        actions.symlink(target_file = inputs[0], output = output)

linking_support = struct(
    debug_outputs_by_architecture = _debug_outputs_by_architecture,
    lipo_or_symlink_inputs = _lipo_or_symlink_inputs,
    register_binary_linking_action = _register_binary_linking_action,
    register_static_library_archive_action = _register_static_library_archive_action,
    sectcreate_cc_info = _sectcreate_cc_info,
)
