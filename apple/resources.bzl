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

apple_bundle_import = _apple_bundle_import
apple_resource_bundle = _apple_resource_bundle
apple_resource_group = _apple_resource_group

# TODO(b/124103649): Create a proper rule when ObjC compilation is available in Starlark.
# TODO(rdar/48851150): Add support for Swift once the generator supports public interfaces.
def apple_core_ml_library(name, mlmodel, **kwargs):
    """Macro to orchestrate an objc_library with generated sources for mlmodel files."""

    # List of allowed attributes for the apple_core_ml_library rule. Do not want to expose the
    # underlying objc_library attributes which might slow down migration once we're able to create a
    # proper rule.
    allowed_attributes = [
        "tags",
        "testonly",
        "visibility",
    ]

    for attr, _ in kwargs.items():
        if attr not in allowed_attributes:
            fail("Unknown attribute '{}' in rule 'apple_core_ml_library'".format(attr))

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

    native.objc_library(
        name = name,
        srcs = [":{}.m".format(core_ml_name)],
        hdrs = [":{}".format(core_ml_name)],
        sdk_frameworks = ["CoreML"],
        data = [mlmodel],
        **kwargs
    )
