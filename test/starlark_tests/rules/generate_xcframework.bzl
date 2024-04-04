# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""Rules to generate import-ready XCFrameworks for testing."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:generation_support.bzl",
    "generation_support",
)
load("@build_bazel_rules_swift//swift:providers.bzl", "SwiftInfo")

visibility("//test/starlark_tests/...")

_PLATFORM_TO_SDK = {
    "ios": "iphoneos",
    "ios_simulator": "iphonesimulator",
    "macos": "macosx",
    "tvos": "appletvos",
    "tvos_simulator": "appletvsimulator",
    "watchos": "watchos",
    "watchos_simulator": "watchsimulator",
}

def _platform_to_library_identifier(platform, architectures):
    """Returns an XCFramework library identifier based on archs, environment, and platform.

    Args:
        platform: Target Apple platform for the XCFramework library (e.g. macos, ios)
        architectures: List of architectures supported by the XCFramework library
            (e.g. ['arm64', 'x86_64']).
    Returns:
        A string representing an XCFramework library identifier.
    """
    platform, _, environment = platform.partition("_")
    environment = environment if environment else "device"
    return "{platform}-{architectures}{environment}".format(
        platform = platform,
        architectures = "_".join(sorted(architectures)),
        environment = "-{0}".format(environment) if environment != "device" else "",
    )

def _sdk_for_platform(platform):
    """Returns an Apple platform SDK name for xcrun command flags.

    Args:
        platform: Target Apple platform for the XCFramework library (e.g. macos, ios)
    Returns:
        A string representing an Apple SDK.
    """
    if platform not in _PLATFORM_TO_SDK:
        fail("Invalid platform: %s - must follow format <apple_os>[_<environment>]" % platform)

    return _PLATFORM_TO_SDK[platform]

def _create_xcframework(
        *,
        actions,
        apple_fragment,
        frameworks = {},
        headers = [],
        label,
        libraries = [],
        module_interfaces = [],
        target_dir,
        xcode_config):
    """Generates XCFramework using xcodebuild.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        frameworks: Dictionary of framework paths and framework files.
        headers: A list of files referencing headers.
        label: Label of the target being built.
        libraries: A list of files referencing static libraries.
        module_interfaces: List of files referencing Swift module interface files.
        target_dir: Path referencing directory of the current target.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.

    Returns:
        List of generated XCFramework files.
    """
    bundle_name = label.name + ".xcframework"
    xcframework_directory = paths.join(target_dir, bundle_name)
    intermediates_directory = paths.join(label.package, "%s-intermediates" % label.name)

    if (frameworks and libraries) or (not frameworks and not libraries):
        fail("Can only generate XCFrameworks using static libraries or dynamic frameworks.")

    info_plist = actions.declare_file(paths.join(bundle_name, "Info.plist"))
    outputs = [info_plist]

    args = []
    inputs = []
    args.extend(["rm", "-rf", xcframework_directory, ";"])
    args.extend(["/usr/bin/xcodebuild", "-create-xcframework"])

    if libraries:
        inputs.extend(libraries)
        for library in libraries:
            library_relative_path = paths.relativize(library.short_path, intermediates_directory)
            outputs.append(actions.declare_file(library_relative_path, sibling = info_plist))
            args.extend(["-library", library.path])

            if headers:
                args.extend(["-headers", paths.join(library.dirname, "Headers")])

    for header in headers:
        inputs.append(header)
        outputs.append(actions.declare_file(
            paths.relativize(header.short_path, intermediates_directory),
            sibling = info_plist,
        ))

    for framework_path, framework_files in frameworks.items():
        inputs.extend(framework_files)
        outputs.extend([
            actions.declare_file(
                paths.relativize(f.short_path, intermediates_directory),
                sibling = info_plist,
            )
            for f in framework_files
        ])
        args.extend(["-framework", framework_path])

    for module_interface in module_interfaces:
        inputs.append(module_interface)

        # xcodebuild removes swiftmodule files for XCFrameworks.
        # This filters out these files to avoid Bazel errors due
        # no action generating these files.
        if module_interface.extension == "swiftmodule":
            continue
        outputs.append(actions.declare_file(
            paths.relativize(module_interface.short_path, intermediates_directory),
            sibling = info_plist,
        ))

    args.extend(["-output", xcframework_directory])

    apple_support.run_shell(
        actions = actions,
        apple_fragment = apple_fragment,
        command = " ".join(args),
        inputs = depset(inputs),
        mnemonic = "GenerateXCFrameworkXcodebuild",
        outputs = outputs,
        progress_message = "Generating XCFramework using xcodebuild",
        xcode_config = xcode_config,
    )

    return outputs

