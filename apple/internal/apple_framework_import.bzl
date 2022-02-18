# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Implementation of framework import rules."""

load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:sets.bzl",
    "sets",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
    "SwiftToolchainInfo",
    "SwiftUsageInfo",
    "swift_clang_module_aspect",
    "swift_common",
)

def _is_swiftmodule(path):
    """Predicate to identify Swift modules/interfaces."""
    return path.endswith((".swiftmodule", ".swiftinterface"))

def _swiftmodule_for_cpu(swiftmodule_files, cpu):
    """Select the cpu specific swiftmodule."""

    # The paths will be of the following format:
    #   ABC.framework/Modules/ABC.swiftmodule/<arch>.swiftmodule
    # Where <arch> will be a common arch like x86_64, arm64, etc.
    named_files = {f.basename: f for f in swiftmodule_files}

    module = named_files.get("{}.swiftmodule".format(cpu))
    if not module and cpu == "armv7":
        module = named_files.get("arm.swiftmodule")

    return module

def _classify_framework_imports(config_vars, framework_imports):
    """Classify a list of framework files into bundling, header, or module_map."""

    bundling_imports = []
    header_imports = []
    module_map_imports = []
    for file in framework_imports:
        file_short_path = file.short_path
        if file_short_path.endswith(".h"):
            header_imports.append(file)
            continue
        if file_short_path.endswith(".modulemap"):
            # With the flip of `--incompatible_objc_framework_cleanup`, the
            # `objc_library` implementation in Bazel no longer passes module
            # maps as inputs to the compile actions, so that `@import`
            # statements for user-provided framework no longer work in a
            # sandbox. This trap door allows users to continue using `@import`
            # statements for imported framework by adding module map to
            # header_imports so that they are included in Obj-C compilation but
            # they aren't processed in any way.
            if defines.bool_value(
                config_vars = config_vars,
                define_name = "apple.incompatible.objc_framework_propagate_modulemap",
                default = False,
            ):
                header_imports.append(file)
            module_map_imports.append(file)
            continue
        if "Headers/" in file_short_path:
            # This matches /Headers/ and /PrivateHeaders/
            header_imports.append(file)
            continue
        if _is_swiftmodule(file_short_path):
            # Add Swift's module files to header_imports so that they are correctly included in the build
            # by Bazel but they aren't processed in any way
            header_imports.append(file)
            continue
        if file_short_path.endswith((".swiftdoc", ".swiftsourceinfo")):
            # Ignore swiftdoc files, they don't matter in the build, only for IDEs
            continue
        bundling_imports.append(file)

    return bundling_imports, header_imports, module_map_imports

def _all_framework_binaries(frameworks_groups):
    """Returns a list of Files of all imported binaries."""
    binaries = []
    for framework_dir, framework_imports in frameworks_groups.items():
        binary = _get_framework_binary_file(framework_dir, framework_imports.to_list())
        if binary != None:
            binaries.append(binary)

    return binaries

def _all_dsym_binaries(dsym_imports):
    """Returns a list of Files of all imported dSYM binaries."""
    return [
        file
        for file in dsym_imports
        if file.basename.lower() != "info.plist"
    ]

def _get_framework_binary_file(framework_dir, framework_imports):
    """Returns the File that is the framework's binary."""
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]
    framework_path = paths.join(framework_dir, framework_name)
    for framework_import in framework_imports:
        if framework_import.path == framework_path:
            return framework_import

    return None

def _grouped_framework_files(framework_imports):
    """Returns a dictionary of each framework's imports, grouped by path to the .framework root."""
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "framework_imports",
    )

    # Only check for unique basenames of these keys, since it's possible to
    # have targets that glob files from different locations but with the same
    # `.framework` name, causing them to be merged into the same framework
    # during bundling.
    unique_frameworks = collections.uniq(
        [paths.basename(path) for path in framework_groups.keys()],
    )
    if len(unique_frameworks) > 1:
        fail("A framework import target may only include files for a " +
             "single '.framework' bundle.", attr = "framework_imports")

    return framework_groups

