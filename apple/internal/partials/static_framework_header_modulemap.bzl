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

"""Partial implementation for bundling header and modulemaps for static frameworks."""

load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
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
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _get_link_declarations(dylibs = [], frameworks = []):
    """Returns the module map lines that link to the given dylibs and frameworks.

    Args:
      dylibs: A sequence of library names (which must begin with "lib") that will
          be referenced in the module map.
      frameworks: A sequence of framework names that will be referenced in the
          module map.

    Returns:
      A list of "link" and "link framework" lines that reference the given
      libraries and frameworks.
    """
    link_lines = []

    for dylib in dylibs:
        if not dylib.startswith("lib"):
            fail("Linked libraries must start with 'lib' but found %s", dylib)
        link_lines.append('link "%s"' % dylib[3:])
    for framework in frameworks:
        link_lines.append('link framework "%s"' % framework)

    return link_lines

def _get_umbrella_header_declaration(basename):
    """Returns the module map line that references an umbrella header.

    Args:
      basename: The basename of the umbrella header file to be referenced in the
          module map.

    Returns:
      The module map line that references the umbrella header.
    """
    return 'umbrella header "%s"' % basename

def _create_modulemap(
        actions,
        output,
        module_name,
        umbrella_header_name,
        sdk_dylibs,
        sdk_frameworks):
    """Creates a modulemap for a framework.

    Args:
      actions: The actions module from a rule or aspect context.
      output: A declared `File` to which the module map will be written.
      module_name: The name of the module to declare in the module map file.
      umbrella_header_name: The basename of the umbrella header file, or None if
          there is no umbrella header.
      sdk_dylibs: A list of system dylibs to list in the module.
      sdk_frameworks: A list of system frameworks to list in the module.
    """
    declarations = []
    if umbrella_header_name:
        declarations.append(
            _get_umbrella_header_declaration(umbrella_header_name),
        )
    declarations.extend([
        "export *",
        "module * { export * }",
    ])
    declarations.extend(_get_link_declarations(sdk_dylibs, sdk_frameworks))

    content = (
        ("framework module %s {\n" % module_name) +
        "\n".join(["  " + decl for decl in declarations]) +
        "\n}\n"
    )
    actions.write(output = output, content = content)

def _create_umbrella_header(actions, output, headers):
    """Creates an umbrella header that imports a list of other headers.

    Args:
      actions: The `actions` module from a rule or aspect context.
      output: A declared `File` to which the umbrella header will be written.
      headers: A list of header files to be imported by the umbrella header.
    """
    import_lines = ['#import "%s"' % f.basename for f in headers]
    content = "\n".join(import_lines) + "\n"
    actions.write(output = output, content = content)

def _static_framework_header_modulemap_partial_impl(ctx, hdrs, umbrella_header, binary_objc_provider):
    """Implementation for the static framework headers and modulemaps partial."""
    bundle_name = bundling_support.bundle_name(ctx)

    bundle_files = []

    umbrella_header_name = None
    if umbrella_header:
        umbrella_header_name = umbrella_header.basename
        bundle_files.append(
            (processor.location.bundle, "Headers", depset(hdrs + [umbrella_header])),
        )
    elif hdrs:
        umbrella_header_name = "{}.h".format(bundle_name)
        umbrella_header_file = intermediates.file(ctx.actions, ctx.label.name, umbrella_header_name)
        _create_umbrella_header(
            ctx.actions,
            umbrella_header_file,
            sorted(hdrs),
        )

        # Don't bundle the umbrella header if there is only one public header
        # which has the same name
        if len(hdrs) == 1 and hdrs[0].basename == umbrella_header_name:
            bundle_files.append(
                (processor.location.bundle, "Headers", depset(hdrs)),
            )
        else:
            bundle_files.append(
                (processor.location.bundle, "Headers", depset(hdrs + [umbrella_header_file])),
            )
    else:
        umbrella_header_name = None

    sdk_dylibs = getattr(binary_objc_provider, "sdk_dylib", None)
    sdk_frameworks = getattr(binary_objc_provider, "sdk_framework", None)

    # Create a module map if there is a need for one (that is, if there are
    # headers or if there are dylibs/frameworks that the target depends on).
    if any([sdk_dylibs, sdk_dylibs, umbrella_header_name]):
        modulemap_file = intermediates.file(ctx.actions, ctx.label.name, "module.modulemap")
        _create_modulemap(
            ctx.actions,
            modulemap_file,
            bundle_name,
            umbrella_header_name,
            sorted(sdk_dylibs.to_list()) if sdk_dylibs else [],
            sorted(sdk_frameworks.to_list() if sdk_frameworks else []),
        )
        bundle_files.append((processor.location.bundle, "Modules", depset([modulemap_file])))

    return struct(
        bundle_files = bundle_files,
    )

def static_framework_header_modulemap_partial(hdrs, umbrella_header, binary_objc_provider):
    """Constructor for the static framework headers and modulemaps partial.

    This partial bundles the headers and modulemaps for static frameworks.

    Args:
      hdrs: The list of headers to bundle.
      umbrella_header: An umbrella header to use instead of generating one
      binary_objc_provider: The ObjC provider for the binary target.

    Returns:
      A partial that returns the bundle location of the static framework header and modulemap
      artifacts.
    """
    return partial.make(
        _static_framework_header_modulemap_partial_impl,
        hdrs = hdrs,
        umbrella_header = umbrella_header,
        binary_objc_provider = binary_objc_provider,
    )