def _generate_static_library_xcframework_files(
        *,
        actions,
        apple_fragment,
        generate_modulemap,
        hdrs,
        include_module_interface_files,
        label,
        minimum_os_versions,
        platforms,
        srcs,
        swift_library,
        target_dir,
        xcode_config):
    """Generate a set of XCFramework files appropriate for a Static Library XCFramework.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        generate_modulemap: Boolean. Indicates if the target should generate a Clang modulemap.
        hdrs: A list of files referencing headers.
        include_module_interface_files: Boolean. Indicates if the target should generate Swift
            module interface files.
        label: Label of the target being built.
        minimum_os_versions: The ctx.minimum_os_versions attribute from the rule.
        platforms: The ctx.platforms attribute from the rule.
        srcs: A list of files referencing source code.
        swift_library: A list, which if not empty will contain files from a swift_library target.
        target_dir: Path referencing directory of the current target.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.

    Returns:
        List of generated XCFramework files.
    """
    if not swift_library and platforms.keys() != minimum_os_versions.keys():
        fail("Attributes: 'platforms' and 'minimum_os_versions' must define the same keys")

    if swift_library and len(platforms) > 1:
        fail("Providing a pre-compiled static library is only allowed for a single platform.")

    if swift_library and minimum_os_versions:
        fail("""
Attributes `minimum_os_versions` and `swift_library` can't be set simultaneously.
 - Use `minimum_os_versions` when using Objective-C sources for XCFrameworks.
 - Use `swift_library` when sourcing a previously compiled Swift library.""")

    headers = []
    libraries = []
    module_interfaces = []
    modulemaps = []
    umbrella_header = None
    for platform in platforms:
        architectures = platforms[platform]
        library_identifier = _platform_to_library_identifier(
            platform = platform,
            architectures = architectures,
        )

        library_path = library_identifier
        headers_path = paths.join(library_path, "Headers", label.name)

        if not swift_library:
            # Compile library
            minimum_os_version = minimum_os_versions[platform]
            binary = generation_support.compile_binary(
                actions = actions,
                apple_fragment = apple_fragment,
                archs = architectures,
                label = label,
                minimum_os_version = minimum_os_version,
                sdk = _sdk_for_platform(platform),
                srcs = srcs,
                hdrs = hdrs,
                xcode_config = xcode_config,
            )

            # Create static library
            static_library = generation_support.create_static_library(
                actions = actions,
                apple_fragment = apple_fragment,
                binary = binary,
                label = label,
                parent_dir = library_identifier,
                xcode_config = xcode_config,
            )

            # Copy headers and generate umbrella header
            headers.extend([
                generation_support.copy_file(
                    actions = actions,
                    base_path = headers_path,
                    file = header,
                    label = label,
                )
                for header in hdrs
            ])

            umbrella_header = generation_support.generate_umbrella_header(
                actions = actions,
                bundle_name = label.name,
                headers = hdrs,
                headers_path = headers_path,
                label = label,
            )
            headers.append(umbrella_header)
        else:
            # Copy static library to intermediate directory
            static_library = generation_support.copy_file(
                actions = actions,
                base_path = library_path,
                file = generation_support.get_file_with_extension(
                    files = swift_library,
                    extension = "a",
                ),
                label = label,
                target_filename = label.name + ".a",
            )

            # Copy Swift module files to intermediate directory
            if include_module_interface_files:
                swiftmodule_path = paths.join(library_path, label.name + ".swiftmodule")
                module_interfaces = [
                    generation_support.copy_file(
                        actions = actions,
                        base_path = swiftmodule_path,
                        file = interface_file,
                        label = label,
                        target_filename = "{architecture}.{extension}".format(
                            architecture = architectures[0],
                            extension = interface_file.extension,
                        ),
                    )
                    for interface_file in swift_library
                    if interface_file.extension.startswith("swift")
                ]

            # Copy swiftc generated headers to intermediate directory
            headers.append(
                generation_support.copy_file(
                    actions = actions,
                    base_path = headers_path,
                    label = label,
                    file = generation_support.get_file_with_extension(
                        files = swift_library,
                        extension = "h",
                    ),
                    target_filename = label.name + ".h",
                ),
            )

        # Generate Clang modulemap under Headers directory.
        if generate_modulemap:
            modulemaps.append(
                generation_support.generate_module_map(
                    actions = actions,
                    bundle_name = label.name,
                    headers = headers,
                    label = label,
                    module_map_path = headers_path,
                    umbrella_header = umbrella_header,
                ),
            )

        libraries.append(static_library)

    # Create static library XCFramework
    xcframework_files = _create_xcframework(
        actions = actions,
        apple_fragment = apple_fragment,
        headers = headers + modulemaps,
        label = label,
        libraries = libraries,
        module_interfaces = module_interfaces,
        target_dir = target_dir,
        xcode_config = xcode_config,
    )

    return xcframework_files

