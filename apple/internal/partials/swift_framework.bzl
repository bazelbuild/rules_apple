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

"""Partial implementation for Swift frameworks with third party interfaces."""

load(
    "@build_bazel_rules_apple//apple/internal:clang_modulemap_support.bzl",
    "clang_modulemap_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_info_support.bzl",
    "swift_info_support",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

visibility("//apple/...")

def _swift_framework_partial_impl(
        *,
        actions,
        avoid_deps,
        bundle_name,
        framework_modulemap,
        label_name,
        output_discriminator,
        public_hdrs,
        sdk_dylibs,
        sdk_frameworks,
        swift_infos):
    """Implementation for the Swift framework processing partial."""

    if len(swift_infos) == 0:
        fail("""
Internal error: Expected to find a SwiftInfo before entering this partial. Please file an \
issue with a reproducible error case.
""")

    avoid_modules = swift_info_support.modules_from_avoid_deps(avoid_deps = avoid_deps)
    bundle_files = []
    expected_module_name = bundle_name
    found_module_name = None
    found_generated_header = None
    modules_parent = paths.join("Modules", "{}.swiftmodule".format(expected_module_name))

    for arch, swiftinfo in swift_infos.items():
        swift_module = swift_info_support.swift_include_info(
            avoid_modules = avoid_modules,
            found_module_name = found_module_name,
            transitive_modules = swiftinfo.transitive_modules,
        )

        # If headers are generated, they should be generated equally for all archs, so just take the
        # first generated header found.
        if (not found_generated_header) and swift_module.clang:
            if swift_module.clang.compilation_context.direct_headers:
                found_generated_header = swift_module.clang.compilation_context.direct_headers[0]

        found_module_name = swift_module.name

        bundle_interface = swift_info_support.declare_swiftinterface(
            actions = actions,
            arch = arch,
            label_name = label_name,
            output_discriminator = output_discriminator,
            swiftinterface = swift_module.swift.swiftinterface,
        )
        bundle_files.append((processor.location.bundle, modules_parent, depset([bundle_interface])))

        bundle_doc = swift_info_support.declare_swiftdoc(
            actions = actions,
            arch = arch,
            label_name = label_name,
            output_discriminator = output_discriminator,
            swiftdoc = swift_module.swift.swiftdoc,
        )
        bundle_files.append((processor.location.bundle, modules_parent, depset([bundle_doc])))

    swift_info_support.verify_found_module_name(
        bundle_name = expected_module_name,
        found_module_name = found_module_name,
    )

    swift_generated_header = None
    if found_generated_header:
        swift_generated_header = swift_info_support.declare_generated_header(
            actions = actions,
            generated_header = found_generated_header,
            is_clang_submodule = bool(public_hdrs),
            label_name = label_name,
            output_discriminator = output_discriminator,
            module_name = expected_module_name,
        )

    umbrella_header_filename = None
    if public_hdrs:
        umbrella_referenced_headers = list(public_hdrs)
        if swift_generated_header:
            umbrella_referenced_headers.append(swift_generated_header)

        header_files, umbrella_header_filename = clang_modulemap_support.process_headers(
            actions = actions,
            label_name = label_name,
            module_name = expected_module_name,
            output_discriminator = output_discriminator,
            public_hdrs = umbrella_referenced_headers,
        )
        if header_files:
            bundle_files.append(
                (processor.location.bundle, "Headers", depset(header_files)),
            )
    elif swift_generated_header:
        bundle_files.append(
            (processor.location.bundle, "Headers", depset([swift_generated_header])),
        )

    if umbrella_header_filename or public_hdrs or swift_generated_header:
        # Generate the clang module map and arrange headers appropriately.
        modulemap_file = intermediates.file(
            actions = actions,
            target_name = label_name,
            output_discriminator = output_discriminator,
            file_name = "module.modulemap",
        )

        modulemap_content = ""
        if public_hdrs:
            modulemap_content += clang_modulemap_support.modulemap_header_interface_contents(
                framework_modulemap = framework_modulemap,
                module_name = expected_module_name,
                sdk_dylibs = sorted(sdk_dylibs.to_list() if sdk_dylibs else []),
                sdk_frameworks = sorted(sdk_frameworks.to_list() if sdk_frameworks else []),
                umbrella_header_filename = umbrella_header_filename,
            )
            modulemap_content += "\n"
            modulemap_content += clang_modulemap_support.modulemap_swift_contents(
                framework_modulemap = False,
                is_submodule = True,
                module_name = expected_module_name,
            )
        else:
            modulemap_content += clang_modulemap_support.modulemap_swift_contents(
                framework_modulemap = framework_modulemap,
                is_submodule = False,
                module_name = expected_module_name,
            )

        actions.write(
            output = modulemap_file,
            content = modulemap_content,
        )

        bundle_files.append((processor.location.bundle, "Modules", depset([modulemap_file])))

    return struct(bundle_files = bundle_files)

def swift_framework_partial(
        *,
        actions,
        apple_xplat_toolchain_info,
        avoid_deps = [],
        bundle_name,
        framework_modulemap = True,
        label_name,
        output_discriminator = None,
        public_hdrs = [],
        sdk_dylibs = [],
        sdk_frameworks = [],
        swift_infos):
    """Constructor for the Swift framework processing partial.

    This partial collects and bundles the necessary files to construct a Swift based static
    framework.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_xplat_toolchain_info: An AppleXPlatToolsToolchainInfo provider.
        avoid_deps: A list of library targets with modules to avoid, if specified. Optional.
        bundle_name: The name of the output bundle.
        framework_modulemap: Boolean to indicate if the generated modulemap should be for a
            framework instead of a library or a generic module. Defaults to `True`.
        label_name: Name of the target being built.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`. Optional.
        public_hdrs: A list of public headers to present in addition to the generated header. Useful
            for mixed interface Swift and Objective-C SDKs. Optional.
        sdk_dylibs: A list of dynamic libraries referenced by this framework. Only necessary to
            generate static library archive-supporting Clang module maps, as "dynamic" frameworks
            should reference these in load commands. Optional.
        sdk_frameworks: A list of frameworks referenced by this framework. Only necessary to
            generate static library archive-supporting Clang module maps, as "dynamic" frameworks
            should reference these in load commands. Optional.
        swift_infos: A dictionary with architectures as keys and the SwiftInfo provider containing
            the required artifacts for that architecture as values.

    Returns:
        A partial that returns the bundle location of the supporting Swift artifacts needed in a
        Swift based sdk framework.
    """
    enable_wip_features = (
        apple_xplat_toolchain_info.build_settings.enable_wip_features
    )
    return partial.make(
        _swift_framework_partial_impl,
        actions = actions,
        avoid_deps = avoid_deps,
        bundle_name = bundle_name,
        framework_modulemap = framework_modulemap,
        label_name = label_name,
        output_discriminator = output_discriminator,
        public_hdrs = public_hdrs if enable_wip_features else [],
        sdk_dylibs = sdk_dylibs if enable_wip_features else [],
        sdk_frameworks = sdk_frameworks if enable_wip_features else [],
        swift_infos = swift_infos,
    )
