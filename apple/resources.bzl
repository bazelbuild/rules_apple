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

load("@rules_cc//cc:defs.bzl", "objc_library")
load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_bundle_import.bzl",
    _apple_bundle_import = "apple_bundle_import",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_core_ml_library.bzl",
    _apple_core_ml_library = "apple_core_ml_library",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_rules:apple_intent_library.bzl",
    _apple_intent_library = "apple_intent_library",
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
    "@build_bazel_rules_apple//apple/internal/utils:modules.bzl",
    _modules = "modules",
)
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

apple_bundle_import = _apple_bundle_import
apple_resource_bundle = _apple_resource_bundle
apple_resource_group = _apple_resource_group
modules = _modules

# TODO(b/124103649): Create a proper rule when ObjC compilation is available in Starlark.
# TODO(rdar/48851150): Add support for Swift once the generator supports public interfaces.
def apple_core_ml_library(name, mlmodel, **kwargs):
    # buildifier: disable=function-docstring-args
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
    objc_library(
        name = name,
        srcs = [":{}.m".format(core_ml_name)],
        hdrs = [":{}".format(core_ml_name)],
        sdk_frameworks = ["CoreML"],
        data = [mlmodel],
        **kwargs
    )

def objc_intent_library(
    name,
    srcs,
    class_prefix = None,
    class_visibility = None,
    module_name = None,
    tags = None,
    testonly = False,
    visibility = None,
    language = None,
    swift_version = None,
    **kwargs):
    if not module_name:
        module_name = modules.derive_name(native.package_name(), name)
    intent_name = "{}.Intent".format(name)
    intent_srcs = "{}.srcs".format(intent_name)
    intent_hdrs = "{}.hdrs".format(intent_name)
    _apple_intent_library(
        name = intent_name,
        srcs = srcs,
        language = "Objective-C",
        class_prefix = class_prefix,
        module_name = module_name,
        tags = tags,
        testonly = testonly,
    )
    native.filegroup(
        name = intent_srcs,
        srcs = [intent_name],
        output_group = "srcs",
        tags = tags,
        testonly = testonly,
    )
    native.filegroup(
        name = intent_hdrs,
        srcs = [intent_name],
        output_group = "hdrs",
        tags = tags,
        testonly = testonly,
    )
    objc_library(
        name = name,
        srcs = [intent_srcs],
        hdrs = [intent_hdrs],
        includes = ["{}.hdrs.h".format(intent_name)],
        sdk_frameworks = ["Intents"],
        module_name = module_name,
        data = srcs,
        tags = tags,
        testonly = testonly,
        visibility = visibility,
    )

def swift_intent_library(
    name,
    srcs,
    class_prefix = None,
    class_visibility = None,
    module_name = None,
    swift_version = None,
    tags = None,
    testonly = False,
    visibility = None,
    language = None,
    **kwargs):
    if not module_name:
        module_name = modules.derive_name(native.package_name(), name)
    print("module_name", module_name)
    intent_name = "{}.Intent".format(name)
    _apple_intent_library(
        name = intent_name,
        srcs = srcs,
        language = "Swift",
        class_prefix = class_prefix,
        class_visibility = class_visibility,
        swift_version = swift_version,
        module_name = module_name,
        tags = tags,
        testonly = testonly,
    )
    swift_library(
        name = name,
        srcs = [intent_name],
        module_name = module_name,
        data = srcs,
        tags = tags,
        testonly = testonly,
        visibility = visibility,
        **kwargs,
    )