def _generate_framework_xcframework_files(
        *,
        actions,
        apple_fragment,
        hdrs,
        include_framework_root_infoplists,
        include_resource_bundles,
        include_versioned_frameworks,
        kind,
        label,
        minimum_os_versions,
        platforms,
        srcs,
        target_dir,
        xcode_config):
    """Generate a set of XCFramework files appropriate for Framework XCFrameworks.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        hdrs: A list of files referencing headers.
        include_framework_root_infoplists: Boolean. Indicates if all bundled frameworks should
            include a root infoplist.
        include_resource_bundles: Boolean. Indicates if all bundled frameworks should include a
            resource bundle with an Info.plist.
        include_versioned_frameworks: Boolean. Indicates if the framework should include additional
            "versions" of the framework under the Versions directory on macOS. No-op otherwise.
        kind: String. Indicates whether the framework is "static" or "dynamic", based on the given
            string.
        label: Label of the target being built.
        minimum_os_versions: The ctx.minimum_os_versions attribute from the rule.
        platforms: The ctx.platforms attribute from the rule.
        srcs: A list of files referencing source code.
        target_dir: Path referencing directory of the current target.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.

    Returns:
        List of generated XCFramework files.
    """
    if platforms.keys() != minimum_os_versions.keys():
        fail("Attributes: 'platforms' and 'minimum_os_versions' must define the same keys")

    frameworks = {}
    for platform in platforms:
        sdk = _sdk_for_platform(platform)
        architectures = platforms[platform]
        minimum_os_version = minimum_os_versions[platform]
        library_identifier = _platform_to_library_identifier(
            platform = platform,
            architectures = architectures,
        )

        # Compile library
        binary = generation_support.compile_binary(
            actions = actions,
            apple_fragment = apple_fragment,
            archs = architectures,
            hdrs = hdrs,
            label = label,
            minimum_os_version = minimum_os_version,
            sdk = sdk,
            srcs = srcs,
            xcode_config = xcode_config,
        )

        # Create dynamic library
        library_file = None
        if kind == "dynamic":
            library_file = generation_support.create_dynamic_library(
                actions = actions,
                apple_fragment = apple_fragment,
                archs = architectures,
                binary = binary,
                label = label,
                minimum_os_version = minimum_os_version,
                sdk = sdk,
                xcode_config = xcode_config,
            )
        elif kind == "static":
            library_file = generation_support.create_static_library(
                actions = actions,
                apple_fragment = apple_fragment,
                binary = binary,
                label = label,
                parent_dir = library_identifier,
                xcode_config = xcode_config,
            )
        else:
            fail("""
Internal Error: Received undefined kind of {}, expected either static or dynamic.
            """.format(kind))

        # Create framework bundle
        framework_files = generation_support.create_framework(
            actions = actions,
            apple_fragment = apple_fragment,
            base_path = library_identifier,
            bundle_name = label.name,
            headers = hdrs,
            include_resource_bundle = include_resource_bundles,
            include_root_infoplist = include_framework_root_infoplists,
            include_versioned_frameworks = include_versioned_frameworks and platform == "macos",
            kind = kind,
            label = label,
            library = library_file,
            target_os = platform,
            xcode_config = xcode_config,
        )

        framework_path = paths.join(
            binary.dirname,
            library_identifier,
            label.name + ".framework",
        )
        frameworks[framework_path] = framework_files

    # Create xcframework bundle
    xcframework_files = _create_xcframework(
        actions = actions,
        apple_fragment = apple_fragment,
        frameworks = frameworks,
        label = label,
        target_dir = target_dir,
        xcode_config = xcode_config,
    )

    return xcframework_files

