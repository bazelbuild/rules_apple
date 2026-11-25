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

"""Support methods for handling artifacts from SwiftInfo providers."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _verify_found_module_name(*, bundle_name, found_module_name):
    """Validate that the module name fits the requirements for Swift frameworks.

    Args:
        bundle_name: The bundle name for this Swift framework.
        found_module_name: The module name that was found from a SwiftInfo provider.
    """
    if bundle_name != found_module_name:
        fail("""
error: Found swift_library with module name {actual} but expected {expected}. Swift static \
frameworks expect a single swift_library dependency with `module_name` set to the same \
`bundle_name` as the static framework target.\
""".format(
            actual = found_module_name,
            expected = bundle_name,
        ))

def _modules_from_avoid_deps(*, avoid_swift_infos):
    """Returns a Starlark set of module names found from the given SwiftInfo providers."""
    avoid_modules = set()
    for swiftinfo in avoid_swift_infos:
        for module in swiftinfo.transitive_modules.to_list():
            if module.swift and not module.is_system:
                avoid_modules.add(module.name)
    return avoid_modules

def _swift_include_info(
        *,
        avoid_modules = set(),
        found_module_name,
        transitive_modules):
    """Returns the module containing the Swift interface information from a SwiftInfo provider.

    Args:
        avoid_modules: A Starlark set of modules to avoid, if specified.
        found_module_name: The module name that was previously found from transitive deps.
        transitive_modules: The transitive_modules field of a SwiftInfo provider.

    Returns:
        The module found from `transitive_modules` that has the necessary swift interfaces.
    """
    swift_module = None
    transitive_modules_list = transitive_modules.to_list()

    for module in transitive_modules_list:
        if not module.swift or module.is_system or module.name in avoid_modules:
            continue

        if swift_module or (found_module_name and module.name != found_module_name):
            fail(
                """\
Error: Swift third party frameworks expect a single swift_library dependency with \
library_evolution = True and no transitive swift_library dependencies.\
""",
            )

        if not all([module.name, module.swift.swiftdoc, module.swift.swiftinterface]):
            fail(
                """\
Error: Could not find all required artifacts and information to build a Swift framework. \
Please make sure you have a single swift_library dependency with library_evolution = True.

For the Swift module found for this framework:
- Swift module name was "{module_name}"
- Generated swiftdoc file was "{swiftdoc}"
- Generated swiftinterface file was "{swiftinterface}"

If this is not a module that you expect to see in your distribution (i.e., it is not your \
framework's module or one of its public dependencies), you may be leaking a private dependency \
unintentionally. Consider putting that module (or the one that depends on it, if it is a \
transitive dependency) in the 'private_deps' of your 'swift_library' and use '@_implementationOnly \
import' to import it.\
""".format(
                    module_name = module.name or "<not found>",
                    swiftdoc = module.swift.swiftdoc or "<not found>",
                    swiftinterface = module.swift.swiftinterface or "<not found>",
                ),
            )

        swift_module = module

    if not swift_module:
        if not transitive_modules_list:
            fail("""\
Internal Error: Swift third party frameworks require a Swift module to be defined from a \
"swift_library", but could not find any Swift modules from deps. Please file an issue on the Apple \
BUILD rules with a reproducible error case.
""")

        avoid_modules_list = list(avoid_modules) if avoid_modules else None
        if avoid_modules_list:
            fail("""\
Error: Could not find a Swift module to build a Swift framework. This could be because "avoid_deps"\
 is too broadly defined.

Found these Swift modules within "avoid_deps": {avoid_modules_list}

Found these Swift modules within "deps": {transitive_modules_list}
""".format(
                avoid_modules_list = ", ".join(sorted(avoid_modules_list)),
                transitive_modules_list = ", ".join(sorted([
                    module.name
                    for module in transitive_modules_list
                ])),
            ))

        fail("""\
Internal Error: Could not find any Swift modules from deps, even though information for transitive \
modules from a Swift library dependency was found in deps. Please file an issue on the Apple BUILD \
rules with a reproducible error case.
""")

    return swift_module

