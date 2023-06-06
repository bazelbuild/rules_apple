"""experimental_mixed_language_library macro implementation."""

load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
    "swift_library",
)
load("@bazel_skylib//lib:paths.bzl", "paths")

_CPP_FILE_TYPES = [".cc", ".cpp", ".mm", ".cxx", ".C"]

_NON_CPP_FILE_TYPES = [".m", ".c"]

_ASSEMBLY_FILE_TYPES = [".s", ".S", ".asm"]

_OBJECT_FILE_FILE_TYPES = [".o"]

_HEADERS_FILE_TYPES = [
    ".h",
    ".hh",
    ".hpp",
    ".ipp",
    ".hxx",
    ".h++",
    ".inc",
    ".inl",
    ".tlh",
    ".tli",
    ".H",
    ".hmap",
]

_OBJC_FILE_TYPES = _CPP_FILE_TYPES + \
                   _NON_CPP_FILE_TYPES + \
                   _ASSEMBLY_FILE_TYPES + \
                   _OBJECT_FILE_FILE_TYPES + \
                   _HEADERS_FILE_TYPES

_SWIFT_FILE_TYPES = [".swift"]

def _module_map_content(
        module_name,
        hdrs,
        textual_hdrs,
        swift_generated_header,
        module_map_path):
    # Up to the execution root
    # bazel-out/<platform-config>/bin/<path/to/package>/<target-name>.modulemaps/<module-name>
    slashes_count = module_map_path.count("/")
    relative_path = "".join(["../"] * slashes_count)

    content = "module " + module_name + " {\n"

    for hdr in hdrs:
        if hdr.extension == "h":
            content += "  header \"%s%s\"\n" % (relative_path, hdr.path)
    for hdr in textual_hdrs:
        if hdr.extension == "h":
            content += "  textual header \"%s%s\"\n" % (relative_path, hdr.path)

    content += "\n"
    content += "  export *\n"
    content += "}\n"

    # Add a Swift submodule if a Swift generated header exists
    if swift_generated_header:
        content += "\n"
        content += "module " + module_name + ".Swift {\n"
        content += "  header \"../%s\"\n" % swift_generated_header.basename
        content += "  requires objc\n"
        content += "}\n"

    return content

def _umbrella_header_content(hdrs):
    # If the platform is iOS, add an import call to `UIKit/UIKit.h` to the top
    # of the umbrella header. This allows implicit import of UIKit from Swift.
    content = """\
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif
#endif

"""
    for hdr in hdrs:
        if hdr.extension == "h":
            content += "#import \"%s\"\n" % (hdr.path)

    return content

def _module_map_impl(ctx):
    outputs = []

    hdrs = ctx.files.hdrs
    textual_hdrs = ctx.files.textual_hdrs
    outputs.extend(hdrs)
    outputs.extend(textual_hdrs)

    # Find Swift generated header
    swift_generated_header = None
    for dep in ctx.attr.deps:
        if CcInfo in dep:
            objc_headers = dep[CcInfo].compilation_context.headers.to_list()
        else:
            objc_headers = []
        for hdr in objc_headers:
            if hdr.owner == dep.label:
                swift_generated_header = hdr
                outputs.append(swift_generated_header)

    # Write the module map content
    if swift_generated_header:
        umbrella_header_path = ctx.attr.module_name + ".h"
        umbrella_header = ctx.actions.declare_file(umbrella_header_path)
        outputs.append(umbrella_header)
        ctx.actions.write(
            content = _umbrella_header_content(hdrs),
            output = umbrella_header,
        )
        outputs.append(umbrella_header)
        module_map_path = "%s/%s" % (ctx.attr.name, "module.modulemap")
    else:
        module_map_path = ctx.attr.name + ".modulemap"
    module_map = ctx.actions.declare_file(module_map_path)
    outputs.append(module_map)

    ctx.actions.write(
        content = _module_map_content(
            module_name = ctx.attr.module_name,
            hdrs = hdrs,
            textual_hdrs = textual_hdrs,
            swift_generated_header = swift_generated_header,
            module_map_path = module_map.path,
        ),
        output = module_map,
    )

    objc_provider = apple_common.new_objc_provider()

    compilation_context = cc_common.create_compilation_context(
        headers = depset(outputs),
    )
    cc_info = CcInfo(
        compilation_context = compilation_context,
    )

    return [
        DefaultInfo(
            files = depset([module_map]),
        ),
        objc_provider,
        cc_info,
    ]

_module_map = rule(
    attrs = {
        "module_name": attr.string(
            mandatory = True,
            doc = "The name of the module.",
        ),
        "hdrs": attr.label_list(
            allow_files = _HEADERS_FILE_TYPES,
            doc = """\
The list of C, C++, Objective-C, and Objective-C++ header files used to
construct the module map.
""",
        ),
        "textual_hdrs": attr.label_list(
            allow_files = _HEADERS_FILE_TYPES,
            doc = """\
The list of C, C++, Objective-C, and Objective-C++ header files used to
construct the module map. Unlike hdrs, these will be declared as 'textual
header' in the module map.
""",
        ),
        "deps": attr.label_list(
            providers = [SwiftInfo],
            doc = """\
The list of swift_library targets.  A `${module_name}.Swift` submodule will be
generated if non-empty.
""",
        ),
    },
    doc = "Generates a module map given a list of header files.",
    implementation = _module_map_impl,
    provides = [
        DefaultInfo,
    ],
)

