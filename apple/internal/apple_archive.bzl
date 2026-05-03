"""
Rule for packaging a bundle into an Apple archive.
"""

load(
    "//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleCodesigningDossierInfo",
    "AppleDsymBundleInfo",
)
load(
    "//apple/internal:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "//apple/internal:providers.bzl",
    "new_applebundleinfo",
)
load(
    "//apple/internal/providers:apple_debug_info.bzl",
    "AppleDebugInfo",
)
load(
    "//apple/internal/providers:apple_messages_stub_info.bzl",
    "AppleMessagesStubInfo",
)
load(
    "//apple/internal/providers:apple_swift_dylibs_info.bzl",
    "AppleSwiftDylibsInfo",
)
load(
    "//apple/internal/providers:apple_symbols_file_info.bzl",
    "AppleSymbolsFileInfo",
)
load(
    "//apple/internal/providers:apple_watchos_stub_info.bzl",
    "AppleWatchosStubInfo",
)
load(
    "//apple/internal/utils:defines.bzl",
    "defines",
)

def _output_group_names(output_group_info):
    """Returns the declared output group names for an OutputGroupInfo provider."""
    return [name for name in dir(output_group_info) if name not in ["to_json", "to_proto"]]

def _output_groups_for_archive(bundle_target, combined_zip = None):
    """Returns the output groups that should be exposed by apple_archive."""
    output_groups = {}

    if OutputGroupInfo in bundle_target:
        bundle_output_groups = bundle_target[OutputGroupInfo]
        for output_group_name in _output_group_names(bundle_output_groups):
            output_groups[output_group_name] = getattr(bundle_output_groups, output_group_name)

    if combined_zip:
        output_groups["combined_dossier_zip"] = depset([combined_zip])

    return output_groups

def _is_macos_bundle(bundle_info):
    """Returns whether the bundle targets macOS."""
    return bundle_info.platform_type == "macos"

def _archive_extension(bundle_info):
    """Returns the archive file extension for the bundle."""
    return "zip" if _is_macos_bundle(bundle_info) else "ipa"

def _archive_bundle_destination(bundle_info):
    """Returns the archive-relative destination for the packaged bundle."""
    bundle_with_extension = "%s%s" % (bundle_info.bundle_name, bundle_info.bundle_extension)
    if _is_macos_bundle(bundle_info):
        return bundle_with_extension
    return "Payload/%s" % bundle_with_extension

def _should_compress_archive(ctx):
    """Determines if the archive should be compressed based on defines and compilation mode."""
    return defines.bool_value(
        config_vars = ctx.var,
        define_name = "apple.compress_ipa",
        default = (ctx.var.get("COMPILATION_MODE") == "opt"),
    )

def _collect_symbols_files(ctx, bundle_merge_files):
    """Collects symbols files and adds them to bundle_merge_files.

    Args:
        ctx: The rule context.
        bundle_merge_files: List to append symbols merge structs to.

    Returns:
        List of symbols input files.
    """
    symbols_inputs = []
    if ctx.attr.include_symbols and AppleSymbolsFileInfo in ctx.attr.bundle:
        symbols_info = ctx.attr.bundle[AppleSymbolsFileInfo]
        symbols_inputs = symbols_info.symbols_output_dirs.to_list()
        for symbols_dir in symbols_inputs:
            bundle_merge_files.append(
                struct(
                    src = symbols_dir.path,
                    dest = "Symbols",
                ),
            )
    return symbols_inputs

def _collect_swift_support_files(ctx, bundle_merge_files):
    """Collects Swift support files and adds them to bundle_merge_files.

    Args:
        ctx: The rule context.
        bundle_merge_files: List to append Swift support merge structs to.

    Returns:
        List of Swift support input files.
    """
    swift_support_inputs = []
    if AppleSwiftDylibsInfo in ctx.attr.bundle:
        swift_dylibs_info = ctx.attr.bundle[AppleSwiftDylibsInfo]
        for platform_name, swift_support_dir in swift_dylibs_info.swift_support_files:
            swift_support_inputs.append(swift_support_dir)
            bundle_merge_files.append(
                struct(
                    src = swift_support_dir.path,
                    dest = "SwiftSupport/%s" % platform_name,
                ),
            )
    return swift_support_inputs

