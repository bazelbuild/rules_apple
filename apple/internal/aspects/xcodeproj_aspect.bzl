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

load("@build_bazel_rules_apple//apple:providers.bzl", "AppleBundleInfo", "AppleResourceInfo")
load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

XcodeGenTargetInfo = provider()

_RESOURCES_FIELDS = [
    "alternate_icons",
    "asset_catalogs",
    "datamodels",
    "infoplists",
    "metals",
    "mlmodels",
    "plists",
    "pngs",
    "processed",
    "storyboards",
    "strings",
    "texture_atlases",
    "unprocessed",
    "xibs",
]

_RESOURCES_SPECIAL_SLUGS = [
    ".lproj/",
    ".xcassets/",
    ".atlas/",
]

# List of all the attributes that can be used to generate the xcodeproj.
_COMPILE_DEPS = [
    # "app_clips",  # For ios_application which can include app clips.
    "bundles",
    "deps",
    "private_deps",
    "extension",
    "extensions",
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

_RULES_TO_TARGET_TYPES = dict(
    objc_library = "library.static",
    swift_library = "library.static",
    cc_library = "library.static",
    swift_c_module = "library.static",
    swift_module_alias = "library.static",
    ios_framework = "framework",
    ios_extension = "app-extension",
    ios_application = "application",
    ios_imessage_extension = "app-extension",  # TODO(zllak): not sure here
    apple_dynamic_framework_import = "framework",
    apple_static_framework_import = "framework",
)

_SOURCE_ATTRS = ["srcs", "hdrs", "textual_hdrs"]

_PLATFORM_TYPES = dict(
    ios = "iOS",
    macos = "macOS",
)

def _platform_type_for_type(typ):
    return _PLATFORM_TYPES[typ]

_INDEX_IMPORT_SCRIPT_PREAMBLE = """\
readonly bazel_root="^/private/var/tmp/_bazel_.+?/.+?/execroot/[^/]+"
readonly bazel_bin="^(?:$bazel_root/)?bazel-out/.+?/bin"
readonly bazel_swift_object="$bazel_bin/.*/(.+?)(?:_swift)?_objs/.*/(.+?)[.]swift[.]o$"
readonly bazel_objc_object="$bazel_bin/.*/_objs/(?:arc/|non_arc/)?(.+?)-(?:objc|cpp)/(.+?)[.]o$"
readonly xcode_object="$CONFIGURATION_TEMP_DIR/\\$1.build/Objects-normal/$ARCHS/\\$2.o"
readonly bazel_module="$bazel_bin/.*/(.+?)[.]swiftmodule$"
readonly xcode_module="$BUILT_PRODUCTS_DIR/\\$1.swiftmodule/$ARCHS.swiftmodule"
readonly bazel_external="$bazel_root/external"
readonly xcode_external="$BAZEL_WORKSPACE/bazel-$(basename "$BAZEL_WORKSPACE")/external"
"""

_INDEX_IMPORT_SCRIPT = """\
$INDEX_IMPORT \
    -incremental \
    -remap "$bazel_module=$xcode_module" \
    -remap "$bazel_swift_object=$xcode_object" \
    -remap "$bazel_objc_object=$xcode_object" \
    -remap "$bazel_external=$xcode_external" \
    -remap "$bazel_root=$BAZEL_WORKSPACE" \
    -remap "^([^//])=$BAZEL_WORKSPACE/\\$1" \
    "{indexstore}" \
    "$BUILD_DIR/../../Index/DataStore" || true
"""

def _index_import(indexstore):
    return _INDEX_IMPORT_SCRIPT.format(
        indexstore = _file_bazel_path(indexstore, prefix = "$"),
    )

_COPY_SWIFT_MODULE_SCRIPT = """\
rm -rf $BUILT_PRODUCTS_DIR/{module_name}.swiftmodule
mkdir -p $BUILT_PRODUCTS_DIR/{module_name}.swiftmodule
cp -c "{swiftmodule}" "$BUILT_PRODUCTS_DIR/{module_name}.swiftmodule/$ARCHS.swiftmodule"
cp -c "{swiftdoc}" "$BUILT_PRODUCTS_DIR/{module_name}.swiftmodule/$ARCHS.swiftdoc"
"""

def _copy_swift_module(module):
    return _COPY_SWIFT_MODULE_SCRIPT.format(
        module_name = module.name,
        swiftmodule = _file_bazel_path(module.swift.swiftmodule, prefix = "$"),
        swiftdoc = _file_bazel_path(module.swift.swiftdoc, prefix = "$"),
    )

_BAZEL_BUILD_SCRIPT = """\
set -euxo pipefail
cd $BAZEL_WORKSPACE

OPTIONS=(
    "--define=apple.experimental.tree_artifact_outputs=1"
    "--define=apple.add_debugger_entitlement=1"
    "--features=swift.index_while_building"
    "--features=swift.disable_system_index"
    "--aspects=@build_bazel_rules_apple//apple/internal/aspects:xcodeproj_aspect.bzl%sources_aspect"
    "--output_groups=archive,swift_modules,swift_index_store,index_import,module_maps"
)

if [ -n "${TARGET_DEVICE_IDENTIFIER:-}" ] && [ "$PLATFORM_NAME" = "iphoneos" ]; then
    echo "Builds with --ios_multi_cpus=arm64 since the target is an iOS device."
    OPTIONS+=("--ios_multi_cpus=arm64")
fi

bazel build "${OPTIONS[@]}" $BAZEL_TARGET_LABEL
"""

_COPY_APP_SCRIPT = """\
set -euxo pipefail
rm -rf "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
cp -rc "{app}" "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
chmod -R u+w "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
"""

_CREATE_LLDB_INIT = """\
cat > $BAZEL_LLDB_INIT_FILE <<-END
platform settings -w "$BAZEL_WORKSPACE/"
settings set target.sdk-path $SDKROOT
settings set target.swift-framework-search-paths $FRAMEWORK_SEARCH_PATHS
settings set target.source-map ./bazel-out/ "$BAZEL_EXECROOT/bazel-out/"
settings append target.source-map ./external/ "$BAZEL_OUTPUT_BASE/external/"
settings append target.source-map ./ "$BAZEL_WORKSPACE/"
END

LLDB_SWIFT_EXTRA_CLANG_FLAGS=()
if [[ "$CONFIGURATION" = "Debug" ]]; then
  LLDB_SWIFT_EXTRA_CLANG_FLAGS+=(" -D DEBUG")
fi

if [[ ${#LLDB_SWIFT_EXTRA_CLANG_FLAGS[@]} -ne 0 ]]; then
  cat >> $BAZEL_LLDB_INIT_FILE <<-END
settings set -- target.swift-extra-clang-flags ${LLDB_SWIFT_EXTRA_CLANG_FLAGS[@]}
END
fi
"""

def _file_extension(f):
    _, ext = paths.split_extension(f)
    return ext

def _normalize_targetname(name):
    if name.startswith("//"):
        name = name[2:]
    if name.startswith("@"):
        name = name[1:]
    return name.replace("/", "_").replace(":", "_")

def _should_include_file(f):
    return f.is_source and not _is_file_external(f)

def _collect_sources(rule):
    return depset(transitive = [
        src.files
        for attr in _SOURCE_ATTRS
        for src in getattr(rule.attr, attr, [])
    ])

def _collect_resources(target):
    if AppleResourceInfo not in target:
        return depset([])
    ari = target[AppleResourceInfo]
    return depset(transitive = [
        files
        for field in _RESOURCES_FIELDS
        for _, _, files in getattr(ari, field, [])
    ])

def _collect_swift_modules(target):
    return depset([
        module.swift
        for module in target[SwiftInfo].direct_modules
        if module.swift
    ])

def _depset_paths(ds, map_each = None):
    return [
        map_each(f) if map_each else f.path
        for f in ds.to_list()
        if _should_include_file(f)
    ]

def _collect_transitive_deps(target, ctx):
    deps = [
        dep[XcodeGenTargetInfo]
        for attr in _DIRECT_DEPS
        for dep in getattr(ctx.rule.attr, attr, [])
        if XcodeGenTargetInfo in dep
    ]
    return depset(
        direct = deps,
        transitive = [
            dep.transitive_deps
            for dep in deps
        ],
    )

def _is_file_external(f):
    """Returns True if the given file is an external file."""
    return f.owner.workspace_root != ""

def _file_bazel_path(f, prefix = "", suffix = ""):
    bazel_dir = "BAZEL_WORKSPACE"
    if not f.is_source:
        bazel_dir = "BAZEL_EXECROOT"
    elif _is_file_external(f):
        bazel_dir = "BAZEL_OUTPUT_BASE"
    return paths.join(prefix + bazel_dir + suffix, f.path)

def _string_bazel_path(path, prefix = "", suffix = ""):
    bazel_dir = "BAZEL_WORKSPACE"
    if path.startswith("bazel-out/"):
        bazel_dir = "BAZEL_EXECROOT"
    if path.startswith("external/"):
        bazel_dir = "BAZEL_OUTPUT_BASE"
    return paths.join(prefix + bazel_dir + suffix, path)

def _rule_to_target_type(rule):
    return _RULES_TO_TARGET_TYPES[rule.kind]

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

def _get_obj_attr(obj, attr_path):
    attr_path = attr_path.split(".")
    for a in attr_path:
        if not obj or not hasattr(obj, a):
            return None
        obj = getattr(obj, a)
    return obj

def _collect_objc_strict_includes(target, rule_attr):
    """Returns a depset of strict includes found on the deps of given target."""
    depsets = []
    for dep in rule_attr.deps:
        if apple_common.Objc in dep:
            objc = dep[apple_common.Objc]
            if hasattr(objc, "strict_include"):
                depsets.append(objc.strict_include)
    return depset(transitive = depsets)

def _xcodegen_file_optional(f):
    return f.path

def _string_upto(s, upto):
    idx = s.find(upto)
    if idx > 0:
        return s[:idx + len(upto)]
    return s

def _resource_path(f):
    for slug in _RESOURCES_SPECIAL_SLUGS:
        if slug in f.path:
            return _string_upto(f.path, slug)
    return f.path

def _module_map_search_path(path):
    for p in [".modulemaps/", ".framework/Modules/"]:
        idx = path.find(p)
        if idx >= 0:
            return paths.dirname(path[:idx])
    return path

def _module_map_search_paths(target):
    if apple_common.Objc in target:
        return depset([
            _module_map_search_path(module_map.path)
            for module_map in target[apple_common.Objc].module_map.to_list()
        ])
    return None

def _header_search_paths(target):
    includes = []
    if CcInfo in target:
        cc_ctx = target[CcInfo].compilation_context
        includes = [
            cc_ctx.includes,
            cc_ctx.quote_includes,
            cc_ctx.system_includes,
        ]
    if apple_common.Objc in target:
        includes.append(target[apple_common.Objc].strict_include)
    return depset(transitive = includes)

def _frameworks_search_path(target):
    if CcInfo in target:
        return target[CcInfo].compilation_context.framework_includes
    return None

def _expand_search_paths(search_paths):
    return " ".join([
        _string_bazel_path(sp, prefix = "$")
        for sp in search_paths.to_list()
        if sp != "."
    ])

def _module_map_flag(module_map):
    return "-fmodule-map-file={}".format(_file_bazel_path(module_map, prefix = "$"))

def _module_map_flags(module_maps):
    return [
        _module_map_flag(mm)
        for mm in module_maps.to_list()
    ]

def _swift_cflags(flags):
    return [
        "-Xcc {}".format(flag)
        for flag in flags
    ]

def _collect_module_infos(target):
    defines = depset([])
    swift_defines = []
    module_maps = []
    includes = []
    framework_includes = []

    if SwiftInfo in target:
        for module in target[SwiftInfo].transitive_modules.to_list():
            if module.swift:
                swift_defines.extend(module.swift.defines)
            if module.clang:
                if module.clang.module_map:
                    module_maps.append(module.clang.module_map)
                cc_ctx = module.clang.compilation_context
                defines = cc_ctx.defines
                framework_includes.append(cc_ctx.framework_includes)
                includes.extend([
                    cc_ctx.includes,
                    cc_ctx.quote_includes,
                    cc_ctx.system_includes,
                ])
        return struct(
            defines = defines,
            swift_defines = depset(swift_defines),
            module_maps = depset(module_maps),
            framework_includes = depset(transitive = framework_includes),
            includes = depset(transitive = includes),
        )

    module_maps = depset([])
    includes = []
    framework_includes = depset([])
    if CcInfo in target:
        cc_ctx = target[CcInfo].compilation_context
        framework_includes = cc_ctx.framework_includes
        includes = [
            cc_ctx.includes,
            cc_ctx.quote_includes,
            cc_ctx.system_includes,
        ]
    if apple_common.Objc in target:
        objc_info = target[apple_common.Objc]
        includes.append(objc_info.strict_include)
        module_maps = objc_info.module_map

    return struct(
        module_maps = module_maps,
        framework_includes = framework_includes,
        includes = depset(transitive = includes),
    )

def _copts(rule):
    if hasattr(rule.attr, "copts"):
        return rule.attr.copts
    return []

def _swift_library_to_target(target, ctx):
    name = _normalize_targetname(str(target.label))
    sources = _collect_sources(ctx.rule)

    apple_frag = _get_obj_attr(ctx.fragments, "apple")
    current_platform = str(apple_frag.single_arch_platform.platform_type)

    modules = _collect_module_infos(target)
    return [
        XcodeGenTargetInfo(
            label = target.label,
            name = name,
            kind = ctx.rule.kind,
            srcs = sources,
            swift = struct(
                indexstore = getattr(target[OutputGroupInfo], "swift_index_store", None),
                modules = target[SwiftInfo].direct_modules,
            ),
            target = _make_target(
                target,
                ctx,
                sources = _depset_paths(sources, map_each = _xcodegen_file_optional) + [
                    {"path": ctx.build_file_path, "optional": True},
                ],
                settings = dict(
                    base = {
                        "PRODUCT_NAME": name,
                        "MACH_O_TYPE": "staticlib",
                        "ONLY_ACTIVE_ARCH": "YES",
                        "CLANG_ENABLE_MODULES": "YES",
                        "CLANG_ENABLE_OBJ_ARC": "YES",
                        "BAZEL_TARGET_LABEL": str(target.label),
                        "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited)",
                        "HEADER_SEARCH_PATHS": _expand_search_paths(modules.includes),
                        "FRAMEWORK_SEARCH_PATHS": _expand_search_paths(modules.framework_includes),
                        "OTHER_SWIFT_FLAGS": " ".join(
                            _copts(ctx.rule) +
                            _swift_cflags(_module_map_flags(modules.module_maps)),
                        ),
                    },
                ),
            ),
            transitive_deps = _collect_transitive_deps(target, ctx),
        ),
    ]

def _objc_library_to_target(target, ctx):
    name = _normalize_targetname(str(target.label))
    sources = _collect_sources(ctx.rule)

    modules = _collect_module_infos(target)
    return [
        XcodeGenTargetInfo(
            name = name,
            kind = ctx.rule.kind,
            srcs = sources,
            target = _make_target(
                target,
                ctx,
                sources = _depset_paths(sources, map_each = _xcodegen_file_optional) + [
                    {"path": ctx.build_file_path, "optional": True},
                ],
                settings = dict(
                    base = {
                        "PRODUCT_NAME": name,
                        "MACH_O_TYPE": "staticlib",
                        "BAZEL_TARGET_LABEL": str(target.label),
                        "HEADER_SEARCH_PATHS": _expand_search_paths(modules.includes),
                        "FRAMEWORK_SEARCH_PATHS": _expand_search_paths(modules.framework_includes),
                        "OTHER_CFLAGS": " ".join(
                            _copts(ctx.rule) +
                            _module_map_flags(modules.module_maps),
                        ),
                    },
                ),
            ),
            transitive_deps = _collect_transitive_deps(target, ctx),
        ),
    ]

def _make_target(target, ctx, **kwargs):
    platform_type, os_deployment_target = _get_deployment_info(target, ctx)
    platform = _platform_type_for_type(platform_type)
    ret = dict(
        type = _rule_to_target_type(ctx.rule),
        platform = platform,
        deploymentTarget = {
            platform: os_deployment_target,
        },
    )
    ret.update(kwargs)
    return ret

def _bundle_to_target(target, ctx):
    abi = target[AppleBundleInfo]
    typ = _rule_to_target_type(ctx.rule)

    resources = _collect_resources(target)

    scheme = None
    custom_lldb_init = "$CONFIGURATION_TEMP_DIR/{}.lldbinit".format(abi.bundle_name)
    if ctx.rule.kind in ["ios_application"]:
        scheme = dict(
            build = dict(
                parallelizeBuild = False,
                buildImplicitDependencies = False,
                targets = {
                    abi.bundle_name: ["build", "run", "profile", "analyze"],
                },
            ),
            run = dict(
                targets = [abi.bundle_name],
                customLLDBInit = custom_lldb_init,
                commandLineArguments = {},
                environmentVariables = {},
            ),
        )

    swift_indexstores = []
    import_index_command = [
        "set -euxo pipefail",
        _INDEX_IMPORT_SCRIPT_PREAMBLE,
    ]
    swift_modules = []
    copy_modules_command = [
        "set -euxo pipefail",
    ]

    module_maps = []
    deps = _collect_transitive_deps(target, ctx)
    for dep in deps.to_list():
        if hasattr(dep, "module_maps"):
            module_maps.append(dep.module_maps)
        if hasattr(dep, "swift"):
            if dep.swift.indexstore:
                swift_indexstores.append(dep.swift.indexstore)
                for indexstore in dep.swift.indexstore.to_list():
                    import_index_command.append(_index_import(indexstore))
            for module in dep.swift.modules:
                if module.swift:
                    swift_modules.append(module.swift.swiftmodule)
                    swift_modules.append(module.swift.swiftdoc)
                    copy_modules_command.append(_copy_swift_module(module))

    resources_paths = depset(_depset_paths(resources, map_each = _resource_path))
    return [
        XcodeGenTargetInfo(
            name = abi.bundle_name,
            kind = ctx.rule.kind,
            srcs = resources,
            target = _make_target(
                target,
                ctx,
                sources = resources_paths.to_list(),
                settings = dict(
                    base = {
                        "PRODUCT_NAME": abi.bundle_name,
                        "BAZEL_TARGET_LABEL": str(target.label),
                        "BAZEL_LLDB_INIT_FILE": custom_lldb_init,
                        "PRODUCT_BUNDLE_IDENTIFIER": abi.bundle_id,
                    },
                ),
                preBuildScripts = [
                    dict(
                        name = "bazel build {}".format(str(target.label)),
                        shell = "/bin/bash",
                        script = _BAZEL_BUILD_SCRIPT,
                    ),
                    dict(
                        name = "Copy modules",
                        shell = "/bin/bash",
                        script = "\n".join(copy_modules_command),
                    ),
                    dict(
                        name = "Import index",
                        shell = "/bin/bash",
                        script = "\n".join(import_index_command),
                    ),
                    dict(
                        name = "Copy Bundle to Destination",
                        shell = "/bin/bash",
                        script = _COPY_APP_SCRIPT.format(
                            app = _file_bazel_path(abi.archive, prefix = "$"),
                        ),
                    ),
                    dict(
                        name = "Create LLDB Init",
                        shell = "/bin/bash",
                        script = _CREATE_LLDB_INIT,
                    ),
                ],
                linking = dict(
                    embed = False,
                    link = False,
                    codeSign = False,
                ),
            ),
            scheme = scheme,
            transitive_deps = deps,
        ),
        OutputGroupInfo(
            archive = depset([abi.archive]),
            swift_index_store = depset(transitive = swift_indexstores),
            index_import = depset(ctx.files._index_import),
            swift_modules = depset(swift_modules),
            module_maps = depset(transitive = module_maps),
        ),
    ]

def _apple_framework_import_to_target(target, ctx):
    return [
        XcodeGenTargetInfo(
            name = _normalize_targetname(str(target.label)),
            kind = ctx.rule.kind,
            srcs = depset([]),
            target = _make_target(target, ctx),
            transitive_deps = _collect_transitive_deps(target, ctx),
        ),
    ]

def _sources_aspect(target, ctx):
    """Extract informations from a target and return the appropriate informations through a provider"""

    if SwiftInfo in target:
        return _swift_library_to_target(target, ctx)
    elif ctx.rule.kind in ["objc_library", "cc_library"]:
        return _objc_library_to_target(target, ctx)
    elif ctx.rule.kind in ["apple_dynamic_framework_import", "apple_static_framework_import"]:
        return _apple_framework_import_to_target(target, ctx)
    elif AppleBundleInfo in target:
        return _bundle_to_target(target, ctx)

    return []

sources_aspect = aspect(
    attr_aspects = _COMPILE_DEPS,
    attrs = {
        "_xcode_config": attr.label(default = configuration_field(
            name = "xcode_config_label",
            fragment = "apple",
        )),
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
        ),
        "_index_import": attr.label(
            default = "@build_bazel_rules_swift_index_import//:index_import",
            executable = True,
            cfg = "host",
            allow_single_file = True,
        ),
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
