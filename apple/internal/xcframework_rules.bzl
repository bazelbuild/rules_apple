# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Implementation of the xcframework rules."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_toolchains.bzl",
    "AppleMacToolsToolchainInfo",
    "AppleXPlatToolsToolchainInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:cc_info_support.bzl",
    "cc_info_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:experimental.bzl",
    "is_experimental_tree_artifact_enabled",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:partials.bzl",
    "partials",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_usage_aspect.bzl",
    "swift_usage_aspect",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleBundleVersionInfo",
    "AppleStaticXcframeworkBundleInfo",
    "AppleXcframeworkBundleInfo",
)
load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:paths.bzl", "paths")

def _group_link_outputs_by_library_identifier(
        *,
        actions,
        apple_fragment,
        deps,
        label_name,
        link_result,
        xcode_config):
    """Groups linking outputs by library identifier with additional platform information.

    Linking outputs artifacts are combined using the lipo tool if necessary due to grouping.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        deps: Label list of dependencies from rule context (ctx.split_attr.deps).
        label_name: Name of the target being built.
        link_result: The struct returned by `linking_support.register_binary_linking_action`.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.

    Returns:
        A list of structs with the following fields; `architectures` containing a list of the
        architectures that the binary was built with, `binary` referencing the output binary linked
        with the `lipo` tool if necessary, or referencing a symlink to the original binary if not,
        `bitcode_symbol_maps` which is a mapping of architectures to bitcode symbol maps if any were
        created, `dsym_binaries` which is a mapping of architectures to dsym binaries if any were
        created, `environment` to reference the target environment the binary was built for,
        `linkmaps` which is a mapping of architectures to linkmaps if any were created,  and
        `platform` to reference the target platform the binary was built for.
    """
    linking_type = None
    for attr_name in ["binary", "library"]:
        if hasattr(link_result, attr_name):
            linking_type = attr_name
            break

    if not linking_type:
        fail("Apple linking APIs output struct must define either 'binary' or 'library'.\n" +
             "This is most likely a rules_apple bug, please file a bug with reproduction steps.")

    # Organize each output as a platform_environment, where each can accept one or more archs.
    link_outputs_by_framework = {}

    # Iterate through the outputs of the registered linking action, match archs to platform and
    # environment combinations.
    for link_output in link_result.outputs:
        framework_key = link_output.platform + "_" + link_output.environment
        if link_outputs_by_framework.get(framework_key):
            link_outputs_by_framework[framework_key].append(link_output)
        else:
            link_outputs_by_framework[framework_key] = [link_output]

    link_outputs_by_library_identifier = {}

    # Iterate through the structure again, this time creating a structure equivalent to link_result
    # .outputs but with .architecture replaced with .architectures, .bitcode_symbols replaced with
    # .bitcode_symbol_maps, .dsym_binary replaced with .dsym_binaries, and .linkmap replaced with
    # .linkmaps
    for framework_key, link_outputs in link_outputs_by_framework.items():
        inputs = [getattr(output, linking_type) for output in link_outputs]
        filename = "{}_{}".format(label_name, framework_key)
        extension = inputs[0].extension
        if extension != "":
            filename = "{}.{}".format(filename, extension)
        fat_binary = actions.declare_file(filename)
        linking_support.lipo_or_symlink_inputs(
            actions = actions,
            inputs = inputs,
            output = fat_binary,
            apple_fragment = apple_fragment,
            xcode_config = xcode_config,
        )

        architectures = []
        bitcode_symbol_maps = {}
        dsym_binaries = {}
        linkmaps = {}
        split_attr_keys = []
        swift_infos = {}
        uses_swift = False
        for link_output in link_outputs:
            split_attr_key = transition_support.xcframework_split_attr_key(
                cpu = link_output.architecture,
                environment = link_output.environment,
                platform_type = link_output.platform,
            )

            architectures.append(link_output.architecture)
            split_attr_keys.append(split_attr_key)

            # If there's any Swift dependencies on this framework rule,
            # look for providers to see if we need to generate Swift interfaces.
            if swift_support.uses_swift(deps[split_attr_key]):
                uses_swift = True
                for dep in deps[split_attr_key]:
                    if SwiftInfo in dep:
                        swift_infos[link_output.architecture] = dep[SwiftInfo]

            # static library linking does not support bitcode, dsym, and linkmaps yet.
            if linking_type == "binary":
                bitcode_symbol_maps[link_output.architecture] = link_output.bitcode_symbols
                dsym_binaries[link_output.architecture] = link_output.dsym_binary
                linkmaps[link_output.architecture] = link_output.linkmap

        environment = link_outputs[0].environment
        platform = link_outputs[0].platform

        library_identifier = _library_identifier(
            architectures = architectures,
            environment = environment,
            platform = platform,
        )

        link_outputs_by_library_identifier[library_identifier] = struct(
            architectures = architectures,
            binary = fat_binary,
            bitcode_symbol_maps = bitcode_symbol_maps,
            dsym_binaries = dsym_binaries,
            environment = environment,
            linkmaps = linkmaps,
            platform = platform,
            split_attr_keys = split_attr_keys,
            swift_infos = swift_infos,
            uses_swift = uses_swift,
        )

    return link_outputs_by_library_identifier