def _generate_dynamic_xcframework_impl(ctx):
    """Implementation of generate_dynamic_xcframework."""
    actions = ctx.actions
    apple_fragment = ctx.fragments.apple
    label = ctx.label
    target_dir = paths.join(ctx.bin_dir.path, label.package)
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    srcs = ctx.files.srcs
    hdrs = ctx.files.hdrs
    platforms = ctx.attr.platforms
    minimum_os_versions = ctx.attr.minimum_os_versions
    include_resource_bundles = ctx.attr.include_resource_bundles
    include_versioned_frameworks = ctx.attr.include_versioned_frameworks

    xcframework_files = _generate_framework_xcframework_files(
        actions = actions,
        apple_fragment = apple_fragment,
        hdrs = hdrs,
        include_framework_root_infoplists = True,
        include_resource_bundles = include_resource_bundles,
        include_versioned_frameworks = include_versioned_frameworks,
        kind = "dynamic",
        label = label,
        minimum_os_versions = minimum_os_versions,
        platforms = platforms,
        srcs = srcs,
        target_dir = target_dir,
        xcode_config = xcode_config,
    )

    return [
        DefaultInfo(
            files = depset(xcframework_files),
        ),
    ]

def _generate_static_xcframework_impl(ctx):
    """Implementation of generate_static_xcframework."""
    actions = ctx.actions
    apple_fragment = ctx.fragments.apple
    bundle_format = ctx.attr.bundle_format
    label = ctx.label
    target_dir = paths.join(ctx.bin_dir.path, label.package)
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    srcs = ctx.files.srcs
    hdrs = ctx.files.hdrs
    swift_library = ctx.files.swift_library
    include_framework_root_infoplists = ctx.attr.include_framework_root_infoplists
    include_module_interface_files = ctx.attr.include_module_interface_files
    include_resource_bundles = ctx.attr.include_resource_bundles
    include_versioned_frameworks = ctx.attr.include_versioned_frameworks

    platforms = ctx.attr.platforms
    minimum_os_versions = ctx.attr.minimum_os_versions
    generate_modulemap = ctx.attr.generate_modulemap

    xcframework_files = []
    if bundle_format == "library":
        xcframework_files = _generate_static_library_xcframework_files(
            actions = actions,
            apple_fragment = apple_fragment,
            generate_modulemap = generate_modulemap,
            hdrs = hdrs,
            include_module_interface_files = include_module_interface_files,
            label = label,
            minimum_os_versions = minimum_os_versions,
            platforms = platforms,
            srcs = srcs,
            swift_library = swift_library,
            target_dir = target_dir,
            xcode_config = xcode_config,
        )
    else:
        if swift_library:
            fail("""
Error: The `swift_library` attribute is not yet supported for the generate_static_xcframework \
test-scoped rule for Static Framework XCFrameworks.""")
        if not include_module_interface_files:
            fail("""
Error: The `include_module_interface_files` attribute is not yet supported for the \
generate_static_xcframework test-scoped rule for Static Framework XCFrameworks.""")
        if not generate_modulemap:
            fail("""
Error: The `generate_modulemap` attribute is not yet supported for the \
generate_static_xcframework test-scoped rule for Static Framework XCFrameworks.""")
        xcframework_files = _generate_framework_xcframework_files(
            actions = actions,
            apple_fragment = apple_fragment,
            hdrs = hdrs,
            include_framework_root_infoplists = include_framework_root_infoplists,
            include_resource_bundles = include_resource_bundles,
            include_versioned_frameworks = include_versioned_frameworks,
            kind = "static",
            label = label,
            minimum_os_versions = minimum_os_versions,
            platforms = platforms,
            srcs = srcs,
            target_dir = target_dir,
            xcode_config = xcode_config,
        )

    return [
        DefaultInfo(
            files = depset(xcframework_files),
        ),
    ]

generate_dynamic_xcframework = rule(
    doc = "Generates XCFramework with dynamic frameworks using Xcode build utilities.",
    implementation = _generate_dynamic_xcframework_impl,
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        {
            "srcs": attr.label_list(
                doc = "List of source files for compiling Objective-C(++) / Swift binaries.",
                mandatory = True,
                allow_files = True,
            ),
            "hdrs": attr.label_list(
                doc = "Header files for generated XCFrameworks.",
                mandatory = False,
                allow_files = True,
            ),
            "platforms": attr.string_list_dict(
                doc = """
A dictionary of strings indicating which platform variants should be built (with the following
format: <platform>[_<environment>]) as keys, and arrays of strings listing which architectures
should be built for those platform variants as their values.

    platforms = {
        "ios_simulator": [
            "x86_64",
            "arm64",
        ],
        "ios": ["arm64"],
        "watchos_simulator": ["x86_64"],
    },
""",
                mandatory = True,
            ),
            "minimum_os_versions": attr.string_dict(
                doc = """
A dictionary of strings indicating the minimum OS version supported by each platform variant
represented as a dotted version number as values.

    minimum_os_versions = {
        "ios_simulator": "12.0",
        "ios": "12.0",
        "watchos_simulator": "4.0",
    },
""",
                mandatory = True,
            ),
            "generate_modulemap": attr.bool(
                doc = """Flag to indicate if modulemap generation is enabled.""",
                mandatory = False,
                default = True,
            ),
            "include_resource_bundles": attr.bool(
                mandatory = False,
                default = False,
                doc = """
Boolean to indicate if the generate framework should include a resource bundle containing an
Info.plist file to test resource propagation.
""",
            ),
            "include_versioned_frameworks": attr.bool(
                default = True,
                doc = """
Flag to indicate if the framework should include additional versions of the framework under the
Versions directory. This is only supported for macOS platform.
                """,
            ),
        },
    ),
    fragments = ["apple"],
)

