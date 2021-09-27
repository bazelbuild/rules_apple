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

"""Implementation of the xcodeproj generation aspect."""

load("@build_bazel_rules_apple//apple:providers.bzl", "AppleBinaryInfo", "AppleBundleInfo", "IosApplicationBundleInfo", "IosExtensionBundleInfo")
load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

XCodeGenProviderInfo = provider()

# List of all the attributes that can be used to generate the xcodeproj.
_COMPILE_DEPS = [
    "app_clips",  # For ios_application which can include app clips.
    "bundles",
    "deps",
    "extension",
    "extensions",
    "frameworks",
    "settings_bundle",
    "srcs",  # To propagate down onto rules which generate source files.
    "tests",  # for test_suite when the --noexpand_test_suites flag is used.
    "test_host",
    "additional_contents",  # macos_application can specify a dict with supported rules as keys.
    "watch_application",
]

_DIRECT_DEPS = [
    "bundles",
    "deps",
    "extension",
    "extensions",
    "frameworks",
]

def _get_platform_type(ctx):
    """Return the current apple_common.platform_type as a string."""
    current_platform = (_get_obj_attr(ctx, "rule.attr.platform_type") or
                        _get_obj_attr(ctx, "rule.attr._platform_type"))
    if not current_platform:
        apple_frag = _get_obj_attr(ctx.fragments, "apple")
        current_platform = str(apple_frag.single_arch_platform.platform_type)
    return current_platform

def _get_deployment_info(target, ctx):
    """Returns (platform_type, minimum_os_version) for the given target."""
    if AppleBundleInfo in target:
        apple_bundle_provider = target[AppleBundleInfo]
        minimum_os_version = apple_bundle_provider.minimum_os_version
        platform_type = apple_bundle_provider.platform_type
        return (platform_type, minimum_os_version)

    attr_platform_type = _get_platform_type(ctx)
    return (attr_platform_type, _minimum_os_for_platform(ctx, attr_platform_type))

def _minimum_os_for_platform(ctx, platform_type_str):
    """Extracts the minimum OS version for the given apple_common.platform."""
    min_os = _get_obj_attr(ctx, "rule.attr.minimum_os_version")
    if min_os:
        return min_os

    platform_type = getattr(apple_common.platform_type, platform_type_str)
    min_os = (ctx.attr._xcode_config[apple_common.XcodeVersionConfig].minimum_os_for_platform_type(platform_type))

    if not min_os:
        return None

    # Convert the DottedVersion to a string suitable for inclusion in a struct.
    return str(min_os)

def _dict_omitting_none(**kwargs):
    """Creates a dict from the args, dropping keys with None or [] values."""
    return {
        name: kwargs[name]
        for name in kwargs
        # Starlark doesn't support "is"; comparison is explicit for correctness.
        # pylint: disable=g-equals-none,g-explicit-bool-comparison
        if kwargs[name] != None and kwargs[name] != []
    }

def _struct_omitting_none(**kwargs):
    """Creates a struct from the args, dropping keys with None or [] values."""
    return struct(**_dict_omitting_none(**kwargs))

def _get_obj_attr(obj, attr_path):
    attr_path = attr_path.split(".")
    for a in attr_path:
        if not obj or not hasattr(obj, a):
            return None
        obj = getattr(obj, a)
    return obj

def _getattr_as_list(obj, attr_path):
    val = _get_obj_attr(obj, attr_path)
    if not val:
        return []

    if type(val) == "list":
        return val
    elif type(val) == "dict":
        return val.keys()
    return [val]

def _is_file_external(f):
    """Returns True if the given file is an external file."""
    return f.owner.workspace_root != ""

def _file_path(f):
    prefix = "__BAZEL_WORKSPACE__"
    if not f.is_source:
        prefix = "__BAZEL_EXECROOT__"
    elif _is_file_external(f):
        prefix = "__BAZEL_OUTPUT_BASE__"
    return paths.join(prefix, f.path)