def _library_identifier(*, architectures, environment, platform):
    """Return a unique identifier for an embedded framework to disambiguate it from others.

    Args:
        architectures: The architectures of the target that was built. For example, `x86_64` or
            `arm64`.
        environment: The environment of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_common` linking APIs.
            Typically `device` or `simulator`.
        platform: The platform of the target that was built, which corresponds to the toolchain's
            target triple values as reported by `apple_common` linking APIs.
            For example, `ios`, `macos`, `tvos` or `watchos`.

    Returns:
        A string that can be used to determine the subfolder this embedded framework will be found
        in the final XCFramework bundle. This mirrors the formatting for subfolders as given by the
        xcodebuild -create-xcframework tool.
    """
    library_identifier = "{}-{}".format(platform, "_".join(architectures))
    if environment != "device":
        library_identifier += "-{}".format(environment)
    return library_identifier

def _unioned_attrs(*, attr_names, split_attr, split_attr_keys):
    """Return a list of attribute values unioned for the given attributes, by split attribute key.

     Args:
        attr_names: The rule attributes to union. Assumed to contain lists of values.
        split_attr: The Starlark interface for 1:2+ transitions, typically from `ctx.split_attr`.
        split_attr_keys: A list of strings representing each 1:2+ transition key to check.

    Returns:
        A new list of attributes based on the union of all rule attributes given, by split
        attribute key.
    """
    unioned_attrs = []
    for attr_name in attr_names:
        attr = getattr(split_attr, attr_name)
        if not attr:
            continue
        for split_attr_key in split_attr_keys:
            found_attr = attr.get(split_attr_key)
            if found_attr:
                unioned_attrs += found_attr
    return unioned_attrs

def _available_library_dictionary(
        *,
        architectures,
        bitcode_symbol_maps,
        environment,
        headers_path,
        library_identifier,
        library_path,
        platform):
    """Generates a dictionary containing keys referencing a framework in the XCFramework bundle.

     Args:
        architectures: The architectures of the target that was built. For example, `x86_64` or
            `arm64`.
        bitcode_symbol_maps: A mapping of architectures to Files representing bitcode symbol maps
            for each architecture.
        environment: The environment of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_common` linking APIs.
            Typically `device` or `simulator`.
        headers_path: A string representing the path inside the library identifier to reference
            bundled headers and modulemap files.
        library_identifier: A string representing the path to the framework to reference in the
            xcframework bundle.
        library_path: A string representing the path inside the library identifier to reference in
            the xcframework bundle.
        platform: The platform of the target that was built, which corresponds to the toolchain's
            target triple values as reported by `apple_common` linking APIs.
            For example, `ios`, `macos`, `tvos` or `watchos`.

    Returns:
        A dictionary containing keys representing how a given framework should be referenced in the
        root Info.plist of a given XCFramework bundle.
    """
    available_library = {
        "LibraryIdentifier": library_identifier,
        "LibraryPath": library_path,
        "SupportedArchitectures": architectures,
        "SupportedPlatform": platform,
    }

    # If there are any bitcode symbol maps for this library, indicate that they are in the
    # BCSymbolMaps subdir.
    #
    # The `BitcodeSymbolMapsPath` is relative to the `LibraryIdentifier`. If `LibraryIdentifier` is
    # `ios-arm64_armv7`, then the path in the xcframework bundle to the bitcode symbol maps will be
    # `ios-arm64_armv7/BCSymbolMaps`
    for bitcode_symbol_map in bitcode_symbol_maps.values():
        if bitcode_symbol_map:
            available_library["BitcodeSymbolMapsPath"] = "BCSymbolMaps"
            break

    if headers_path:
        available_library["HeadersPath"] = headers_path

    if environment != "device":
        available_library["SupportedPlatformVariant"] = environment
    return available_library