def _declare_generated_header(
        *,
        actions,
        generated_header,
        is_clang_submodule,
        label_name,
        module_name,
        output_discriminator):
    """Declares the generated header file for this Swift framework.

    Args:
        actions: The actions provider from `ctx.actions`.
        generated_header: A File referencing the generated header from a SwiftInfo provider.
        is_clang_submodule: Delcares if this header will be referenced as a Clang submodule, rather
            than as the Clang module itself. This changes the header to be suffixed with "-Swift.h".
        label_name: Name of the target being built.
        module_name: The name of the Swift module.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.

    Returns:
        A File referencing the intermediate generated header.
    """

    bundle_header_filename = "{}.h".format(
        module_name + "-Swift" if is_clang_submodule else module_name,
    )
    bundle_header = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = bundle_header_filename,
    )
    actions.symlink(
        target_file = generated_header,
        output = bundle_header,
    )
    return bundle_header

def _declare_swiftdoc(
        *,
        actions,
        arch,
        label_name,
        output_discriminator,
        swiftdoc):
    """Declares the swiftdoc for this Swift framework.

    Args:
        actions: The actions provider from `ctx.actions`.
        arch: The cpu architecture that the generated swiftdoc belongs to.
        label_name: Name of the target being built.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        swiftdoc: A File referencing the swiftdoc file from a SwiftInfo provider.

    Returns:
        A File referencing the intermediate swiftdoc.
    """
    bundle_doc = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = "{}.swiftdoc".format(arch),
    )
    actions.symlink(
        target_file = swiftdoc,
        output = bundle_doc,
    )
    return bundle_doc

def _declare_swiftinterface(
        *,
        actions,
        arch,
        label_name,
        output_discriminator,
        swiftinterface):
    """Declares the swiftinterface for this Swift framework.

    Args:
        actions: The actions provider from `ctx.actions`.
        arch: The cpu architecture that the generated swiftdoc belongs to.
        label_name: Name of the target being built.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        swiftinterface: A File referencing the swiftinterface file from a SwiftInfo provider.

    Returns:
        A File referencing the intermediate swiftinterface.
    """
    bundle_interface = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = "{}.swiftinterface".format(arch),
    )
    actions.symlink(
        target_file = swiftinterface,
        output = bundle_interface,
    )
    return bundle_interface

def _declare_package_swiftinterface(
        *,
        actions,
        arch,
        bundle_name,
        framework_modulemap,
        label_name,
        output_discriminator,
        package_swiftinterface):
    """Declares the package swiftinterface for this Swift framework.

    The file is declared under a path matching the XCFramework or framework
    module layout (`[<output_discriminator>/]<bundle_name>.framework/Modules/<bundle_name>.swiftmodule/<arch>.package.swiftinterface`
    or `<output_discriminator>/<bundle_name>.swiftmodule/<arch>.package.swiftinterface`)
    so that framework and XCFramework import rules can classify and select the
    slice and architecture when the `package_swiftinterfaces` output group is
    included in `xcframework_imports` or `framework_imports`.

    Args:
        actions: The actions provider from `ctx.actions`.
        arch: The cpu architecture that the generated package swiftinterface
            belongs to.
        bundle_name: The bundle name of the framework.
        framework_modulemap: Boolean indicating whether the target produces a
            `.framework` bundle (`True`) or a static library slice (`False`).
        label_name: Name of the target being built.
        output_discriminator: A string to differentiate between different target
            intermediate files (such as the XCFramework library identifier) or
            `None`.
        package_swiftinterface: A File referencing the `.package.swiftinterface`
            file from a `SwiftInfo` provider.

    Returns:
        A File referencing the intermediate `.package.swiftinterface`.
    """
    swiftmodule_dir = "{}.swiftmodule".format(bundle_name)
    if framework_modulemap:
        module_relative_dir = paths.join(
            "{}.framework".format(bundle_name),
            "Modules",
            swiftmodule_dir,
        )
    else:
        module_relative_dir = swiftmodule_dir

    file_name = paths.join(
        module_relative_dir,
        "{}.package.swiftinterface".format(arch),
    )
    if output_discriminator:
        file_name = paths.join(output_discriminator, file_name)

    bundle_package_interface = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = None,
        file_name = file_name,
    )
    actions.symlink(
        target_file = package_swiftinterface,
        output = bundle_package_interface,
    )
    return bundle_package_interface

swift_info_support = struct(
    verify_found_module_name = _verify_found_module_name,
    modules_from_avoid_deps = _modules_from_avoid_deps,
    swift_include_info = _swift_include_info,
    declare_generated_header = _declare_generated_header,
    declare_package_swiftinterface = _declare_package_swiftinterface,
    declare_swiftdoc = _declare_swiftdoc,
    declare_swiftinterface = _declare_swiftinterface,
)
