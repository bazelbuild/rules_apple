"""Partial implementation for developer framework import file processing."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "//apple:providers.bzl",
    "AppleDeveloperFrameworkImportInfo",
)
load(
    "//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "//apple/internal:processor.bzl",
    "processor",
)

def _developer_framework_import_partial_impl(
        *,
        actions,
        apple_mac_toolchain_info,
        label_name,
        output_discriminator,
        platform_prerequisites,
        targets):
    bundle_zips = []
    signed_frameworks_list = []
    developer_frameworks = {}

    for target in targets:
        if AppleDeveloperFrameworkImportInfo not in target:
            continue

        info = target[AppleDeveloperFrameworkImportInfo]
        if not info.bundle:
            continue

        developer_frameworks[info.framework_name] = info

    for framework_name in sorted(developer_frameworks.keys()):
        framework_info = developer_frameworks[framework_name]
        framework_zip = intermediates.file(
            actions = actions,
            target_name = label_name,
            output_discriminator = output_discriminator,
            file_name = "_developer_frameworks/{}.framework.zip".format(framework_name),
        )
        temp_framework_bundle_path = framework_zip.path[:-len(".zip")]

        args = actions.args()
        args.add("--framework_binary", framework_info.binary.path)
        args.add_all(
            framework_info.runtime_imports.to_list(),
            before_each = "--framework_file",
        )
        args.add("--output_zip", framework_zip.path)
        args.add("--temp_path", temp_framework_bundle_path)

        preserved_framework_processor = apple_mac_toolchain_info.preserved_framework_processor
        input_files = framework_info.runtime_imports.to_list() + [framework_info.binary]

        apple_support.run(
            actions = actions,
            apple_fragment = platform_prerequisites.apple_fragment,
            arguments = [args],
            executable = preserved_framework_processor,
            inputs = input_files,
            mnemonic = "PreservedFrameworkProcessor",
            outputs = [framework_zip],
            xcode_config = platform_prerequisites.xcode_version_config,
        )

        bundle_zips.append(
            (processor.location.framework, None, depset([framework_zip])),
        )
        signed_frameworks_list.append("{}.framework".format(framework_name))

    return struct(
        bundle_zips = bundle_zips,
        signed_frameworks = depset(signed_frameworks_list),
    )

def developer_framework_import_partial(
        *,
        actions,
        apple_mac_toolchain_info,
        label_name,
        output_discriminator = None,
        platform_prerequisites,
        targets):
    """Constructor for developer framework import file processing."""
    return partial.make(
        _developer_framework_import_partial_impl,
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        label_name = label_name,
        output_discriminator = output_discriminator,
        platform_prerequisites = platform_prerequisites,
        targets = targets,
    )