def _create_xcframework_root_infoplist(
        *,
        actions,
        apple_fragment,
        available_libraries,
        resolved_plisttool,
        rule_label,
        xcode_config):
    """Generates a root Info.plist for a given XCFramework.

     Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        available_libraries: A dictionary containing keys representing how a given framework should
            be referenced in the root Info.plist of a given XCFramework bundle.
        resolved_plisttool: A struct referencing the resolved plist tool.
        rule_label: The label of the target being analyzed.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.

    Returns:
        A `File` representing a root Info.plist to be embedded within an XCFramework bundle.
    """
    root_info_plist = intermediates.file(
        actions = actions,
        target_name = rule_label.name,
        output_discriminator = None,
        file_name = "Info.plist",
    )

    default_xcframework_plist = {
        "CFBundlePackageType": "XFWK",
        "XCFrameworkFormatVersion": "1.0",
    }

    plisttool_control = struct(
        binary = False,
        output = root_info_plist.path,
        plists = [{"AvailableLibraries": available_libraries}, default_xcframework_plist],
        target = str(rule_label),
    )
    plisttool_control_file = intermediates.file(
        actions = actions,
        target_name = rule_label.name,
        output_discriminator = None,
        file_name = "xcframework_plisttool_control.json",
    )
    actions.write(
        output = plisttool_control_file,
        content = json.encode(plisttool_control),
    )
    apple_support.run(
        actions = actions,
        apple_fragment = apple_fragment,
        arguments = [plisttool_control_file.path],
        executable = resolved_plisttool.executable,
        inputs = depset([plisttool_control_file], transitive = [resolved_plisttool.inputs]),
        input_manifests = resolved_plisttool.input_manifests,
        mnemonic = "CreateXCFrameworkRootInfoPlist",
        outputs = [root_info_plist],
        xcode_config = xcode_config,
    )
    return root_info_plist

def _create_xcframework_bundle(
        *,
        actions,
        bundle_name,
        framework_archive_files,
        framework_archive_merge_files,
        framework_archive_merge_zips = [],
        label_name,
        output_archive,
        resolved_bundletool,
        root_info_plist):
    """Generates the bundle archive for an XCFramework.

     Args:
        actions: The actions providerx from `ctx.actions`.
        bundle_name: The name of the XCFramework bundle.
        framework_archive_files: A list of depsets referencing files to be used as inputs to the
            bundling action. This should include every archive referenced as a "src" of
            framework_archive_merge_zips.
        framework_archive_merge_files: A list of structs representing files that should be merged
            into the bundle. Each struct contains two fields: "src", the path of the file that
            should be merged into the bundle; and "dest", the path inside the bundle where the file
            should be placed. The destination path is relative to `bundle_path`.
        framework_archive_merge_zips: A list of structs representing ZIP archives whose contents
            should be merged into the bundle. Each struct contains two fields: "src", the path of
            the archive whose contents should be merged into the bundle; and "dest", the path inside
            the bundle where the ZIPs contents should be placed. The destination path is relative to
            `bundle_path`.
        label_name: Name of the target being built.
        output_archive: The file representing the final bundled archive.
        resolved_bundletool: A struct referencing the resolved bundle tool.
        root_info_plist: A `File` representing a fully formed root Info.plist for this XCFramework.
    """
    bundletool_control_file = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = None,
        file_name = "xcframework_bundletool_control.json",
    )
    root_info_plist_merge_file = struct(src = root_info_plist.path, dest = "Info.plist")
    bundletool_control = struct(
        bundle_merge_files = [root_info_plist_merge_file] + framework_archive_merge_files,
        bundle_merge_zips = framework_archive_merge_zips,
        bundle_path = bundle_name + ".xcframework",
        output = output_archive.path,
        compress = True,
    )
    actions.write(
        output = bundletool_control_file,
        content = json.encode(bundletool_control),
    )

    actions.run(
        arguments = [bundletool_control_file.path],
        executable = resolved_bundletool.executable,
        inputs = depset(
            direct = [bundletool_control_file, root_info_plist],
            transitive = [resolved_bundletool.inputs] + framework_archive_files,
        ),
        input_manifests = resolved_bundletool.input_manifests,
        mnemonic = "CreateXCFrameworkBundle",
        outputs = [output_archive],
        progress_message = "Bundling %s" % label_name,
    )

