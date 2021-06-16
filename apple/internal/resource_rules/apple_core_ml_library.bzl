# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Implementation of Apple CoreML library rule."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleSupportToolchainInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _apple_core_ml_library_impl(ctx):
    """Implementation of the apple_core_ml_library."""
    actions = ctx.actions
    basename = paths.replace_extension(ctx.file.mlmodel.basename, "")

    deps = getattr(ctx.attr, "deps", None)
    uses_swift = swift_support.uses_swift(deps) if deps else False

    coremlc_source = actions.declare_file(
        "{}.m".format(basename),
        sibling = ctx.outputs.source,
    )
    coremlc_header = actions.declare_file("{}.h".format(basename), sibling = coremlc_source)

    # TODO(b/168721966): Consider if an aspect could be used to generate mlmodel sources. This
    # would be similar to how we are planning to use the resource aspect with the
    # apple_resource_bundle and apple_resource_group resource rules. That might allow for more
    # portable platform information.
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        config_vars = ctx.var,
        device_families = None,
        disabled_features = ctx.disabled_features,
        explicit_minimum_deployment_os = None,
        explicit_minimum_os = None,
        features = ctx.features,
        objc_fragment = None,
        platform_type_string = str(ctx.fragments.apple.single_arch_platform.platform_type),
        uses_swift = uses_swift,
        xcode_path_wrapper = ctx.executable._xcode_path_wrapper,
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]

    # coremlc doesn't have any configuration on the name of the generated source files, it uses the
    # basename of the mlmodel file instead, so we need to expect those files as outputs.
    resource_actions.generate_objc_mlmodel_sources(
        actions = actions,
        input_file = ctx.file.mlmodel,
        output_source = coremlc_source,
        output_header = coremlc_header,
        platform_prerequisites = platform_prerequisites,
        resolved_xctoolrunner = apple_toolchain_info.resolved_xctoolrunner,
    )

    # But we would like our ObjC clients to use <target_name>.h instead, so we create that header
    # too and import the coremlc header.
    public_header = actions.declare_file("{}.h".format(ctx.attr.header_name))
    actions.write(
        public_header,
        "#import \"{}\"".format(coremlc_header.path),
    )

    # In order to reference the source file from the macro context, we need to have an implicit
    # output, but those can only reference the name of the target, so we need to symlink the coremlc
    # source into the implicit output. We don't want to do this for the headers since we would like
    # the header to be named as the objc_library target and not the target for this rule.
    actions.symlink(target_file = coremlc_source, output = ctx.outputs.source)

    # This rule returns the headers as its outputs so that they can be referenced in the hdrs of the
    # underlying objc_library.
    return [DefaultInfo(files = depset([public_header, coremlc_header]))]

apple_core_ml_library = rule(
    implementation = _apple_core_ml_library_impl,
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "mlmodel": attr.label(
            allow_single_file = ["mlmodel"],
            mandatory = True,
            doc = """
Label to a single `.mlmodel` file from which to generate sources and compile into mlmodelc files.
""",
        ),
        "header_name": attr.string(
            mandatory = True,
            doc = "Private attribute to configure the ObjC header name to be exported.",
        ),
        "_toolchain": attr.label(
            default = Label("@build_bazel_rules_apple//apple/internal:toolchain_support"),
            providers = [[AppleSupportToolchainInfo]],
        ),
    }),
    output_to_genfiles = True,
    fragments = ["apple"],
    outputs = {
        "source": "%{name}.m",
    },
    doc = """
This rule takes a single mlmodel file and creates a target that can be added as a dependency from
objc_library or swift_library targets. For Swift, just import like any other objc_library target.
For objc_library, this target generates a header named `<target_name>.h` that can be imported from
within the package where this target resides. For example, if this target's label is
`//my/package:coreml`, you can import the header as `#import "my/package/coreml.h"`.

This rule supports the integration of CoreML `mlmodel` files into Apple rules.
`apple_core_ml_library` targets are added directly into `deps` for both
`objc_library` and `swift_library` targets.

For Swift, import the `apple_core_ml_library` the same way you'd import an
`objc_library` or `swift_library` target. For `objc_library` targets,
`apple_core_ml_library` creates a header file named after the target.

For example, if the `apple_core_ml_library` target's label is
`//my/package:MyModel`, then to import this module in Swift you need to use
`import my_package_MyModel`. From Objective-C sources, you'd import the header
as `#import my/package/MyModel.h`.

This rule will also compile the `mlmodel` into an `mlmodelc` and propagate it
upstream so that it is packaged as a resource inside the top level bundle.

This rule currently only returns an ObjC interface since the Swift generated files do not have the
necessary public interfaces to export its symbols outside of the module.
""",
)