def _grouped_xcframework_files(framework_imports):
    """Returns a dictionary of each framework's imports, grouped by path to the .xcframework root."""
    framework_groups = group_files_by_directory(
        framework_imports,
        ["xcframework"],
        attr = "xcframework_imports",
    )

    # Only check for unique basenames of these keys, since it's possible to
    # have targets that glob files from different locations but with the same
    # `.xcframework` name, causing them to be merged into the same framework
    # during bundling.
    unique_frameworks = collections.uniq(
        [paths.basename(path) for path in framework_groups.keys()],
    )
    if len(unique_frameworks) > 1:
        fail("A framework import target may only include files for a " +
             "single '.xcframework' bundle.", attr = "xcframework_imports")

    return framework_groups

def _objc_provider_with_dependencies(ctx, objc_provider_fields, additional_objc_infos = []):
    """Returns a new Objc provider which includes transitive Objc dependencies."""
    objc_provider_fields["providers"] = [
        dep[apple_common.Objc]
        for dep in ctx.attr.deps
    ] + additional_objc_infos
    return apple_common.new_objc_provider(**objc_provider_fields)

def _cc_info_with_dependencies(
        ctx,
        header_imports,
        additional_cc_infos = [],
        includes = [],
        is_framework = True):
    """Returns a new CcInfo which includes transitive Cc dependencies."""
    framework_search_paths = _framework_search_paths(header_imports) if is_framework else []
    cc_info = CcInfo(
        compilation_context = cc_common.create_compilation_context(
            headers = depset(header_imports),
            framework_includes = depset(framework_search_paths),
            includes = depset(includes),
        ),
    )
    dep_cc_infos = [dep[CcInfo] for dep in ctx.attr.deps]
    return cc_common.merge_cc_infos(
        cc_infos = [cc_info] + dep_cc_infos + additional_cc_infos,
    )

def _transitive_framework_imports(deps):
    """Returns the list of transitive framework imports for the given deps."""
    return [
        dep[AppleFrameworkImportInfo].framework_imports
        for dep in deps
        if (AppleFrameworkImportInfo in dep and
            hasattr(dep[AppleFrameworkImportInfo], "framework_imports"))
    ]

def _framework_import_info(
        *,
        arch_found,
        debug_info_binaries,
        dsyms,
        transitive_sets):
    """Returns AppleFrameworkImportInfo containing transitive framework imports and build archs."""
    provider_fields = {}
    if transitive_sets:
        provider_fields["framework_imports"] = depset(transitive = transitive_sets)
    provider_fields["build_archs"] = depset([arch_found])
    provider_fields["debug_info_binaries"] = depset(debug_info_binaries)
    provider_fields["dsym_imports"] = depset(dsyms)
    return AppleFrameworkImportInfo(**provider_fields)

def _is_debugging(ctx):
    """Returns `True` if the current compilation mode produces debug info.

    rules_apple specific implementation of rules_swift's `is_debugging`, which
    is not currently exported.

    See: https://github.com/bazelbuild/rules_swift/blob/44146fccd9e56fe1dc650a4e0f21420a503d301c/swift/internal/api.bzl#L315-L326
    """
    return ctx.var["COMPILATION_MODE"] in ("dbg", "fastbuild")

def _ensure_swiftmodule_is_embedded(swiftmodule):
    """Ensures that a `.swiftmodule` file is embedded in a library or binary.

    rules_apple specific implementation of rules_swift's
    `ensure_swiftmodule_is_embedded`, which is not currently exported.

    See: https://github.com/bazelbuild/rules_swift/blob/e78ceb37c401a9bf9e551a6accd1df7d864688d5/swift/internal/debugging.bzl#L20-L47
    """
    return dict(
        linkopt = depset(["-Wl,-add_ast_path,{}".format(swiftmodule.path)]),
        link_inputs = depset([swiftmodule]),
    )

def _framework_objc_provider_fields(
        framework_binary_field,
        module_map_imports,
        framework_binaries):
    """Return an objc_provider initializer dictionary with information for a given framework."""

    objc_provider_fields = {}
    if module_map_imports:
        objc_provider_fields["module_map"] = depset(module_map_imports)

    if framework_binaries:
        objc_provider_fields[framework_binary_field] = depset(framework_binaries)

    return objc_provider_fields

