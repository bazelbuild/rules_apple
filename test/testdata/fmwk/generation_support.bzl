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

"""Apple Frameworks and XCFramework generation support methods for testing."""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load("@bazel_skylib//lib:paths.bzl", "paths")

_SDK_TO_VERSION_ARG = {
    "iphonesimulator": "-mios-simulator-version-min",
    "iphoneos": "-miphoneos-version-min",
    "macosx": "-mmacos-version-min",
    "appletvsimulator": "-mtvos-simulator-version-min",
    "appletvos": "-mtvos-version-min",
    "watchsimulator": "-mwatchos-simulator-version-min",
    "watchos": "-mwatchos-version-min",
}

_FRAMEWORK_PLIST_TEMPLATE = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>{0}</string>
  <key>CFBundleIdentifier</key>
  <string>org.bazel.{0}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>{0}</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
</dict>
</plist>
"""

def _min_version_arg_for_sdk(sdk, minimum_os_version):
    """Returns the clang minimum version argument for a given SDK as a string.

    Args:
        sdk: A string representing an Apple SDK.
        minimum_os_version: Dotted version string for minimum OS version supported by the target.
    Returns:
        A string representing a clang arg for minimum os version of a given Apple SDK.
    """
    return "{0}={1}".format(_SDK_TO_VERSION_ARG[sdk], minimum_os_version)

def _compile_binary(
        *,
        actions,
        apple_fragment,
        archs,
        embed_bitcode = False,
        embed_debug_info = False,
        hdrs,
        label,
        minimum_os_version,
        sdk,
        srcs,
        xcode_config):
    """Compiles binary for a given Apple platform and architectures using Clang.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        archs: List of architectures to compile (e.g. ['arm64', 'x86_64']).
        embed_bitcode: Whether to include bitcode in the binary.
        embed_debug_info: Whether to include debug info in the binary.
        hdrs: List of headers files to compile.
        label: Label of the target being built.
        minimum_os_version: Dotted version string for minimum OS version supported by the target.
        sdk: A string representing an Apple SDK.
        srcs: List of source files to compile.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.
    Returns:
        A compiled binary file.
    """
    binary_name = "{label}.o".format(label = label.name)
    binary_dir = "{sdk}_{archs}".format(sdk = sdk, archs = "_".join(archs))
    binary = actions.declare_file(paths.join("intermediates", binary_dir, binary_name))

    inputs = []
    inputs.extend(srcs)
    inputs.extend(hdrs)

    args = ["/usr/bin/xcrun"]
    args.extend(["-sdk", sdk])
    args.append("clang")
    args.append(_min_version_arg_for_sdk(sdk, minimum_os_version))

    if embed_bitcode:
        args.append("-fembed-bitcode")

    if embed_debug_info:
        args.append("-g")

    for arch in archs:
        args.extend(["-arch", arch])

    for src in srcs:
        args.extend(["-c", src.path])

    args.extend(["-o", binary.path])

    apple_support.run_shell(
        actions = actions,
        apple_fragment = apple_fragment,
        command = " ".join(args),
        inputs = inputs,
        mnemonic = "XcodeToolingClangCompile",
        outputs = [binary],
        progress_message = "Compiling library to Mach-O using clang",
        xcode_config = xcode_config,
        use_default_shell_env = True,
    )

    return binary

def _create_static_library(*, actions, apple_fragment, parent_dir = "", binary, xcode_config):
    """Creates an Apple static library using libtool.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        binary: A binary file to use for the archive file.
        parent_dir: Optional parent directory name for the generated archive file.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.
    Returns:
        A static library (archive) file.
    """
    static_library_name = paths.replace_extension(binary.basename, ".a")
    static_library_path = paths.join("intermediates", parent_dir, static_library_name)
    static_library = actions.declare_file(static_library_path)

    args = ["/usr/bin/xcrun", "libtool", "-static", binary.path, "-o", static_library.path]

    apple_support.run_shell(
        actions = actions,
        apple_fragment = apple_fragment,
        command = " ".join(args),
        inputs = depset([binary]),
        mnemonic = "XcodeToolingLibtool",
        outputs = [static_library],
        progress_message = "Creating static library using libtool",
        xcode_config = xcode_config,
    )

    return static_library

def _create_dynamic_library(
        *,
        actions,
        apple_fragment,
        archs,
        binary,
        minimum_os_version,
        sdk,
        xcode_config):
    """Creates an Apple dynamic library using Clang for Objective-C(++) sources.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        archs: List of architectures to compile (e.g. ['arm64', 'x86_64']).
        binary: A binary file to use for the archive file.
        minimum_os_version: Dotted version string for minimum OS version supported by the target.
        sdk: A string representing an Apple SDK.
        xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.
    Returns:
        A dynamic library file.
    """
    dylib_name, _ = binary.basename.split(".")
    dylib_dir = "{sdk}_{archs}".format(sdk = sdk, archs = "_".join(archs))
    dylib_path = paths.join("intermediates", dylib_dir, dylib_name)
    dylib_binary = actions.declare_file(dylib_path)

    args = ["/usr/bin/xcrun"]
    args.extend(["-sdk", sdk])
    args.append("clang")
    args.append("-fobjc-link-runtime")
    args.append(_min_version_arg_for_sdk(sdk, minimum_os_version))
    args.append("-dynamiclib")
    args.extend([
        "-install_name",
        "@rpath/{}.framework/{}".format(dylib_name, dylib_name),
    ])

    for arch in archs:
        args.extend(["-arch", arch])

    args.append(binary.path)
    args.extend(["-o", dylib_binary.path])

    apple_support.run_shell(
        actions = actions,
        apple_fragment = apple_fragment,
        command = " ".join(args),
        inputs = depset([binary]),
        mnemonic = "XcodeToolingClangDylib",
        outputs = [dylib_binary],
        progress_message = "Creating dynamic library using clang",
        xcode_config = xcode_config,
    )

    return dylib_binary

def _create_framework(
        *,
        actions,
        base_path = "",
        bundle_name,
        library,
        headers,
        include_resource_bundle = False,
        module_interfaces = []):
    """Creates an Apple platform framework bundle.

    Args:
        actions: The actions provider from `ctx.actions`.
        base_path: Base path for the generated archive file (optional).
        bundle_name: Name of the Framework bundle.
        library: The library for the Framework bundle.
        headers: List of header files for the Framework bundle.
        include_resource_bundle: Boolean to indicate if a resource bundle should be added to
            the framework bundle (optional).
        module_interfaces: List of Swift module interface files for the framework bundle (optional).
    Returns:
        List of files for a .framework bundle.
    """
    framework_files = []
    framework_directory = paths.join(base_path, bundle_name + ".framework")

    framework_binary = actions.declare_file(paths.join(framework_directory, bundle_name))
    actions.symlink(
        output = framework_binary,
        target_file = library,
    )

    framework_plist = actions.declare_file(paths.join(framework_directory, "Info.plist"))
    actions.write(
        output = framework_plist,
        content = _FRAMEWORK_PLIST_TEMPLATE.format(bundle_name),
    )

    framework_files.extend([framework_binary, framework_plist])

    if headers:
        headers_path = paths.join(framework_directory, "Headers")
        framework_files.extend([
            _copy_file(
                actions = actions,
                file = header,
                base_path = headers_path,
            )
            for header in headers
        ])
        umbrella_header = _generate_umbrella_header(
            actions = actions,
            bundle_name = bundle_name,
            headers = headers,
            headers_path = headers_path,
            is_framework_umbrella_header = True,
        )
        framework_files.append(umbrella_header)

        module_map_path = paths.join(framework_directory, "Modules")
        framework_files.append(
            _generate_module_map(
                actions = actions,
                bundle_name = bundle_name,
                is_framework_module = True,
                module_map_path = module_map_path,
                umbrella_header = umbrella_header,
            ),
        )

    if module_interfaces:
        modules_path = paths.join(framework_directory, "Modules", bundle_name + ".swiftmodule")
        framework_files.extend([
            _copy_file(
                actions = actions,
                file = interface_file,
                base_path = modules_path,
            )
            for interface_file in module_interfaces
        ])

    if include_resource_bundle:
        resources_path = paths.join(framework_directory, "Resources", bundle_name + ".bundle")
        resource_file = actions.declare_file(paths.join(resources_path, "Info.plist"))
        actions.write(output = resource_file, content = "Mock resource bundle")
        framework_files.append(resource_file)

    return framework_files

def _copy_file(*, actions, base_path, file, target_filename = None):
    """Copies file to a target directory.

    Args:
        actions: The actions provider from `ctx.actions`.
        base_path: Base path for the copied files.
        file: File to copy.
        target_filename: (optional) String for target filename. If None, file basename is used.
    Returns:
        List of copied files.
    """
    filename = target_filename if target_filename else file.basename
    copied_file_path = paths.join(base_path, filename)
    copied_file = actions.declare_file(copied_file_path)
    actions.symlink(output = copied_file, target_file = file)
    return copied_file

def _get_file_with_extension(*, extension, files):
    """Traverse a given file list and return file matching given extension.

    Args:
        extension: File extension to match.
        files: List of files to traverse.
    Returns:
        File matching extension, None otherwise.
    """
    for file in files:
        if file.extension == extension:
            return file
    return None

def _generate_umbrella_header(
        *,
        actions,
        bundle_name,
        headers,
        headers_path,
        is_framework_umbrella_header = False):
    """Generates a single umbrella header given a sequence of header files.

    Args:
        actions: The actions provider from `ctx.actions`.
        bundle_name: Name of the Framework/XCFramework bundle.
        headers: List of header files for the Framework bundle.
        headers_path: Base path for the generated umbrella header file.
        is_framework_umbrella_header: Boolean to indicate if the generated umbrella header is for an
          Apple framework. Defaults to `False`.
    Returns:
        File for the generated umbrella header.
    """
    header_text = "#import <Foundation/Foundation.h>\n"

    header_prefix = bundle_name if is_framework_umbrella_header else ""
    for header in headers:
        header_text += "#import <{}>\n".format(paths.join(header_prefix, header.basename))

    umbrella_header = actions.declare_file(
        paths.join(headers_path, bundle_name + ".h"),
    )
    actions.write(
        output = umbrella_header,
        content = header_text,
    )

    return umbrella_header

def _generate_module_map(
        *,
        actions,
        bundle_name,
        headers = None,
        is_framework_module = False,
        module_map_path,
        umbrella_header = None):
    """Generates a single module map given a sequence of header files.

    Args:
        actions: The actions provider from `ctx.actions`.
        bundle_name: Name of the Framework/XCFramework bundle.
        headers: List of header files to use for the generated modulemap file.
        is_framework_module: Boolean to indicate if the generated modulemap is for a framework.
          Defaults to `False`.
        module_map_path: Base path for the generated modulemap file.
        umbrella_header: Umbrella header file to use for generated modulemap file.
    Returns:
        File for the generated modulemap file.
    """
    modulemap_content = actions.args()
    modulemap_content.set_param_file_format("multiline")

    if is_framework_module:
        modulemap_content.add("framework module %s {" % bundle_name)
    else:
        modulemap_content.add("module %s {" % bundle_name)

    if umbrella_header:
        modulemap_content.add("umbrella header \"%s\"" % umbrella_header.basename)
        modulemap_content.add("export *")
        modulemap_content.add("module * { export * }")
    elif headers:
        for header in headers:
            modulemap_content.add("header \"%s\"" % header.basename)
        modulemap_content.add("requires objc")

    modulemap_content.add("}")

    modulemap_file = actions.declare_file(paths.join(module_map_path, "module.modulemap"))
    actions.write(output = modulemap_file, content = modulemap_content)

    return modulemap_file

generation_support = struct(
    compile_binary = _compile_binary,
    copy_file = _copy_file,
    create_dynamic_library = _create_dynamic_library,
    create_framework = _create_framework,
    create_static_library = _create_static_library,
    get_file_with_extension = _get_file_with_extension,
    generate_module_map = _generate_module_map,
    generate_umbrella_header = _generate_umbrella_header,
)