def _apple_xcframework_impl(ctx):
    """Experimental WIP implementation of apple_xcframework."""

    if is_experimental_tree_artifact_enabled(config_vars = ctx.var):
        fail("The apple_xcframework rule does not yet support the experimental tree artifact. " +
             "Please ensure that the `apple.experimental.tree_artifact_outputs` variable is not " +
             "set to 1 on the command line or in your active build configuration.")

    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_name = ctx.attr.bundle_name or ctx.attr.name
    executable_name = getattr(ctx.attr, "executable_name", bundle_name)
    deps = ctx.split_attr.deps

    # Add the disable_legacy_signing feature to the list of features
    # TODO(b/72148898): Remove this when dossier based signing becomes the default.
    features = ctx.features
    features.append("disable_legacy_signing")
    label = ctx.label

    # Bundle extension needs to be ".xcframework" for root bundle, but macos/ios/tvos will always
    # be ".framework"
    nested_bundle_extension = ".framework"

    # Similarly, bundle_id is expected to be in terms of the bundle ID for each embedded framework,
    # as this value is not used in the XCFramework's root Info.plist.
    nested_bundle_id = ctx.attr.bundle_id

    for framework_type in ctx.attr.framework_type:
        if framework_type != "dynamic":
            fail("Unsupported framework_type found: " + framework_type)

    link_result = linking_support.register_binary_linking_action(
        ctx,
        # Frameworks do not have entitlements.
        entitlements = None,
        extra_linkopts = [
            "-dynamiclib",
            "-Wl,-install_name,@rpath/{name}{extension}/{name}".format(
                extension = nested_bundle_extension,
                name = bundle_name,
            ),
        ],
        platform_prerequisites = None,
        stamp = ctx.attr.stamp,
    )

    link_outputs_by_library_identifier = _group_link_outputs_by_library_identifier(
        actions = actions,
        apple_fragment = ctx.fragments.apple,
        deps = deps,
        label_name = label.name,
        link_result = link_result,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    available_libraries = []
    framework_archive_files = []
    framework_archive_merge_files = []
    framework_archive_merge_zips = []
    framework_output_files = []
    framework_output_groups = []

    for library_identifier, link_output in link_outputs_by_library_identifier.items():
        binary_artifact = link_output.binary

        rule_descriptor = rule_support.rule_descriptor_no_ctx(
            link_output.platform,
            apple_product_type.framework,
        )

        platform_prerequisites = platform_support.platform_prerequisites(
            apple_fragment = ctx.fragments.apple,
            config_vars = ctx.var,
            cpp_fragment = ctx.fragments.cpp,
            device_families = ctx.attr.families_required.get(
                link_output.platform,
                default = rule_descriptor.allowed_device_families,
            ),
            disabled_features = ctx.disabled_features,
            explicit_minimum_deployment_os = ctx.attr.minimum_deployment_os_versions.get(
                link_output.platform,
            ),
            explicit_minimum_os = ctx.attr.minimum_os_versions.get(link_output.platform),
            features = ctx.features,
            objc_fragment = ctx.fragments.objc,
            platform_type_string = link_output.platform,
            uses_swift = link_output.uses_swift,
            xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        )

        overridden_predeclared_outputs = struct(
            archive = intermediates.file(
                actions = actions,
                target_name = label.name,
                output_discriminator = library_identifier,
                file_name = label.name + ".zip",
            ),
        )

        resource_deps = _unioned_attrs(
            attr_names = ["data", "deps"],
            split_attr = ctx.split_attr,
            split_attr_keys = link_output.split_attr_keys,
        )

        top_level_infoplists = resources.collect(
            attr = ctx.split_attr,
            res_attrs = ["infoplists"],
            split_attr_keys = link_output.split_attr_keys,
        )
        top_level_resources = resources.collect(
            attr = ctx.split_attr,
            res_attrs = ["data"],
            split_attr_keys = link_output.split_attr_keys,
        )

        processor_partials = [
            partials.apple_bundle_info_partial(
                actions = actions,
                bundle_extension = nested_bundle_extension,
                bundle_id = nested_bundle_id,
                bundle_name = bundle_name,
                entitlements = None,
                executable_name = executable_name,
                label_name = label.name,
                output_discriminator = library_identifier,
                platform_prerequisites = platform_prerequisites,
                predeclared_outputs = overridden_predeclared_outputs,
                product_type = rule_descriptor.product_type,
            ),
            partials.binary_partial(
                actions = actions,
                binary_artifact = binary_artifact,
                bundle_name = bundle_name,
                executable_name = executable_name,
                label_name = label.name,
                output_discriminator = library_identifier,
            ),
            partials.bitcode_symbols_partial(
                actions = actions,
                binary_artifact = binary_artifact,
                bitcode_symbol_maps = link_output.bitcode_symbol_maps,
                label_name = label.name,
                output_discriminator = library_identifier,
                platform_prerequisites = platform_prerequisites,
            ),
            partials.debug_symbols_partial(
                actions = actions,
                bin_root_path = bin_root_path,
                bundle_extension = nested_bundle_extension,
                bundle_name = bundle_name,
                debug_discriminator = link_output.platform + "_" + link_output.environment,
                dsym_binaries = link_output.dsym_binaries,
                dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
                executable_name = executable_name,
                linkmaps = link_output.linkmaps,
                platform_prerequisites = platform_prerequisites,
                rule_label = label,
            ),
            partials.resources_partial(
                actions = actions,
                apple_mac_toolchain_info = apple_mac_toolchain_info,
                bundle_extension = nested_bundle_extension,
                bundle_id = nested_bundle_id,
                bundle_name = bundle_name,
                # TODO(b/174858377): Select which environment_plist to use based on Apple platform.
                environment_plist = ctx.file._environment_plist_ios,
                executable_name = executable_name,
                launch_storyboard = None,
                output_discriminator = library_identifier,
                platform_prerequisites = platform_prerequisites,
                resource_deps = resource_deps,
                rule_descriptor = rule_descriptor,
                rule_label = label,
                top_level_infoplists = top_level_infoplists,
                top_level_resources = top_level_resources,
                version = ctx.attr.version,
                version_keys_required = False,
            ),
            partials.swift_dylibs_partial(
                actions = actions,
                apple_mac_toolchain_info = apple_mac_toolchain_info,
                binary_artifact = binary_artifact,
                label_name = label.name,
                platform_prerequisites = platform_prerequisites,
            ),
        ]

        if link_output.uses_swift and link_output.swift_infos:
            processor_partials.append(
                partials.swift_framework_partial(
                    actions = actions,
                    bundle_name = bundle_name,
                    label_name = label.name,
                    output_discriminator = library_identifier,
                    swift_infos = link_output.swift_infos,
                ),
            )
        else:
            processor_partials.append(
                partials.framework_header_modulemap_partial(
                    actions = actions,
                    bundle_name = bundle_name,
                    hdrs = ctx.files.public_hdrs,
                    label_name = label.name,
                    output_discriminator = library_identifier,
                    umbrella_header = ctx.file.umbrella_header,
                ),
            )

        processor_result = processor.process(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = nested_bundle_extension,
            bundle_name = bundle_name,
            entitlements = None,
            executable_name = executable_name,
            features = features,
            ipa_post_processor = None,
            output_discriminator = library_identifier,
            partials = processor_partials,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = overridden_predeclared_outputs,
            process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
            provisioning_profile = None,
            rule_descriptor = rule_descriptor,
            rule_label = label,
        )

        for provider in processor_result.providers:
            # Save the framework archive.
            if getattr(provider, "archive", None):
                # Repackage every archive found for bundle_merge_zips in the final bundler action.
                framework_archive_merge_zips.append(
                    struct(src = provider.archive.path, dest = library_identifier),
                )

                # Save a reference to those archives as file-friendly inputs to the bundler action.
                framework_archive_files.append(depset([provider.archive]))

            # Save the bitcode maps.
            if getattr(provider, "bitcode", None):
                bitcode_files = provider.bitcode.to_list()
                for bitcode_file in bitcode_files:
                    framework_archive_merge_files.append(
                        struct(
                            src = bitcode_file.path,
                            dest = paths.join(library_identifier, "BCSymbolMaps"),
                        ),
                    )
                framework_archive_files.append(provider.bitcode)

            # Save the dSYMs.
            if getattr(provider, "dsyms", None):
                framework_output_files.append(depset(transitive = [provider.dsyms]))
                framework_output_groups.append({"dsyms": provider.dsyms})

            # Save the linkmaps.
            if getattr(provider, "linkmaps", None):
                framework_output_files.append(depset(transitive = [provider.linkmaps]))
                framework_output_groups.append({"linkmaps": provider.linkmaps})

        # Save additional library details for the XCFramework's root info plist.
        available_libraries.append(_available_library_dictionary(
            architectures = link_output.architectures,
            bitcode_symbol_maps = link_output.bitcode_symbol_maps,
            environment = link_output.environment,
            headers_path = None,
            library_identifier = library_identifier,
            library_path = bundle_name + nested_bundle_extension,
            platform = link_output.platform,
        ))

    root_info_plist = _create_xcframework_root_infoplist(
        actions = actions,
        apple_fragment = ctx.fragments.apple,
        available_libraries = available_libraries,
        resolved_plisttool = apple_mac_toolchain_info.resolved_plisttool,
        rule_label = label,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    _create_xcframework_bundle(
        actions = actions,
        bundle_name = bundle_name,
        framework_archive_files = framework_archive_files,
        framework_archive_merge_files = framework_archive_merge_files,
        framework_archive_merge_zips = framework_archive_merge_zips,
        label_name = label.name,
        output_archive = ctx.outputs.archive,
        resolved_bundletool = apple_xplat_toolchain_info.resolved_bundletool,
        root_info_plist = root_info_plist,
    )

    processor_output = [
        # Limiting the contents of AppleBundleInfo to what is necessary for testing and validation.
        AppleBundleInfo(
            archive = ctx.outputs.archive,
            bundle_extension = ".xcframework",
            bundle_id = nested_bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            infoplist = root_info_plist,
            platform_type = None,
        ),
        AppleXcframeworkBundleInfo(),
        DefaultInfo(
            files = depset([ctx.outputs.archive], transitive = framework_output_files),
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                *framework_output_groups
            )
        ),
    ]
    return processor_output

apple_xcframework = rule(
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        rule_factory.common_bazel_attributes.link_multi_arch_binary_attrs(
            cfg = transition_support.xcframework_transition,
        ),
        {
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
            "_environment_plist_ios": attr.label(
                allow_single_file = True,
                default = "@build_bazel_rules_apple//apple/internal:environment_plist_ios",
            ),
            "bundle_id": attr.string(
                doc = """
The bundle ID (reverse-DNS path followed by app name) for each of the embedded frameworks. If
present, this value will be embedded in an Info.plist within each framework bundle.
""",
            ),
            "bundle_name": attr.string(
                mandatory = False,
                doc = """
The desired name of the xcframework bundle (without the extension) and the bundles for all embedded
frameworks. If this attribute is not set, then the name of the target will be used instead.
""",
            ),
            "data": attr.label_list(
                allow_files = True,
                aspects = [apple_resource_aspect],
                cfg = transition_support.xcframework_transition,
                doc = """
A list of resources or files bundled with the bundle. The resources will be stored in the
appropriate resources location within each of the embedded framework bundles.
""",
            ),
            "families_required": attr.string_list_dict(
                doc = """
A list of device families supported by this extension, with platforms such as `ios` as keys. Valid
values are `iphone` and `ipad` for `ios`; at least one must be specified if a platform is defined.
Currently, this only affects processing of `ios` resources.
""",
            ),
            "framework_type": attr.string_list(
                doc = """
Indicates what type of framework the output should be, if defined. Currently only `dynamic` is
supported. If this is not given, the default is to have all contained frameworks built as dynamic
frameworks.
""",
            ),
            "exported_symbols_lists": attr.label_list(
                allow_files = True,
                doc = """
A list of targets containing exported symbols lists files for the linker to control symbol
resolution.

Each file is expected to have a list of global symbol names that will remain as global symbols in
the compiled binary owned by this framework. All other global symbols will be treated as if they
were marked as `__private_extern__` (aka `visibility=hidden`) and will not be global in the output
file.

See the man page documentation for `ld(1)` on macOS for more details.
""",
            ),
            "linkopts": attr.string_list(
                doc = """
A list of strings representing extra flags that should be passed to the linker.
""",
            ),
            "infoplists": attr.label_list(
                allow_empty = False,
                allow_files = [".plist"],
                cfg = transition_support.xcframework_transition,
                doc = """
A list of .plist files that will be merged to form the Info.plist for each of the embedded
frameworks. At least one file must be specified. Please see
[Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling)
for what is supported.
""",
                mandatory = True,
            ),
            "ios": attr.string_list_dict(
                doc = """
A dictionary of strings indicating which platform variants should be built for the `ios` platform (
`device` or `simulator`) as keys, and arrays of strings listing which architectures should be
built for those platform variants (for example, `x86_64`, `arm64`) as their values.
""",
            ),
            "minimum_deployment_os_versions": attr.string_dict(
                doc = """
A dictionary of strings indicating the minimum deployment OS version supported by the target,
represented as a dotted version number (for example, "9.0") as values, with their respective
platforms such as `ios` as keys. This is different from `minimum_os_versions`, which is effective
at compile time. Ensure version specific APIs are guarded with `available` clauses.
""",
                mandatory = False,
            ),
            "minimum_os_versions": attr.string_dict(
                doc = """
A dictionary of strings indicating the minimum OS version supported by the target, represented as a
dotted version number (for example, "8.0") as values, with their respective platforms such as `ios`
as keys.
""",
                mandatory = True,
            ),
            "public_hdrs": attr.label_list(
                allow_files = [".h"],
                doc = """
A list of files directly referencing header files to be used as the publicly visible interface for
each of these embedded frameworks. These header files will be embedded within each bundle,
typically in a subdirectory such as `Headers`.
""",
            ),
            "stamp": attr.int(
                default = -1,
                doc = """
Enable link stamping. Whether to encode build information into the binaries. Possible values:

*   `stamp = 1`: Stamp the build information into the binaries. Stamped binaries are only rebuilt
    when their dependencies change. Use this if there are tests that depend on the build
    information.
*   `stamp = 0`: Always replace build information by constant values. This gives good build
    result caching.
*   `stamp = -1`: Embedding of build information is controlled by the `--[no]stamp` flag.
""",
                values = [-1, 0, 1],
            ),
            "version": attr.label(
                providers = [[AppleBundleVersionInfo]],
                doc = """
An `apple_bundle_version` target that represents the version for this target. See
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).
""",
            ),
            "deps": attr.label_list(
                aspects = [apple_resource_aspect, swift_usage_aspect],
                cfg = transition_support.xcframework_transition,
                doc = """
A list of dependencies targets that will be linked into this each of the framework target's
individual binaries. Any resources, such as asset catalogs, that are referenced by those targets
will also be transitively included in the framework bundles.
""",
            ),
            "umbrella_header": attr.label(
                allow_single_file = [".h"],
                doc = """
An optional single .h file to use as the umbrella header for this framework. Usually, this header
will have the same name as this target, so that clients can load the header using the #import
<MyFramework/MyFramework.h> format. If this attribute is not specified (the common use case), an
umbrella header will be generated under the same name as this target.
""",
            ),
        },
    ),
    fragments = ["apple", "objc", "cpp"],
    implementation = _apple_xcframework_impl,
    outputs = {"archive": "%{name}.xcframework.zip"},
)