def _is_swift_target(target):
    """Returns whether a target is a Swift target"""
    if SwiftInfo not in target:
        return False

    # Containing a SwiftInfo provider is insufficient to determine whether a target is a Swift
    # target so check whether it contains at least one Swift direct module.
    for module in target[SwiftInfo].direct_modules:
        if module.swift != None:
            return True

    return False

def _collect_swift_modules(target):
    """Collect swift module if the target has any"""
    return [
        _file_path(module.swift.swiftmodule)
        for module in target[SwiftInfo].direct_modules
        if module.swift
    ]

def _sources_aspect(target, ctx):
    """Extract informations from a target and return the appropriate informations through a provider"""
    rule = ctx.rule
    target_kind = rule.kind

    srcs = [
        _file_path(f)
        for attr in ["srcs", "hdrs", "textual_hdrs"]
        for source in _getattr_as_list(rule.attr, attr)
        for f in _get_obj_attr(source, "files").to_list()
    ]
    direct_deps = [
        dep
        for attr in _DIRECT_DEPS
        for dep in _getattr_as_list(rule.attr, attr)
    ]
    transitive_deps = [dep[XCodeGenProviderInfo].transitive_deps for dep in direct_deps if XCodeGenProviderInfo in dep]

    # Collect bundle related information and Xcode version only for runnable targets.
    if AppleBundleInfo in target:
        apple_bundle_provider = target[AppleBundleInfo]

        bundle_name = apple_bundle_provider.bundle_name
        bundle_id = apple_bundle_provider.bundle_id
        product_type = apple_bundle_provider.product_type

        # We only need the infoplist from iOS extension targets.
        infoplist = apple_bundle_provider.infoplist if IosExtensionBundleInfo in target else None
    else:
        bundle_name = None
        product_type = None
        infoplist = None

        # For macos_command_line_application, which does not have a
        # AppleBundleInfo provider but does have a bundle_id attribute for use
        # in the Info.plist.
        if target_kind == "macos_command_line_application":
            bundle_id = _get_obj_attr(rule.attr, "bundle_id")
        else:
            bundle_id = None

    # Swift related metadata
    swift_modules = []
    swift_defines = []
    if _is_swift_target(target):
        swift_modules = _collect_swift_modules(target)

        # attributes["has_swift_info"] = True
        # swift_version = collect_swift_version(copts_attr) if is_swift_library else None
        # transitive_attributes["swift_language_version"] = swift_version
        # transitive_attributes["has_swift_dependency"] = True
        defines = {}
        for module in target[SwiftInfo].transitive_modules.to_list():
            swift_module = module.swift
            if swift_module and swift_module.defines:
                for x in swift_module.defines:
                    defines[x] = None
        swift_defines = defines.keys()

    platform_type, os_deployment_target = _get_deployment_info(target, ctx)
    xcode_version = str(ctx.attr._xcode_config[apple_common.XcodeVersionConfig].xcode_version())

    return [
        XCodeGenProviderInfo(
            bundle_name = bundle_name,
            bundle_id = bundle_id,
            infoplist = infoplist.path if infoplist else None,
            srcs = srcs,
            deps = direct_deps,
            transitive_deps = depset(direct_deps, transitive = transitive_deps),
            type = target_kind,
            platform_type = platform_type,
            product_type = product_type,
            os_deployment_target = os_deployment_target,
            xcode_version = xcode_version,
            swift_modules = swift_modules,
            swift_defines = swift_defines,
            label = str(target.label),
        ),
    ]

sources_aspect = aspect(
    attr_aspects = _COMPILE_DEPS,
    attrs = {
        "_xcode_config": attr.label(default = configuration_field(
            name = "xcode_config_label",
            fragment = "apple",
        )),
        "_cc_toolchain": attr.label(default = Label(
            "@bazel_tools//tools/cpp:current_cc_toolchain",
        )),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    incompatible_use_toolchain_transition = True,
    fragments = [
        "apple",
        "cpp",
        "objc",
    ],
    implementation = _sources_aspect,
)
