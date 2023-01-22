"""apple_library macro implementation."""

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
        content += "  header \"%s\"\n" % swift_generated_header.basename
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

    module_map = ctx.actions.declare_file(ctx.attr.name + "-module.modulemap")
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

# TODO: Document the apple_library macro
def apple_library(**kwargs):
    """Compiles and links Objective-C and Swift code into a static library.

    Args:
      **kwargs: Other arguments are passed directly to `apple_library`.
    """

    hdrs = kwargs.pop("hdrs", [])
    srcs = kwargs.pop("srcs", [])

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

    name = kwargs.get("name", None)
    module_name = kwargs.pop("module_name", name)
    swift_library_name = name + "_swift"

    deps = kwargs.pop("deps", [])
    objc_deps = []
    swift_deps = [] + deps

    swift_copts = kwargs.pop("swift_copts", [])
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
    textual_hdrs = kwargs.get("textual_hdrs", [])
    _module_map(
        name = name + "_objc_module",
        hdrs = hdrs,
        module_name = module_name,
        textual_hdrs = textual_hdrs,
    )

    objc_module_map = ":" + name + "_objc_module"
    swiftc_inputs = kwargs.pop("swiftc_inputs", [])
    swiftc_inputs = swiftc_inputs + hdrs + textual_hdrs + private_hdrs + [objc_module_map]

    swift_copts += [
        "-Xcc",
        "-fmodule-map-file=$(execpath {})".format(objc_module_map),
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
    )

    umbrella_module_map = name + "_umbrella_module"
    _module_map(
        name = umbrella_module_map,
        deps = [":" + swift_library_name],
        hdrs = hdrs,
        module_name = module_name,
    )
    objc_deps.append(":" + umbrella_module_map)

    objc_copts = kwargs.pop("objc_copts", [])

    native.objc_library(
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
        **kwargs
    )