def _apple_static_xcframework_impl(ctx):
    """Implementation of apple_static_xcframework."""

    actions = ctx.actions
    apple_fragment = ctx.fragments.apple
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_name = ctx.attr.bundle_name or ctx.label.name
    deps = ctx.split_attr.deps
    label = ctx.label
    executable_name = getattr(ctx.attr, "executable_name", bundle_name)
    outputs_archive = ctx.outputs.archive
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    binary_name = bundle_name + ".a"
    link_result = linking_support.register_static_library_linking_action(ctx = ctx)
    link_outputs_by_library_identifier = _group_link_outputs_by_library_identifier(
        actions = actions,
        apple_fragment = apple_fragment,
        deps = deps,
        label_name = bundle_name,
        link_result = link_result,
        xcode_config = xcode_config,
    )

    available_libraries = []
    framework_archive_files = []
    framework_archive_merge_files = []
    for library_identifier, link_output in link_outputs_by_library_identifier.items():
        # Bundle binary artifact for specific library identifier
        binary_artifact = link_output.binary
        framework_archive_merge_files.append(struct(
            src = binary_artifact.path,
            dest = paths.join(library_identifier, binary_name),
        ))
        framework_archive_files.append(depset([binary_artifact]))

        if link_output.uses_swift and link_output.swift_infos:
            # Generate headers, modulemaps, and swiftmodules
            interface_artifacts = partial.call(
                partials.swift_framework_partial(
                    actions = actions,
                    avoid_deps = ctx.attr.avoid_deps,
                    bundle_name = bundle_name,
                    framework_modulemap = False,
                    label_name = label.name,
                    output_discriminator = library_identifier,
                    swift_infos = link_output.swift_infos,
                ),
            )
        else:
            # Generate headers, and modulemaps
            sdk_frameworks = cc_info_support.get_sdk_frameworks(
                deps = ctx.split_attr.deps,
                split_deps_keys = link_output.split_attr_keys,
            )
            sdk_dylibs = cc_info_support.get_sdk_dylibs(
                deps = ctx.split_attr.deps,
                split_deps_keys = link_output.split_attr_keys,
            )
            interface_artifacts = partial.call(partials.framework_header_modulemap_partial(
                actions = actions,
                bundle_name = bundle_name,
                framework_modulemap = False,
                hdrs = ctx.files.public_hdrs,
                label_name = label.name,
                output_discriminator = library_identifier,
                umbrella_header = ctx.file.umbrella_header,
                sdk_frameworks = sdk_frameworks,
                sdk_dylibs = sdk_dylibs,
            ))

        # Bundle headers & modulemaps (and swiftmodules if available)
        for _, bundle_relative_path, files in interface_artifacts.bundle_files:
            framework_archive_files.append(files)
            for file in files.to_list():
                # For Swift based static XCFrameworks, Xcode requires .swiftmodule files to be
                # located under each library identifier directory. While headers and modulemap
                # files need to be under a Headers/ directory. Thus, we default all interface
                # artifacts to be moved to the Headers directory, except for swiftmodule files.
                #
                # e.g.
                #     ios_arm64/
                #       ├── libStatic.a
                #       ├── Headers/..
                #       └── libStatic.swiftmodule/..
                dest_bundle_relative_path = "Headers"
                if ".swiftmodule" in bundle_relative_path:
                    dest_bundle_relative_path = bundle_relative_path.replace("Modules/", "")
                framework_archive_merge_files.append(struct(
                    src = file.path,
                    dest = paths.join(
                        library_identifier,
                        dest_bundle_relative_path,
                        file.basename,
                    ),
                ))

        # Save additional library details for the XCFramework's root info plist.
        available_libraries.append(
            _available_library_dictionary(
                architectures = link_output.architectures,
                bitcode_symbol_maps = {},
                environment = link_output.environment,
                headers_path = "Headers",
                library_identifier = library_identifier,
                library_path = binary_name,
                platform = link_output.platform,
            ),
        )

    root_info_plist = _create_xcframework_root_infoplist(
        actions = actions,
        apple_fragment = apple_fragment,
        available_libraries = available_libraries,
        resolved_plisttool = apple_mac_toolchain_info.resolved_plisttool,
        rule_label = label,
        xcode_config = xcode_config,
    )

    _create_xcframework_bundle(
        actions = actions,
        bundle_name = bundle_name,
        framework_archive_files = framework_archive_files,
        framework_archive_merge_files = framework_archive_merge_files,
        label_name = label.name,
        output_archive = outputs_archive,
        resolved_bundletool = apple_xplat_toolchain_info.resolved_bundletool,
        root_info_plist = root_info_plist,
    )

    return [
        # Limiting the contents of AppleBundleInfo to what is necessary for testing and validation.
        AppleBundleInfo(
            archive = outputs_archive,
            bundle_extension = ".xcframework",
            bundle_name = bundle_name,
            executable_name = executable_name,
            infoplist = root_info_plist,
            platform_type = None,
        ),
        AppleStaticXcframeworkBundleInfo(),
        DefaultInfo(
            files = depset([outputs_archive]),
        ),
    ]