def _swift_interop_info_with_dependencies(ctx, framework_groups, module_map_imports):
    """Return a Swift interop provider for the framework if it has a module map."""
    if not module_map_imports:
        return None

    # We can just take the first key because the rule implementation guarantees
    # that we only have files for a single framework.
    framework_dir = framework_groups.keys()[0]
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]

    # Likewise, assume that there is only a single module map file (the
    # legacy implementation that read from the Objc provider made the same
    # assumption).
    return swift_common.create_swift_interop_info(
        module_map = module_map_imports[0],
        module_name = framework_name,
        swift_infos = [dep[SwiftInfo] for dep in ctx.attr.deps if SwiftInfo in dep],
    )

def _framework_search_paths(header_imports):
    """Return the list framework search paths for the headers_imports."""
    if header_imports:
        header_groups = _grouped_framework_files(header_imports)

        search_paths = sets.make()
        for path in header_groups.keys():
            sets.insert(search_paths, paths.dirname(path))
        return sets.to_list(search_paths)
    else:
        return []

def _debug_info_binaries(
        dsym_binaries,
        framework_binaries):
    """Return the list of files that provide debug info."""
    all_binaries_dict = {}

    for file in dsym_binaries:
        dsym_bundle_path = bundle_paths.farthest_parent(
            file.short_path,
            "framework.dSYM",
        )
        dsym_bundle_basename = paths.basename(dsym_bundle_path)
        framework_basename = dsym_bundle_basename.rstrip(".dSYM")
        all_binaries_dict[framework_basename] = file

    for file in framework_binaries:
        framework_path = bundle_paths.farthest_parent(
            file.short_path,
            "framework",
        )
        framework_basename = paths.basename(framework_path)
        if framework_basename not in all_binaries_dict:
            all_binaries_dict[framework_basename] = file

    return all_binaries_dict.values()

def _get_current_library_identifier(
        *,
        current_platform,
        xcframework_path,
        xcframework_imports):
    """Returns a string representing the path to the framework to reference in the XCFramework bundle."""
    library_identifiers = sets.make()

    for f in xcframework_imports:
        inner_path = f.path[len(xcframework_path) + 1:]
        for i in range(len(inner_path)):
            if inner_path[i] == "/":
                identifier = inner_path[:i]
                sets.insert(library_identifiers, identifier)
                break

    platform_type = str(current_platform.platform_type).lower()
    is_device = current_platform.is_device

    for id in sets.to_list(library_identifiers):
        # Bazel can't build for the catalyst platform (with the public
        # crosstool), so just ignore it for now.
        if id.endswith("-maccatalyst"):
            continue

        # Filter out any ids not starting with the current platform type. This
        # will leave us a list of at most two identifiers that match either
        # "<platform_type>-<archs>" or "<platform_type>-<archs>-simulator"
        if not id.startswith(platform_type):
            continue

        # If the current platform is simulator, and the identifier also ends
        # with "-simulator", we found the identifier.
        if not is_device and id.endswith("-simulator"):
            return id

        # If the current platform is device, and the identifier doesn't end
        # with "-simulator", we found the identifier.
        if is_device and not id.endswith("-simulator"):
            return id

    return None

def _get_framework_name(framework_imports):
    """Returns the framework name (the directory name without .framework)."""

    # We can just take the first key because the rule implementation guarantees
    # that we only have files for a single framework.
    framework_groups = _grouped_framework_files(framework_imports)
    framework_dir = framework_groups.keys()[0]
    return paths.split_extension(paths.basename(framework_dir))[0]

def _process_xcframework_imports(ctx):
    xcframework_groups = _grouped_xcframework_files(ctx.files.xcframework_imports)

    # We can just take the first key because the rule implementation guarantees
    # that we only have files for a single framework.
    xcframework_path = xcframework_groups.keys()[0]
    xcframework_name = paths.split_extension(paths.basename(xcframework_path))[0]

    library_identifier = None
    if ctx.attr.library_identifiers:
        key = str(ctx.fragments.apple.single_arch_platform).lower()
        if key in ctx.attr.library_identifiers:
            library_identifier = ctx.attr.library_identifiers[key]
        else:
            fail(
                "Missing framework path mapping for platform `{}`; is this platform supported?"
                    .format(key),
            )

    # Try to figure out the library identifier from the platform being built
    # and `xcframework_imports` if it's not provided
    if not library_identifier:
        library_identifier = _get_current_library_identifier(
            current_platform = ctx.fragments.apple.single_arch_platform,
            xcframework_path = xcframework_path,
            xcframework_imports = ctx.files.xcframework_imports,
        )

    if not library_identifier:
        fail("Failed to figure out library identifiers. Please provide a " +
             "dictionary of library identifiers to `library_identifiers`.")

    single_platform_dir = paths.join(xcframework_path, library_identifier)

    # XCFramework with static frameworks
    platform_path = "{}/{}/{}.framework".format(xcframework_path, library_identifier, xcframework_name)
    framework_imports_for_platform = [f for f in ctx.files.xcframework_imports if platform_path in f.path]

    # If this is still empty, we are probably processing an XCFramework with
    # static libraries, so do a second check with the platform path not
    # including the `.framework` directory.
    if not framework_imports_for_platform:
        platform_path = "{}/{}/".format(xcframework_path, library_identifier)
        framework_imports_for_platform = [f for f in ctx.files.xcframework_imports if platform_path in f.path]

    if not framework_imports_for_platform:
        fail("Couldn't find framework or library at path `{}`".format(platform_path))

    return xcframework_name, single_platform_dir, framework_imports_for_platform