generate_static_xcframework = rule(
    doc = "Generates XCFramework with a static library using Xcode build utilities.",
    implementation = _generate_static_xcframework_impl,
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        {
            "bundle_format": attr.string(
                default = "library",
                doc = """
The type of the embedded artifacts that this target should build. Options are:

*   `framework`: Embeds static frameworks with resources within the XCFramework bundle. In Xcode
    15.3, these resources will *only* be bundled within the target if the XCFramework bundle is
    embedded with the "Embed & Sign" option, instead of the default "Do Not Sign" option.
*   `library` (default): Embeds static libraries within the XCFramework bundle with the necessary
    supporting code interfaces like header files and swift interfaces. Any resources related to the
    given XCFramework are expected to be distributed separately in an unprocessed form, such as in a
    resource bundle generated by a library target in a Swift Package Manager definition referencing
    this static library XCFramework.
""",
                values = ["framework", "library"],
            ),
            "srcs": attr.label_list(
                doc = "List of source files for compiling Objective-C(++) / Swift binaries.",
                mandatory = False,
                allow_files = True,
            ),
            "hdrs": attr.label_list(
                doc = "Header files for generated XCFrameworks.",
                mandatory = False,
                allow_files = True,
            ),
            "platforms": attr.string_list_dict(
                doc = """
A dictionary of strings indicating which platform variants should be built (with the following
format: <platform>[_<environment>]) as keys, and arrays of strings listing which architectures
should be built for those platform variants as their values.

    platforms = {
        "ios_simulator": [
            "x86_64",
            "arm64",
        ],
        "ios": ["arm64"],
        "watchos_simulator": ["x86_64"],
    },
""",
                mandatory = True,
            ),
            "minimum_os_versions": attr.string_dict(
                doc = """
A dictionary of strings indicating the minimum OS version supported by each platform variant
represented as a dotted version number as values.

    minimum_os_versions = {
        "ios_simulator": "12.0",
        "ios": "12.0",
        "watchos_simulator": "4.0",
    },
""",
                mandatory = False,
            ),
            "generate_modulemap": attr.bool(
                doc = "Flag to indicate if modulemap generation is enabled.",
                mandatory = False,
                default = True,
            ),
            "swift_library": attr.label(
                allow_files = True,
                mandatory = False,
                providers = [SwiftInfo],
                doc = """
Label referencing a `swift_library` target to source static library and module to use for the
generated XCFramework bundle. Target platform and architecture must match with the `platforms`
attribute. This means that if you're building using `bazel build --config=ios_x86_64`, then the
`platforms` attribute must define the following dictionary: {"ios_simulator": ["x86_64"]}.
""",
            ),
            "include_framework_root_infoplists": attr.bool(
                default = True,
                doc = """
Flag to indicate if all bundled frameworks should include a root infoplist. True by default. This
has no effect when the `bundle_format` is set to `library`.
""",
            ),
            "include_module_interface_files": attr.bool(
                default = True,
                doc = """
Flag to indicate if the Swift module interface files (i.e. `.swiftmodule` directory) from the
`swift_library` target should be included in the XCFramework bundle or discarded for testing
purposes.
""",
            ),
            "include_resource_bundles": attr.bool(
                mandatory = False,
                default = False,
                doc = """
Boolean to indicate if the generate framework should include a resource bundle containing an
Info.plist file to test resource propagation. This has no effect when the `bundle_format` is set to
`library`.
""",
            ),
            "include_versioned_frameworks": attr.bool(
                default = True,
                doc = """
Flag to indicate if the framework should include additional versions of the framework under the
Versions directory. This is only supported for macOS platform, and only affects Static Framework
XCFramework outputs.
                """,
            ),
        },
    ),
    fragments = ["apple"],
)