def _collect_watchos_stub_files(ctx, bundle_merge_files):
    """Collects WatchOS stub files and adds them to bundle_merge_files.

    Args:
        ctx: The rule context.
        bundle_merge_files: List to append WatchOS stub merge structs to.

    Returns:
        List of WatchOS stub input files.
    """
    watchos_stub_inputs = []
    if AppleWatchosStubInfo in ctx.attr.bundle:
        watchos_stub_info = ctx.attr.bundle[AppleWatchosStubInfo]
        watchos_stub_inputs.append(watchos_stub_info.binary)
        bundle_merge_files.append(
            struct(
                src = watchos_stub_info.binary.path,
                dest = "WatchKitSupport2/WK",
            ),
        )
    return watchos_stub_inputs

def _collect_messages_stub_files(ctx, bundle_merge_files):
    """Collects iMessage stub files and adds them to bundle_merge_files.

    Args:
        ctx: The rule context.
        bundle_merge_files: List to append messages stub merge structs to.

    Returns:
        List of messages stub input files.
    """
    messages_stub_inputs = []
    if AppleMessagesStubInfo in ctx.attr.bundle:
        messages_stub_info = ctx.attr.bundle[AppleMessagesStubInfo]
        if messages_stub_info.messages_application_support:
            messages_stub_inputs.append(messages_stub_info.messages_application_support)
            bundle_merge_files.append(
                struct(
                    src = messages_stub_info.messages_application_support.path,
                    dest = "MessagesApplicationSupport/MessagesApplicationSupportStub",
                ),
            )
        if messages_stub_info.messages_extension_support:
            messages_stub_inputs.append(messages_stub_info.messages_extension_support)
            bundle_merge_files.append(
                struct(
                    src = messages_stub_info.messages_extension_support.path,
                    dest = "MessagesApplicationExtensionSupport/MessagesApplicationExtensionSupportStub",
                ),
            )
    return messages_stub_inputs

def _create_archive_file(ctx, bundle_info, bundletool, should_compress, all_inputs):
    """Creates the archive file using bundletool.

    Args:
        ctx: The rule context.
        bundle_info: The AppleBundleInfo provider.
        bundletool: The bundletool executable.
        should_compress: Whether to compress the archive.
        all_inputs: Tuple of (bundle_merge_files, symbols_inputs,
                    swift_support_inputs, watchos_stub_inputs, messages_stub_inputs).

    Returns:
        The declared archive file.
    """
    bundle_merge_files, symbols_inputs, swift_support_inputs, watchos_stub_inputs, messages_stub_inputs = all_inputs

    archive = ctx.actions.declare_file("%s.%s" % (
        ctx.label.name,
        _archive_extension(bundle_info),
    ))

    control = struct(
        bundle_merge_files = bundle_merge_files,
        output = archive.path,
        compress = should_compress,
    )

    control_file = ctx.actions.declare_file("%s_control.json" % ctx.label.name)
    ctx.actions.write(
        output = control_file,
        content = json.encode(control),
    )

    ctx.actions.run(
        executable = bundletool.files_to_run,
        arguments = [control_file.path],
        inputs = [
            control_file,
            bundle_info.archive,
        ] + symbols_inputs + swift_support_inputs + watchos_stub_inputs + messages_stub_inputs,
        outputs = [archive],
        mnemonic = "CreateArchive",
        exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx),
    )

    return archive

def _create_combined_dossier_zip(ctx, bundletool, archive, dossier_zip):
    """Creates a combined zip file containing both the IPA and dossier.

    Args:
        ctx: The rule context.
        bundletool: The bundletool executable.
        archive: The archive file.
        dossier_zip: The dossier zip file.

    Returns:
        The combined zip file.
    """
    combined_zip = ctx.actions.declare_file("%s_dossier_with_bundle.zip" % ctx.label.name)

    control = struct(
        bundle_merge_zips = [
            struct(src = archive.path, dest = "bundle"),
            struct(src = dossier_zip.path, dest = "dossier"),
        ],
        output = combined_zip.path,
    )

    control_file = ctx.actions.declare_file("%s_combined_control.json" % ctx.label.name)
    ctx.actions.write(
        output = control_file,
        content = json.encode(control),
    )

    ctx.actions.run(
        executable = bundletool.files_to_run,
        arguments = [control_file.path],
        inputs = [control_file, archive, dossier_zip],
        outputs = [combined_zip],
        mnemonic = "CreateCombinedDossierZip",
        exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx),
    )

    return combined_zip