def _common_dynamic_framework_import_impl(ctx, is_xcframework):
    """Common implementation for the apple_dynamic_framework_import and apple_dynamic_xcframework_import rules."""
    providers = []

    if is_xcframework:
        _, _, framework_imports = _process_xcframework_imports(ctx)
    else:
        framework_imports = ctx.files.framework_imports

    bundling_imports, header_imports, module_map_imports = (
        _classify_framework_imports(ctx.var, framework_imports)
    )

    transitive_sets = _transitive_framework_imports(ctx.attr.deps)
    if bundling_imports:
        transitive_sets.append(depset(bundling_imports))
    framework_groups = _grouped_framework_files(framework_imports)
    framework_binaries = _all_framework_binaries(framework_groups)

    # TODO: Support dSYM import
    if is_xcframework:
        dsym_binaries = []
        dsym_imports = []
    else:
        dsym_binaries = _all_dsym_binaries(ctx.files.dsym_imports)
        dsym_imports = ctx.files.dsym_imports

    debug_info_binaries = _debug_info_binaries(
        dsym_binaries = dsym_binaries,
        framework_binaries = framework_binaries,
    )
    providers.append(
        _framework_import_info(
            arch_found = ctx.fragments.apple.single_arch_cpu,
            debug_info_binaries = debug_info_binaries,
            dsyms = dsym_imports,
            transitive_sets = transitive_sets,
        ),
    )

    framework_dirs_set = depset(framework_groups.keys())
    objc_provider_fields = _framework_objc_provider_fields(
        "dynamic_framework_file",
        module_map_imports,
        [] if ctx.attr.bundle_only else framework_binaries,
    )

    objc_provider = _objc_provider_with_dependencies(ctx, objc_provider_fields)
    cc_info = _cc_info_with_dependencies(ctx, header_imports)
    providers.append(objc_provider)
    providers.append(cc_info)
    providers.append(apple_common.new_dynamic_framework_provider(
        objc = objc_provider,
        framework_dirs = framework_dirs_set,
        framework_files = depset(framework_imports),
    ))

    # For now, Swift interop is restricted only to a Clang module map inside
    # the framework.
    swift_interop_info = _swift_interop_info_with_dependencies(
        ctx = ctx,
        framework_groups = framework_groups,
        module_map_imports = module_map_imports,
    )
    if swift_interop_info:
        providers.append(swift_interop_info)

    return providers