def experimental_mixed_language_library(
        *,
        name,
        srcs,
        deps = [],
        module_name = None,
        objc_copts = [],
        swift_copts = [],
        swiftc_inputs = [],
        testonly = False,
        **kwargs):
    """Compiles and links Objective-C and Swift code into a static library.

    This is an experimental macro that supports compiling mixed Objective-C and
    Swift source files into a static library.

    Due to the build performance reason, in general it's not recommended to
    have mixed Objective-C and Swift modules, but it isn't uncommon to see
    mixed language modules in some old codebases. This macro is meant to make
    it easier to migrate codebases with mixed language modules to Bazel without
    having to demix them first.

    This macro only supports a very simple use case of mixed language
    modules---it does not support for header maps or Clang modules.

    Args:
        name: A unique name for this target.
        deps: A list of targets that are dependencies of the target being
            built, which will be linked into that target.
        module_name: The name of the mixed language module being built.
            If left unspecified, the module name will be the name of the
            target.
        objc_copts: Additional compiler options that should be passed to
            `clang`.
        srcs: The list of Objective-C and Swift source files to compile.
        swift_copts: Additional compiler options that should be passed to
            `swiftc`. These strings are subject to `$(location ...)` and "Make"
            variable expansion.
        swiftc_inputs: Additional files that are referenced using
            `$(location...)` in `swift_copts`.
        testonly: If True, only testonly targets (such as tests) can depend on
            this target. Default False.
        **kwargs: Other arguments to pass through to the underlying
            `objc_library`.
    """

    hdrs = kwargs.pop("hdrs", [])

    if not srcs:
        fail("'srcs' must be non-empty")

    swift_srcs = []
    objc_srcs = []
    private_hdrs = []

    for x in srcs:
        _, extension = paths.split_extension(x)
        if extension in _SWIFT_FILE_TYPES:
            swift_srcs.append(x)
        elif extension in _OBJC_FILE_TYPES:
            objc_srcs.append(x)
            if extension in _HEADERS_FILE_TYPES:
                private_hdrs.append(x)
    if not objc_srcs:
        fail("""\
'srcs' must contain Objective-C source files. Use 'swift_library' if this
target only contains Swift files.""")
    if not swift_srcs:
        fail("""\
'srcs' must contain Swift source files. Use 'objc_library' if this
target only contains Objective-C files.""")

    if not module_name:
        module_name = name
    swift_library_name = name + ".internal.swift"

    objc_deps = []
    swift_deps = [] + deps

    swift_copts = swift_copts + [
        "-Xfrontend",
        "-enable-objc-interop",
        "-import-underlying-module",
    ]

    objc_deps = [":" + swift_library_name]

    # Add Obj-C includes to Swift header search paths
    repository_name = native.repository_name()
    includes = kwargs.get("includes", [])
    for x in includes:
        include = x if repository_name == "@" else "external/" + repository_name.lstrip("@") + "/" + x
        swift_copts += [
            "-Xcc",
            "-I{}".format(include),
        ]

    # Generate module map for the underlying Obj-C module
    objc_module_map_name = name + ".internal.objc"
    textual_hdrs = kwargs.get("textual_hdrs", [])
    _module_map(
        name = objc_module_map_name,
        hdrs = hdrs,
        module_name = module_name,
        textual_hdrs = textual_hdrs,
        testonly = testonly,
    )

    swiftc_inputs = swiftc_inputs + hdrs + textual_hdrs + private_hdrs + [":" + objc_module_map_name]

    swift_copts += [
        "-Xcc",
        "-fmodule-map-file=$(execpath :{})".format(objc_module_map_name),
    ]

    features = kwargs.pop("features", [])
    swift_features = features + ["swift.no_generated_module_map"]

    swift_library(
        name = swift_library_name,
        copts = swift_copts,
        deps = swift_deps,
        features = swift_features,
        generated_header_name = module_name + "-Swift.h",
        generates_header = True,
        module_name = module_name,
        srcs = swift_srcs,
        swiftc_inputs = swiftc_inputs,
        testonly = testonly,
    )

    umbrella_module_map = name + ".internal.umbrella"
    _module_map(
        name = umbrella_module_map,
        deps = [":" + swift_library_name],
        hdrs = hdrs,
        module_name = module_name,
        testonly = testonly,
    )
    objc_deps.append(":" + umbrella_module_map)

    native.objc_library(
        name = name,
        copts = objc_copts,
        deps = objc_deps,
        hdrs = hdrs + [
            # These aren't headers but here is the only place to declare these
            # files as the inputs because objc_library doesn't have an
            # attribute to declare custom inputs.
            ":" + umbrella_module_map,
        ],
        module_map = umbrella_module_map,
        srcs = objc_srcs,
        testonly = testonly,
        **kwargs
    )