apple_static_xcframework = rule(
    implementation = _apple_static_xcframework_impl,
    doc = """
Generates an XCFramework with static libraries for third-party distribution.

NOTE: This is only supported on bazel 6.0+
""",
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        rule_factory.common_bazel_attributes.link_multi_arch_static_library_attrs(
            cfg = transition_support.xcframework_transition,
        ),
        {
            "executable_name": attr.string(
                mandatory = False,
                doc = """
The desired name of the executable, if the bundle has an executable. If this attribute is not set,
then the name of the `bundle_name` attribute will be used if it is set; if not, then the name of
the target will be used instead.
""",
            ),
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
            "avoid_deps": attr.label_list(
                allow_files = True,
                cfg = transition_support.xcframework_transition,
                mandatory = False,
                doc = """
A list of library targets on which this framework depends in order to compile, but the transitive
closure of which will not be linked into the framework's binary.
""",
            ),
            "bundle_name": attr.string(
                mandatory = False,
                doc = """
The desired name of the XCFramework bundle (without the extension) and the binaries for all embedded
static libraries. If this attribute is not set, then the name of the target will be used instead.
""",
            ),
            "deps": attr.label_list(
                aspects = [swift_usage_aspect],
                allow_files = True,
                cfg = transition_support.xcframework_transition,
                mandatory = True,
                doc = """
A list of files directly referencing libraries to be represented for each given platform split in
the XCFramework. These libraries will be embedded within each platform split.
""",
            ),
            "ios": attr.string_list_dict(
                doc = """
A dictionary of strings indicating which platform variants should be built for the `ios` platform (
`device` or `simulator`) as keys, and arrays of strings listing which architectures should be
built for those platform variants (for example, `x86_64`, `arm64`) as their values.
""",
            ),
            "minimum_deployment_os_versions": attr.string_dict(
                doc = """
A dictionary of strings indicating the minimum deployment OS version supported by the target,
represented as a dotted version number (for example, "9.0") as values, with their respective
platforms such as `ios` as keys. This is different from `minimum_os_versions`, which is effective
at compile time. Ensure version specific APIs are guarded with `available` clauses.
""",
                mandatory = False,
            ),
            "minimum_os_versions": attr.string_dict(
                mandatory = True,
                doc = """
A dictionary of strings indicating the minimum OS version supported by the target, represented as a
dotted version number (for example, "8.0") as values, with their respective platforms such as `ios`
as keys.
""",
            ),
            "public_hdrs": attr.label_list(
                allow_files = [".h"],
                cfg = transition_support.xcframework_transition,
                doc = """
A list of files directly referencing header files to be used as the publicly visible interface for
each of these embedded libraries. These header files will be embedded within each platform split,
typically in a subdirectory such as `Headers`.
""",
            ),
            "umbrella_header": attr.label(
                allow_single_file = [".h"],
                doc = """
An optional single .h file to use as the umbrella header for this framework. Usually, this header
will have the same name as this target, so that clients can load the header using the #import
<MyFramework/MyFramework.h> format. If this attribute is not specified (the common use case), an
umbrella header will be generated under the same name as this target.
""",
            ),
        },
    ),
    fragments = ["apple", "objc", "cpp"],
    outputs = {"archive": "%{name}.xcframework.zip"},
)
