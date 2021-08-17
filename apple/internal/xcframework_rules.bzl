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
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleBundleVersionInfo",
    "AppleSupportToolchainInfo",
    "AppleXcframeworkBundleInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_usage_aspect",
)

# TODO(b/174858377): Allow for multiple 1:2+ transition keys when we support lipoed xcframework
# contents.
def _unioned_attrs(*, attr_names, split_attr, split_attr_key):
    """Return a list of attribute values unioned for the given attributes, by split attribute key.

     Args:
        attr_names: The rule attributes to union. Assumed to contain lists of values.
        split_attr: The Starlark interface for 1:2+ transitions, typically from `ctx.split_attr`.
        split_attr_key: A string representing the 1:2+ transition key.

    Returns:
        A new list of attributes based on the union of all rule attributes given, by split
            attribute key.
    """
    unioned_attrs = []
    for attr_name in attr_names:
        attr = getattr(split_attr, attr_name)
        if not attr:
            continue
        found_attr = attr.get(split_attr_key)
        if found_attr:
            unioned_attrs += found_attr
    return unioned_attrs

def _available_library_dictionary(
        *,
        architecture,
        bundle_extension,
        bundle_name,
        environment,
        platform,
        split_attr_key):
    """Generates a dictionary containing keys referencing a framework in the XCFramework bundle.

     Args:
        architecture: The architecture of the target that was built. For example, `x86_64` or
            `arm64`.
        bundle_extension: The extension for the library inside the archive.
        bundle_name: The name of the library inside the archive.
        environment: The environment of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_support.link_multi_arch_binary`.
            for environment. Typically `device` or `simulator`.
        platform: The platform of the target that was built, which corresponds to the toolchain's
            target triple values as reported by `apple_support.link_multi_arch_binary` for platform.
            For example, `ios`, `macos`, `tvos` or `watchos`.
        split_attr_key: A string representing the 1:2+ transition key.

    Returns:
        A dictionary containing keys representing how a given framework should be referenced in the
            root Info.plist of a given XCFramework bundle.
    """
    available_library = {
        "LibraryIdentifier": split_attr_key,
        "LibraryPath": bundle_name + bundle_extension,
        "SupportedArchitectures": [
            architecture,
        ],
        "SupportedPlatform": platform,
    }

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
        xcode_config,
        xcode_path_wrapper):
    """Generates a root Info.plist for a given XCFramework.

     Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        available_libraries: A dictionary containing keys representing how a given framework should
            be referenced in the root Info.plist of a given XCFramework bundle.
        resolved_plisttool: A struct referencing the resolved plist tool.
        rule_label: The label of the target being analyzed.
        xcode_version_config: The `apple_common.XcodeVersionConfig` provider from the context.
        xcode_path_wrapper: The Xcode path wrapper script.

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
        xcode_path_wrapper = xcode_path_wrapper,
    )
    return root_info_plist

def _create_xcframework_bundle(
        *,
        actions,
        bundle_name,
        framework_archive_files,
        framework_archive_merge_zips,
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
    bundletool_control = struct(
        bundle_merge_files = [struct(src = root_info_plist.path, dest = "Info.plist")],
        bundle_merge_zips = framework_archive_merge_zips,
        bundle_path = bundle_name + ".xcframework",
        output = output_archive.path,
    )
    actions.write(
        output = bundletool_control_file,
        content = json.encode(bundletool_control),
    )

    actions.run(
        arguments = [bundletool_control_file.path],
        executable = resolved_bundletool.executable,
        inputs = depset([bundletool_control_file, root_info_plist], transitive = [resolved_bundletool.inputs] + framework_archive_files),
        input_manifests = resolved_bundletool.input_manifests,
        mnemonic = "CreateXCFrameworkBundle",
        outputs = [output_archive],
        progress_message = "Bundling %s" % label_name,
    )

def _apple_xcframework_impl(ctx):
    """Experimental WIP implementation of apple_xcframework."""

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]

    # Bundle extension needs to be ".xcframework" for root bundle, but macos/ios/tvos will always
    # be ".framework"
    nested_bundle_extension = ".framework"

    # Similarly, bundle_id is expected to be in terms of the bundle ID for each embedded framework,
    # as this value is not used in the XCFramework's root Info.plist.
    nested_bundle_id = ctx.attr.bundle_id
    bundle_name = ctx.attr.bundle_name or ctx.attr.name
    executable_name = getattr(ctx.attr, "executable_name", bundle_name)

    # Add the disable_legacy_signing feature to the list of features
    # TODO(b/72148898): Remove this when dossier based signing becomes the default.
    features = ctx.features
    features.append("disable_legacy_signing")
    label = ctx.label

    for framework_type in ctx.attr.framework_type:
        if framework_type != "dynamic":
            fail("Unsupported framework_type found: " + framework_type)

    link_result = linking_support.register_linking_action(
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

    framework_archive_files = []
    framework_archive_merge_zips = []
    available_libraries = []

    # TODO(b/174858377): Match outputs in a means that allows for lipo.
    for link_output in link_result.outputs:
        split_attr_key = transition_support.xcframework_split_attr_key(
            cpu = link_output.architecture,
            environment = link_output.environment,
            platform_type = link_output.platform,
        )

        binary_artifact = link_output.binary
        uses_swift = swift_support.uses_swift(ctx.split_attr.deps[split_attr_key])
        rule_descriptor = rule_support.rule_descriptor_no_ctx(
            link_output.platform,
            apple_product_type.framework,
        )

        platform_prerequisites = platform_support.platform_prerequisites(
            apple_fragment = ctx.fragments.apple,
            config_vars = ctx.var,
            device_families = getattr(
                ctx.attr.families_required,
                link_output.platform,
                rule_descriptor.allowed_device_families,
            ),
            disabled_features = ctx.disabled_features,
            explicit_minimum_deployment_os = getattr(
                ctx.attr.minimum_deployment_os_versions,
                link_output.platform,
                None,
            ),
            explicit_minimum_os = getattr(
                ctx.attr.minimum_os_versions,
                link_output.platform,
                None,
            ),
            features = ctx.features,
            objc_fragment = ctx.fragments.objc,
            platform_type_string = link_output.platform,
            uses_swift = uses_swift,
            xcode_path_wrapper = ctx.executable._xcode_path_wrapper,
            xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        )

        overridden_predeclared_outputs = struct(
            archive = intermediates.file(
                actions = actions,
                target_name = label.name,
                output_discriminator = split_attr_key,
                file_name = label.name + ".zip",
            ),
        )

        resource_deps = _unioned_attrs(
            attr_names = ["data", "deps"],
            split_attr = ctx.split_attr,
            split_attr_key = split_attr_key,
        )

        top_level_infoplists = resources.collect(
            attr = ctx.split_attr,
            res_attrs = ["infoplists"],
            split_attr_keys = [split_attr_key],
        )
        top_level_resources = resources.collect(
            attr = ctx.split_attr,
            res_attrs = ["data"],
            split_attr_keys = [split_attr_key],
        )

        # TODO(b/174858377): Add support for debug outputs such as dSYM bundles.
        processor_partials = [
            partials.apple_bundle_info_partial(
                actions = actions,
                bundle_extension = nested_bundle_extension,
                bundle_id = nested_bundle_id,
                bundle_name = bundle_name,
                entitlements = None,
                executable_name = executable_name,
                label_name = label.name,
                output_discriminator = split_attr_key,
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
                output_discriminator = split_attr_key,
            ),
            partials.framework_headers_partial(hdrs = ctx.files.public_hdrs),
            partials.resources_partial(
                actions = actions,
                apple_toolchain_info = apple_toolchain_info,
                bundle_extension = nested_bundle_extension,
                bundle_id = nested_bundle_id,
                bundle_name = bundle_name,
                # TODO(b/174858377): Select which environment_plist to use based on Apple platform.
                environment_plist = ctx.file._environment_plist_ios,
                executable_name = executable_name,
                launch_storyboard = None,
                output_discriminator = split_attr_key,
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
                apple_toolchain_info = apple_toolchain_info,
                binary_artifact = binary_artifact,
                label_name = label.name,
                platform_prerequisites = platform_prerequisites,
            ),
        ]

        processor_result = processor.process(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = nested_bundle_extension,
            bundle_name = bundle_name,
            entitlements = None,
            executable_name = executable_name,
            features = features,
            ipa_post_processor = None,
            output_discriminator = split_attr_key,
            partials = processor_partials,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = overridden_predeclared_outputs,
            process_and_sign_template = apple_toolchain_info.process_and_sign_template,
            provisioning_profile = None,
            rule_descriptor = rule_descriptor,
            rule_label = label,
        )

        for provider in processor_result.providers:
            if getattr(provider, "archive", None):
                # Repackage every archive found for bundle_merge_zips in the final bundler action.
                framework_archive_merge_zips.append(
                    struct(src = provider.archive.path, dest = split_attr_key),
                )

                # Save a reference to those archives as file-friendly inputs to the bundler action.
                framework_archive_files.append(depset([provider.archive]))

        # Save additional library details for the XCFramework's root info plist.
        available_libraries.append(_available_library_dictionary(
            architecture = link_output.architecture,
            bundle_extension = nested_bundle_extension,
            bundle_name = bundle_name,
            environment = link_output.environment,
            platform = link_output.platform,
            split_attr_key = split_attr_key,
        ))

    root_info_plist = _create_xcframework_root_infoplist(
        actions = actions,
        apple_fragment = ctx.fragments.apple,
        available_libraries = available_libraries,
        resolved_plisttool = apple_toolchain_info.resolved_plisttool,
        rule_label = label,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        xcode_path_wrapper = ctx.executable._xcode_path_wrapper,
    )

    _create_xcframework_bundle(
        actions = actions,
        bundle_name = bundle_name,
        framework_archive_files = framework_archive_files,
        framework_archive_merge_zips = framework_archive_merge_zips,
        label_name = label.name,
        output_archive = ctx.outputs.archive,
        resolved_bundletool = apple_toolchain_info.resolved_bundletool,
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
            files = depset([ctx.outputs.archive]),
        ),
    ]
    return processor_output

apple_xcframework = rule(
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "_child_configuration_dummy": attr.label(
            cfg = transition_support.xcframework_transition,
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_environment_plist_ios": attr.label(
            allow_single_file = True,
            default = "@build_bazel_rules_apple//apple/internal:environment_plist_ios",
        ),
        "_toolchain": attr.label(
            default = Label("@build_bazel_rules_apple//apple/internal:toolchain_support"),
            providers = [[AppleSupportToolchainInfo]],
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                fragment = "apple",
                name = "xcode_config_label",
            ),
        ),
        "_xcode_path_wrapper": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_apple_support//tools:xcode_path_wrapper"),
        ),
        "_xcrunwrapper": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:xcrunwrapper"),
            executable = True,
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
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).
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
    },
    fragments = ["apple", "objc", "cpp"],
    implementation = _apple_xcframework_impl,
    outputs = {"archive": "%{name}.xcframework.zip"},
)