def _create_apple_bundle_info(bundle_info, archive):
    """Creates an AppleBundleInfo provider for the archive.

    Args:
        bundle_info: The original AppleBundleInfo from the bundle.
        archive: The archive file.

    Returns:
        An AppleBundleInfo provider.
    """
    return new_applebundleinfo(
        archive = archive,
        archive_root = bundle_info.archive_root,
        binary = bundle_info.binary,
        bundle_extension = bundle_info.bundle_extension,
        bundle_id = bundle_info.bundle_id,
        bundle_name = bundle_info.bundle_name,
        entitlements = bundle_info.entitlements,
        executable_name = bundle_info.executable_name,
        extension_safe = bundle_info.extension_safe,
        infoplist = bundle_info.infoplist,
        minimum_deployment_os_version = bundle_info.minimum_deployment_os_version,
        minimum_os_version = bundle_info.minimum_os_version,
        platform_type = bundle_info.platform_type,
        product_type = bundle_info.product_type,
        uses_swift = bundle_info.uses_swift,
    )

def _apple_archive_impl(ctx):
    """
    Implementation for apple_archive.

    This rule uses the providers from the bundle target to re-package it into an archive.
    Apple application bundles are packaged as `.ipa` files for iOS/tvOS/watchOS and `.zip`
    files for macOS.
    """
    bundle_info = ctx.attr.bundle[AppleBundleInfo]
    xplat_tools = apple_toolchain_utils.get_xplat_toolchain(ctx)
    bundletool = xplat_tools.bundletool

    should_compress = _should_compress_archive(ctx)

    # Package the bundle tree artifact into an Apple archive.
    bundle_merge_files = [
        struct(
            src = bundle_info.archive.path,
            dest = _archive_bundle_destination(bundle_info),
        ),
    ]

    symbols_inputs = _collect_symbols_files(ctx, bundle_merge_files)
    swift_support_inputs = _collect_swift_support_files(ctx, bundle_merge_files)
    watchos_stub_inputs = _collect_watchos_stub_files(ctx, bundle_merge_files)
    messages_stub_inputs = _collect_messages_stub_files(ctx, bundle_merge_files)

    all_inputs = (bundle_merge_files, symbols_inputs, swift_support_inputs, watchos_stub_inputs, messages_stub_inputs)
    archive = _create_archive_file(ctx, bundle_info, bundletool, should_compress, all_inputs)

    combined_zip = None
    if AppleCodesigningDossierInfo in ctx.attr.bundle:
        dossier_info = ctx.attr.bundle[AppleCodesigningDossierInfo]
        dossier_zip = dossier_info.dossier
        combined_zip = _create_combined_dossier_zip(ctx, bundletool, archive, dossier_zip)

    apple_archive_bundle_info = _create_apple_bundle_info(bundle_info, archive)

    providers = [
        DefaultInfo(files = depset([archive])),
        apple_archive_bundle_info,
        OutputGroupInfo(**_output_groups_for_archive(
            bundle_target = ctx.attr.bundle,
            combined_zip = combined_zip,
        )),
    ]

    if AppleDsymBundleInfo in ctx.attr.bundle:
        providers.append(ctx.attr.bundle[AppleDsymBundleInfo])

    if AppleDebugInfo in ctx.attr.bundle:
        providers.append(ctx.attr.bundle[AppleDebugInfo])

    return providers

apple_archive = rule(
    implementation = _apple_archive_impl,
    attrs = {
        "bundle": attr.label(
            providers = [
                AppleBundleInfo,
            ],
            doc = """\
The label to a target to re-package into an Apple archive. For example, an
`ios_application` or `macos_application` target.
            """,
        ),
        "include_symbols": attr.bool(
            default = False,
            doc = """
    If true, collects `$UUID.symbols`
    files from all `{binary: .dSYM, ...}` pairs for the application and its
    dependencies, then packages them under the `Symbols/` directory in the
    final archive.
    """,
        ),
    },
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    doc = """\
Re-packages an Apple bundle into an Apple archive.

This rule uses the providers from the bundle target to construct the required
metadata for the archive. iOS/tvOS/watchOS applications produce an `.ipa`;
macOS applications produce a `.zip`. The archive target preserves the wrapped
bundle target's debug providers and output groups so follow-on artifacts such
as dSYMs and linkmaps remain available from the archive target.

Example:

````starlark
load("//apple:apple_archive.bzl", "apple_archive")

ios_application(
    name = "App",
    bundle_id = "com.example.my.app",
    ...
)

apple_archive(
    name = "AppArchive",
    bundle = ":App",
)
````
    """,
)
