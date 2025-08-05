# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Rules related to Apple resources and resource bundles."""

load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_bundle_import.bzl",
    _apple_bundle_import = "apple_bundle_import",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_core_ml_library.bzl",
    _apple_core_ml_library = "apple_core_ml_library",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_resource_bundle.bzl",
    _apple_resource_bundle = "apple_resource_bundle",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_resource_group.bzl",
    _apple_resource_group = "apple_resource_group",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_resource_locales.bzl",
    _apple_locale_from_unicode_locale = "apple_locale_from_unicode_locale",
    _apple_resource_locales = "apple_resource_locales",
)
load("@rules_cc//cc:objc_library.bzl", "objc_library")

visibility("public")

apple_bundle_import = _apple_bundle_import
apple_locale_from_unicode_locale = _apple_locale_from_unicode_locale
apple_resource_bundle = _apple_resource_bundle
apple_resource_group = _apple_resource_group
apple_resource_locales = _apple_resource_locales

# TODO(rdar/48851150): Add support for Swift once the generator supports public interfaces.
def _apple_core_ml_library_impl(name, mlmodel, **kwargs):
    # buildifier: disable=function-docstring-args
    """Macro to orchestrate an objc_library with generated sources for mlmodel files."""

    core_ml_name = "{}.CoreML".format(name)

    # Remove visibility from the internal target, to avoid misuse.
    core_ml_args = dict(kwargs)
    core_ml_args.pop("visibility", None)

    # This target creates an implicit <core_ml_name>.m file that can be referenced in the srcs of
    # the objc_library target below. Since this rule's outputs are the headers, we can set the hdrs
    # attribute to be this target and propagate the headers correctly upstream.
    _apple_core_ml_library(
        name = core_ml_name,
        mlmodel = mlmodel,
        header_name = name,
        visibility = ["//visibility:private"],
        **core_ml_args
    )

    objc_library(
        name = name,
        srcs = [":{}.m".format(core_ml_name)],
        hdrs = [":{}".format(core_ml_name)],
        sdk_frameworks = ["CoreML"],
        data = [mlmodel],
        **kwargs
    )

apple_core_ml_library = macro(
    implementation = _apple_core_ml_library_impl,
    inherit_attrs = "common",
    attrs = {
        "mlmodel": attr.label(
            allow_single_file = ["mlmodel"],
            configurable = False,
            mandatory = True,
            doc = """
A single `.mlmodel` file from which to generate sources and compile into mlmodelc files.
""",
        ),
    },
    doc = """
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
""",
)