def _common_static_framework_import_impl(ctx, is_xcframework):
    """Common implementation for the apple_static_framework_import and apple_static_xcframework_import rules."""
    providers = []

    if is_xcframework:
        framework_name, single_platform_dir, framework_imports = _process_xcframework_imports(ctx)
    else:
        framework_imports = ctx.files.framework_imports
        framework_name = _get_framework_name(framework_imports)
        single_platform_dir = None

    other_imports, header_imports, module_map_imports = _classify_framework_imports(
        ctx.var,
        framework_imports,
    )

    transitive_sets = _transitive_framework_imports(ctx.attr.deps)
    providers.append(_framework_import_info(
        arch_found = ctx.fragments.apple.single_arch_cpu,
        debug_info_binaries = [],
        dsyms = [],
        transitive_sets = transitive_sets,
    ))

    is_framework = False
    for f in framework_imports:
        if f.dirname.endswith(".framework"):
            is_framework = True
            break

    if is_framework:
        framework_groups = _grouped_framework_files(framework_imports)
        framework_binaries = _all_framework_binaries(
            frameworks_groups = framework_groups,
        )

        objc_provider_fields = _framework_objc_provider_fields(
            "static_framework_file",
            module_map_imports,
            framework_binaries,
        )
    else:
        framework_groups = _grouped_xcframework_files(framework_imports)
        framework_binaries = []

        # For non-framework types (XCFrameworks not embedding any .framework
        # bundle but only contain static libraries, headers, and module maps),
        # assume the library filename is the same with XCFramework name or has
        # the .a extension. If the library file has a different naming, the
        # XCFramework can't be processed now.
        for f in other_imports:
            file_basename = f.basename
            if file_basename == framework_name or file_basename.endswith(".a"):
                framework_binaries.append(f)

        objc_provider_fields = _framework_objc_provider_fields(
            "library",
            module_map_imports,
            framework_binaries,
        )

    if is_xcframework and not framework_binaries:
        fail("Static XCFrameworks without binaries are not supported.")

    if ctx.attr.alwayslink:
        if not framework_binaries:
            fail("ERROR: There has to be a binary file in the imported framework.")
        objc_provider_fields["force_load_library"] = depset(framework_binaries)
    if ctx.attr.sdk_dylibs:
        objc_provider_fields["sdk_dylib"] = depset(ctx.attr.sdk_dylibs)
    if ctx.attr.sdk_frameworks:
        objc_provider_fields["sdk_framework"] = depset(ctx.attr.sdk_frameworks)
    if ctx.attr.weak_sdk_frameworks:
        objc_provider_fields["weak_sdk_framework"] = depset(ctx.attr.weak_sdk_frameworks)

    swiftmodule_imports = [
        header
        for header in header_imports
        if _is_swiftmodule(header.basename)
    ]

    additional_objc_infos = []
    additional_cc_infos = []

    if swiftmodule_imports:
        toolchain = ctx.attr._toolchain[SwiftToolchainInfo]
        providers.append(SwiftUsageInfo(toolchain = toolchain))

        # The Swift toolchain propagates Swift-specific linker flags (e.g.,
        # library/framework search paths) as an implicit dependency. In the
        # rare case that a binary has a Swift framework import dependency but
        # no other Swift dependencies, make sure we pick those up so that it
        # links to the standard libraries correctly.
        additional_objc_infos.extend(toolchain.implicit_deps_providers.objc_infos)
        additional_cc_infos.extend(toolchain.implicit_deps_providers.cc_infos)

        if _is_debugging(ctx):
            cpu = ctx.fragments.apple.single_arch_cpu
            swiftmodule = _swiftmodule_for_cpu(swiftmodule_imports, cpu)
            if swiftmodule:
                objc_provider_fields.update(_ensure_swiftmodule_is_embedded(swiftmodule))

    providers.append(
        _objc_provider_with_dependencies(ctx, objc_provider_fields, additional_objc_infos),
    )

    includes = []
    if is_xcframework and not is_framework and ctx.attr.includes:
        includes.extend([
            paths.join(single_platform_dir, x)
            for x in ctx.attr.includes
        ])

    providers.append(
        _cc_info_with_dependencies(ctx, header_imports, additional_cc_infos, includes, is_framework),
    )

    # For now, Swift interop is restricted only to a Clang module map inside
    # the framework.
    swift_interop_info = _swift_interop_info_with_dependencies(
        ctx = ctx,
        framework_groups = framework_groups,
        module_map_imports = module_map_imports,
    )
    if swift_interop_info:
        providers.append(swift_interop_info)

    bundle_files = [x for x in framework_imports if ".bundle/" in x.short_path]
    if bundle_files:
        parent_dir_param = partial.make(
            resources.bundle_relative_parent_dir,
            extension = "bundle",
        )
        resource_provider = resources.bucketize_typed(
            bundle_files,
            owner = str(ctx.label),
            bucket_type = "unprocessed",
            parent_dir_param = parent_dir_param,
        )
        providers.append(resource_provider)

    return providers

def _apple_dynamic_framework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    return _common_dynamic_framework_import_impl(ctx, is_xcframework = False)

def _apple_dynamic_xcframework_import_impl(ctx):
    """Implementation for the apple_dynamic_xcframework_import rule."""
    return _common_dynamic_framework_import_impl(ctx, is_xcframework = True)

def _apple_static_framework_import_impl(ctx):
    """Implementation for the apple_static_framework_import rule."""
    return _common_static_framework_import_impl(ctx, is_xcframework = False)

def _apple_static_xcframework_import_impl(ctx):
    """Implementation for the apple_static_xcframework_import rule."""
    return _common_static_framework_import_impl(ctx, is_xcframework = True)

apple_dynamic_framework_import = rule(
    implementation = _apple_dynamic_framework_import_impl,
    fragments = ["apple"],
    attrs = {
        "framework_imports": attr.label_list(
            allow_empty = False,
            allow_files = True,
            mandatory = True,
            doc = """
The list of files under a .framework directory which are provided to Apple based targets that depend
on this target.
""",
        ),
        "deps": attr.label_list(
            aspects = [swift_clang_module_aspect],
            doc = """
A list of targets that are dependencies of the target being built, which will be linked into that
target.
""",
            providers = [
                [apple_common.Objc, CcInfo],
                [apple_common.Objc, CcInfo, AppleFrameworkImportInfo],
            ],
        ),
        "dsym_imports": attr.label_list(
            allow_files = True,
            doc = """
The list of files under a .dSYM directory, that is the imported framework's dSYM bundle.
""",
        ),
        "bundle_only": attr.bool(
            default = False,
            doc = """
Avoid linking the dynamic framework, but still include it in the app. This is useful when you want
to manually dlopen the framework at runtime.
""",
        ),
    },
    doc = """
This rule encapsulates an already-built dynamic framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_dynamic_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_dynamic_framework_import(
    name = "my_dynamic_framework",
    framework_imports = glob(["my_dynamic_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_dynamic_framework",
    ],
)
```
""",
)

apple_static_framework_import = rule(
    implementation = _apple_static_framework_import_impl,
    fragments = ["apple"],
    attrs = dicts.add(swift_common.toolchain_attrs(), {
        "framework_imports": attr.label_list(
            allow_empty = False,
            allow_files = True,
            mandatory = True,
            doc = """
The list of files under a .framework directory which are provided to Apple based targets that depend
on this target.
""",
        ),
        "sdk_dylibs": attr.string_list(
            doc = """
Names of SDK .dylib libraries to link with. For instance, `libz` or `libarchive`. `libc++` is
included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree.
When linking a binary, all libraries named in that binary's transitive dependency graph are used.
""",
        ),
        "sdk_frameworks": attr.string_list(
            doc = """
Names of SDK frameworks to link with (e.g. `AddressBook`, `QuartzCore`). `UIKit` and `Foundation`
are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only
`Foundation` is always included. When linking a top level binary, all SDK frameworks listed in that
binary's transitive dependency graph are linked.
""",
        ),
        "weak_sdk_frameworks": attr.string_list(
            doc = """
Names of SDK frameworks to weakly link with. For instance, `MediaAccessibility`. In difference to
regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they
are not present at runtime.
""",
        ),
        "deps": attr.label_list(
            aspects = [swift_clang_module_aspect],
            doc = """
A list of targets that are dependencies of the target being built, which will provide headers and be
linked into that target.
""",
            providers = [
                [apple_common.Objc, CcInfo],
                [apple_common.Objc, CcInfo, AppleFrameworkImportInfo],
            ],
        ),
        "alwayslink": attr.bool(
            default = False,
            doc = """
If true, any binary that depends (directly or indirectly) on this framework will link in all the
object files for the framework file, even if some contain no symbols referenced by the binary. This
is useful if your code isn't explicitly called by code in the binary; for example, if you rely on
runtime checks for protocol conformances added in extensions in the library but do not directly
reference any other symbols in the object file that adds that conformance.
""",
        ),
    }),
    doc = """
This rule encapsulates an already-built static framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_static_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_static_framework_import(
    name = "my_static_framework",
    framework_imports = glob(["my_static_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_static_framework",
    ],
)
```
""",
)

_xcframework_import_common_attrs = {
    "library_identifiers": attr.string_dict(
        doc = """
An optional key-value map of platforms to the corresponding platform IDs
(containing all supported architectures), relative to the XCFramework. The
identifier keys should be case-insensitive variants of the values in
[`apple_common.platform`](https://docs.bazel.build/versions/5.0.0/skylark/lib/apple_common.html#platform);
for example, `ios_device` or `ios_simulator`. The identifier values should be
case-sensitive variants of values that might be found in the
`LibraryIdentifier` of an `Info.plist` file in the XCFramework's root; for example,
`ios-arm64_i386_x86_64-simulator` or `ios-arm64_armv7`.

Passing this attribute should not be neccessary if the XCFramework follows the
standard naming convention (that is, it was created by Xcode or Bazel).
""",
    ),
    "xcframework_imports": attr.label_list(
        allow_empty = False,
        allow_files = True,
        mandatory = True,
        doc = """
The list of files under a .xcframework directory which are provided to Apple
based targets that depend on this target.
""",
    ),
    "deps": attr.label_list(
        aspects = [swift_clang_module_aspect],
        doc = """
A list of targets that are dependencies of the target being built, which will
provide headers (if the importing XCFramework is a dynamic framework) and can be
linked into that target.
""",
        providers = [
            [apple_common.Objc, CcInfo],
            [apple_common.Objc, CcInfo, AppleFrameworkImportInfo],
        ],
    ),
}

apple_dynamic_xcframework_import = rule(
    implementation = _apple_dynamic_xcframework_import_impl,
    fragments = ["apple"],
    attrs = dicts.add(_xcframework_import_common_attrs, {
        "bundle_only": attr.bool(
            default = False,
            doc = """
Avoid linking the dynamic XCFramework, but still include it in the app. This is
useful when you want to manually dlopen the XCFramework at runtime.
""",
        ),
    }),
    doc = """
This rule encapsulates an already-built dynamic XCFramework. It is defined by a
list of files in exactly one `.xcframework` directory.
`apple_dynamic_xcframework_import` targets need to be added to library targets
through the `deps` attribute.

### Examples

```starlark
apple_dynamic_xcframework_import(
    name = "my_dynamic_xcframework",
    xcframework_imports = glob(["my_dynamic_framework.xcframework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_dynamic_xcframework",
    ],
)
```
""",
)

apple_static_xcframework_import = rule(
    implementation = _apple_static_xcframework_import_impl,
    fragments = ["apple"],
    attrs = dicts.add(
        _xcframework_import_common_attrs,
        swift_common.toolchain_attrs(),
        {
            "includes": attr.string_list(
                doc = """
List of `#include/#import` search paths to add to this target and all depending
targets.

The paths are interpreted relative to the single platform directory inside the
XCFramework for the platform being built.

These flags are added for this rule and every rule that depends on it. (Note:
not the rules it depends upon!) Be very careful, since this may have
far-reaching effects.
""",
            ),
            "sdk_dylibs": attr.string_list(
                doc = """
Names of SDK .dylib libraries to link with. For instance, `libz` or
`libarchive`. `libc++` is included automatically if the binary has any C++ or
Objective-C++ sources in its dependency tree.  When linking a binary, all
libraries named in that binary's transitive dependency graph are used.
""",
            ),
            "sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to link with (e.g. `AddressBook`, `QuartzCore`).
`UIKit` and `Foundation` are always included when building for the iOS, tvOS
and watchOS platforms. For macOS, only `Foundation` is always included. When
linking a top level binary, all SDK frameworks listed in that binary's
transitive dependency graph are linked.
""",
            ),
            "weak_sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to weakly link with. For instance,
`MediaAccessibility`. In difference to regularly linked SDK frameworks, symbols
from weakly linked frameworks do not cause an error if they are not present at
runtime.
""",
            ),
            "alwayslink": attr.bool(
                default = False,
                doc = """
If true, any binary that depends (directly or indirectly) on this framework
will link in all the object files for the framework file, even if some contain
no symbols referenced by the binary. This is useful if your code isn't
explicitly called by code in the binary; for example, if you rely on runtime
checks for protocol conformances added in extensions in the library but do not
directly reference any other symbols in the object file that adds that
conformance.
""",
            ),
        },
    ),
    doc = """
This rule encapsulates an already-built static XCFramework. It is defined by a
list of files in exactly one `.xcframework` directory.
`apple_static_xcframework_import` targets need to be added to library targets
through the `deps` attribute.

### Examples

```slarlark
apple_static_xcframework_import(
    name = "my_static_xcframework",
    xcframework_imports = glob(["my_static_framework.xcframework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_static_xcframework",
    ],
)
```
""",
)
