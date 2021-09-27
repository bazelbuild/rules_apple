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

"""Exposes rules to generate a xcodeproj"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//apple/internal/aspects:xcodeproj_aspect.bzl", "XCodeGenProviderInfo", "sources_aspect")

ObjcInfo = apple_common.Objc

COPY_FILE_COMMAND = """\
for f in ${{@}}; do
    cat ${{f}} >> {out}
done
"""

SUPPORTED_EXTENSIONS = [
    ".swift",
    ".m",
    ".mm",
    ".h",
]
SUPPORTED_TYPES = [
    "objc_library",
    "swift_library",
    "cc_library",
    "ios_framework",
    "ios_extension",
    "ios_application",
    "apple_dynamic_framework_import",
    "apple_static_framework_import",
]
TYPES_CORRELATIONS = dict(
    objc_library = "library.static",
    swift_library = "library.static",
    cc_library = "library.static",
    ios_framework = "framework",
    ios_extension = "app-extension",
    ios_application = "application",
    apple_dynamic_framework_import = "framework",
    apple_static_framework_import = "framework",
)
PLATFORM_TYPES = dict(
    ios = "iOS",
    macos = "macOS",
)

def _dict_ommit_none(**kwargs):
    return {
        k: v
        for k, v in kwargs.items()
        if v != None
    }

def _compute_scheme_target(xcgi):
    if xcgi.type not in SUPPORTED_TYPES:
        return {}, {}

    normalized_name = _normalize_targetname(xcgi.label)
    typ = xcgi.type

    if typ not in ["ios_framework", "ios_application", "ios_extension", "apple_dynamic_framework_import", "apple_static_framework_import", "swift_library"]:
        return {}, {}

    target_name = normalized_name
    if typ == "ios_framework" or typ == "ios_application" or typ == "ios_extension":
        target_name = xcgi.bundle_name

    sources = [
        {"path": s, "optional": True}
        for s in xcgi.srcs
        if paths.split_extension(s)[1] in SUPPORTED_EXTENSIONS
    ]
    print(sources)

    objc_artifacts_paths = []
    target_settings = {
        "PRODUCT_NAME": normalized_name,
        "MACH_O_TYPE": "staticlib" if xcgi.product_type == "framework" else "$(inherited)",
        "ONLY_ACTIVE_ARCH": "YES",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJ_ARC": "YES",
        "BAZEL_TARGET_LABEL": normalized_name,
        "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited)",
        "HEADER_SEARCH_PATHS": " ".join(objc_artifacts_paths),
    }
    infoplist = ""  # TODO(zllak)
    if typ == "ios_application":
        target_settings["PRODUCT_BUNDLE_IDENTIFIER"] = xcgi.bundle_id
        target_settings["INFOPLIST_FILE"] = "$BAZEL_WORKSPACE_ROOT/" + infoplist
    if typ == "ios_extension":
        target_settings["PRODUCT_BUNDLE_IDENTIFIER"] = xcgi.bundle_id
        target_settings["INFOPLIST_FILE"] = "$BAZEL_WORKSPACE_ROOT/" + xcgi.infoplist
    target = _dict_ommit_none(
        sources = sources,  # sources will come from the swift_library in deps
        type = TYPES_CORRELATIONS[typ],
        platform = PLATFORM_TYPES[xcgi.platform_type],
        dependencies = None,
        settings = target_settings,
        preBuildScripts = [_dict_ommit_none(
            name = "Build with Bazel",
            #script = BAZEL_BUILD_SCRIPT,
            script = """""",
        )],
        linking = _dict_ommit_none(
            embed = False,
            link = False,
            codeSign = False,
        ),
        deploymentTarget = xcgi.os_deployment_target,
    )

    scheme = _dict_ommit_none(
        build = _dict_ommit_none(
            parallelizeBuild = False,
            buildImplicitDependencies = False,
            targets = {
                target_name: ["run", "test", "profile"],
            },
        ),
        run = _dict_ommit_none(
            targets = [target_name],
            customLLDBInit = None,
            #commandLineArguments = "",
            #environmentVariables = "",
        ),
    )

    return {target_name: scheme}, {target_name: target}

def _normalize_targetname(name):
    if name.startswith("//"):
        name = name[2:]
    if name.startswith("@"):
        name = name[1:]
    return name.replace("/", "_").replace(":", "_")

def _xcodeproj_impl(ctx):
    projname = (ctx.attr.project_name or ctx.attr.name)
    project_name = projname + ".xcodeproj/project.pbxproj"
    project_json_name = projname + ".json"
    project = ctx.actions.declare_file(project_name)
    json_xcodegen = ctx.actions.declare_file(project_json_name)

    clang_stub = ctx.actions.declare_file(projname + ".xcodeproj/clang-stub")
    ctx.actions.run_shell(
        inputs = ctx.files._clang_stub,
        outputs = [clang_stub],
        command = COPY_FILE_COMMAND.format(out = clang_stub.path),
        arguments = [f.path for f in ctx.files._clang_stub],
    )

    swiftc_stub = ctx.actions.declare_file(projname + ".xcodeproj/swiftc-stub")
    ctx.actions.run_shell(
        inputs = ctx.files._swiftc_stub,
        outputs = [swiftc_stub],
        command = COPY_FILE_COMMAND.format(out = swiftc_stub.path),
        arguments = [f.path for f in ctx.files._swiftc_stub],
    )

    ld_stub = ctx.actions.declare_file(projname + ".xcodeproj/ld-stub")
    ctx.actions.run_shell(
        inputs = ctx.files._ld_stub,
        outputs = [ld_stub],
        command = COPY_FILE_COMMAND.format(out = ld_stub.path),
        arguments = [f.path for f in ctx.files._ld_stub],
    )

    outputfilemap = ctx.actions.declare_file(projname + ".xcodeproj/outputfilemap")
    ctx.actions.run_shell(
        inputs = ctx.files._output_file_map,
        outputs = [outputfilemap],
        command = COPY_FILE_COMMAND.format(out = outputfilemap.path),
        arguments = [f.path for f in ctx.files._output_file_map],
    )

    index_import = ctx.actions.declare_file(projname + ".xcodeproj/index-import")
    ctx.actions.run_shell(
        inputs = [ctx.executable._index_import],
        outputs = [index_import],
        command = COPY_FILE_COMMAND.format(out = index_import.path),
        arguments = [ctx.executable._index_import.path],
    )

    bep = ctx.actions.declare_file(projname + ".xcodeproj/bep")
    ctx.actions.run_shell(
        inputs = ctx.files._bep,
        outputs = [bep],
        command = COPY_FILE_COMMAND.format(out = bep.path),
        arguments = [f.path for f in ctx.files._bep],
    )

    args = ctx.actions.args()
    args.add(ctx.attr.project_name or ctx.attr.name)
    args.add(json_xcodegen)
    inputs = []

    #################################
    # Handle aspect's provider info #
    #################################

    schemes = {}
    targets = {}
    for dep in ctx.attr.deps:
        if XCodeGenProviderInfo in dep:
            xcgi = dep[XCodeGenProviderInfo]
            sc, tg = _compute_scheme_target(xcgi)
            schemes.update(**sc)
            targets.update(**tg)
            for tdep in xcgi.transitive_deps.to_list():
                xcgi = tdep[XCodeGenProviderInfo]
                sc, tg = _compute_scheme_target(xcgi)
                schemes.update(**sc)
                targets.update(**tg)

    print(schemes)

    info = struct(
        name = ctx.attr.project_name,
        options = {
            "createIntermediateGroups": True,
            "defaultConfig": "Debug",
            "groupSortPosition": "none",
            "settingPresets": "none",
        },
        settings = {
            "base": {
                "CC": "$PROJECT_FILE_PATH/clang-stub",
                "CXX": "$CC",
                "CLANG_ANALYZER_EXEC": "$CC",
                "SWIFT_EXEC": "$PROJECT_FILE_PATH/swiftc-stub",
                "LD": "$PROJECT_FILE_PATH/ld-stub",
                "LIBTOOL": "/usr/bin/true",
                "OTHER_LDFLAGS": "-fuse-ld=$PROJECT_FILE_PATH/ld-stub",
                "USE_HEADERMAP": False,
                "CODE_SIGNING_ALLOWED": False,
                "DEBUG_INFORMATION_FORMAT": "dwarf",
                "DONT_RUN_SWIFT_STDLIB_TOOL": True,
                "SWIFT_OBJC_INTERFACE_HEADER_NAME": "",
                "SWIFT_VERSION": 5,
                "BAZEL_WORKSPACE_ROOT": "%%BWR%%",
                "BAZEL_WORKSPACE_DIR": "%%BWD%%",  # this path is the BAZEL_WORKSPACE_ROOT/bazel-$(basename BAZEL_WORKSPACE_ROOT)
            },
            "configs": {
                "Debug": {
                    "GCC_PREPROCESSOR_DEFINITIONS": "DEBUG",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                },
            },
        },
        configs = {
            "Debug": "debug",
            "Release": "release",
        },
        #schemes = schemes,
        schemes = _dict_ommit_none(
            Debug = _dict_ommit_none(
                build = _dict_ommit_none(
                    targets = _dict_ommit_none(
                        Zenly = "all",
                    ),
                ),
            ),
        ),
        targets = targets,
    )
    ctx.actions.write(json_xcodegen, info.to_json())

    # Call xcodegen with our JSON file
    args = ctx.actions.args()
    args.add_all([
        "--quiet",
        "--no-env",
        "--spec",
        json_xcodegen,
        "--project",
        paths.dirname(project.dirname),
    ])
    ctx.actions.run(
        executable = ctx.executable._xcodegen,
        arguments = [args],
        inputs = [json_xcodegen],
        outputs = [project],
    )

    # Create a runner script that will open with XCode
    runner = ctx.actions.declare_file("runner.sh")
    ctx.actions.write(
        output = runner,
        is_executable = True,
        content = """\
#!/bin/bash

cd $BUILD_WORKSPACE_DIRECTORY

PROJECT_PATH={}
BASE_PROJECT_PATH=$(basename $PROJECT_PATH)

# Sed the pbxproj so we can be outside the sandbox to run bazel
sed -i '' -e "s#%%BWR%%#${{BUILD_WORKSPACE_DIRECTORY}}#g" bazel-bin/$PROJECT_PATH/*.pbxproj
sed -i '' -e "s#%%BWD%%#${{BUILD_WORKSPACE_DIRECTORY}}/bazel-$(basename ${{BUILD_WORKSPACE_DIRECTORY}})#g" bazel-bin/$PROJECT_PATH/*.pbxproj

# Move out of the sandbox
rm -rf $BASE_PROJECT_PATH
cp -R bazel-bin/$PROJECT_PATH $BASE_PROJECT_PATH

open $BASE_PROJECT_PATH
""".format(paths.dirname(project.short_path)),
    )

    outfiles = [json_xcodegen, project, clang_stub, swiftc_stub, ld_stub, outputfilemap, index_import, bep]
    return [
        DefaultInfo(
            executable = runner,
            files = depset(outfiles),
            runfiles = ctx.runfiles(files = outfiles),
        ),
    ]

xcodeproj = rule(
    implementation = _xcodeproj_impl,
    doc = """\
    """,
    attrs = {
        "deps": attr.label_list(mandatory = True, allow_empty = False, providers = [], aspects = [sources_aspect]),
        "project_name": attr.string(mandatory = False),
        "_xcodegen": attr.label(executable = True, default = Label("@com_github_yonaskolb_xcodegen//:xcodegen"), cfg = "host"),
        "_clang_stub": attr.label(allow_single_file = ["sh"], default = Label("//tools/xcodeprojgen:clang-stub.sh"), cfg = "host"),
        "_swiftc_stub": attr.label(allow_single_file = ["sh"], default = Label("//tools/xcodeprojgen:swiftc-stub.sh"), cfg = "host"),
        "_ld_stub": attr.label(allow_single_file = ["sh"], default = Label("//tools/xcodeprojgen:ld-stub.sh"), cfg = "host"),
        "_output_file_map": attr.label(allow_single_file = ["py"], default = Label("//tools/xcodeprojgen:outputfilemap.py"), cfg = "host"),
        "_index_import": attr.label(executable = True, default = Label("@build_bazel_rules_swift_index_import//:index_import"), cfg = "host"),
        "_bep": attr.label(allow_single_file = ["py"], default = Label("//tools/xcodeprojgen:bep.py"), cfg = "host"),
    },
    executable = True,
)

## Copyright 2018 The Bazel Authors. All rights reserved.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
#"""Reads tulsiinfo files generated by the Tulsi aspect, and output a JSON file
#that can be read by xcodegen."""
#
#
#BAZEL_BUILD_SCRIPT = """\
#set -euxo pipefail
#cd $BAZEL_WORKSPACE_ROOT
#
#export DATE_SUFFIX="$(date +%Y%m%d.%H%M%S%L)"
#export BAZEL_BUILD_EVENT="$BUILD_DIR/build-event-$DATE_SUFFIX.json"
#
#OPTIONS=(
#    "--build_event_json_file=$BAZEL_BUILD_EVENT"
#    "--build_event_json_file_path_conversion=no"
#    "--build_event_publish_all_actions"
#    "--use_top_level_targets_for_symlinks"
#    "--features=swift.index_while_building"
#)
#
#if [ -n "${TARGET_DEVICE_IDENTIFIER:-}" ] && [ "$PLATFORM_NAME" = "iphoneos" ]; then
#    echo "Builds with --ios_multi_cpus=arm64 since the target is an iOS device."
#    OPTIONS+=("--ios_multi_cpus=arm64")
#fi
#
## Generate a .app instead of .ipa
#if [ "$PRODUCT_TYPE" = "com.apple.product-type.application" ]; then
#    OPTIONS+=(
#        "--define=apple.experimental.tree_artifact_outputs=1"
#        "--define=apple.add_debugger_entitlement=1"
#        "--define=apple.propagate_embedded_extra_outputs=1"
#    )
#fi
#
#bazel build \
#    "${OPTIONS[@]}" \
#    $BAZEL_TARGET_LABEL
#
## Copy swiftmodule/swiftdoc if found
#MODULES=`$PROJECT_FILE_PATH/bep swiftmodule $BAZEL_BUILD_EVENT | uniq || true`
#if [[ ! -z $MODULES ]]; then
#    for mod in $MODULES; do
#        if [[ -f $mod ]]; then
#            doc="${mod%.swiftmodule}.swiftdoc"
#            framework="${mod%.swiftmodule}.framework"
#            mod_name=$(basename "$mod")
#            doc_name=$(basename "$doc")
#            mod_bundle="$BUILT_PRODUCTS_DIR/$(basename "$framework")/Modules/$mod_name"
#            mkdir -p "$mod_bundle"
#
#            cp "$mod" "$mod_bundle/$ARCHS.swiftmodule"
#            cp "$doc" "$mod_bundle/$ARCHS.swiftdoc"
#
#            ios_mod_name="$ARCHS-$LLVM_TARGET_TRIPLE_VENDOR-$SWIFT_PLATFORM_TARGET_PREFIX$LLVM_TARGET_TRIPLE_SUFFIX"
#            cp "$mod" "$mod_bundle/$ios_mod_name.swiftmodule"
#            cp "$doc" "$mod_bundle/$ios_mod_name.swiftdoc"
#
#            chmod -R +w "$mod_bundle"
#
#            # also copy it in the build artifact as Xcode will ditto it into place,
#            # so if we don't put them there, it will be replaced by empty files
#            obj_norm="$OBJECT_FILE_DIR_normal/$ARCHS"
#            mkdir -p "$obj_norm"
#            if [[ ! -s "$obj_norm/$mod_name" ]]; then
#                cp "$mod" "$obj_norm/$mod_name"
#            fi
#            if [[ ! -s "$obj_norm/$doc_name" ]]; then
#                cp "$doc" "$obj_norm/$doc_name"
#            fi
#            chmod -R +w "$obj_norm"
#        fi
#    done
#fi
#
## Example: /private/var/tmp/_bazel_<username>/<hash>/execroot/<workspacename>
#readonly bazel_root="^/private/var/tmp/_bazel_.+?/.+?/execroot/[^/]+"
#readonly bazel_bin="^(?:$bazel_root/)?bazel-out/.+?/bin"
#
## Object file paths are fundamental to how Xcode loads from the indexstore. If
## the `OutputFile` does not match what Xcode looks for, then those parts of the
## indexstore will not be found and used.
#readonly bazel_swift_object="$bazel_bin/.*/(.+?)(?:_swift)?_objs/.*/(.+?)[.]swift[.]o$"
#readonly bazel_objc_object="$bazel_bin/.*/_objs/(?:arc/|non_arc/)?(.+?)-(?:objc|cpp)/(.+?)[.]o$"
#readonly xcode_object="$CONFIGURATION_TEMP_DIR/\$1.build/Objects-normal/$ARCHS/\$2.o"
#
## Bazel built `.swiftmodule` files are copied to `DerivedData`. Since modules
## are referenced by indexstores, their paths are remapped.
#readonly bazel_module="$bazel_bin/.*/(.+?)[.]swiftmodule$"
#readonly xcode_module="$BUILT_PRODUCTS_DIR/\$1.swiftmodule/$ARCHS.swiftmodule"
#
## External dependencies are available via the `bazel-<workspacename>` symlink.
## This remapping, in combination with `xcode-index-preferences.json`, enables
## index features for external dependencies, such as jump-to-definition.
#readonly bazel_external="$bazel_root/external"
#readonly xcode_external="$BAZEL_WORKSPACE_ROOT/bazel-$(basename "$BAZEL_WORKSPACE_ROOT")/external"
#
## Handle index stores
#INDEXSTORES=`$PROJECT_FILE_PATH/bep indexstore $BAZEL_BUILD_EVENT | uniq || true`
#if [[ ! -z $INDEXSTORES ]]; then
#    for idx in $INDEXSTORES; do
#        if [[ -e "$BAZEL_WORKSPACE_ROOT/$idx" ]]; then
#            $PROJECT_FILE_PATH/index-import \
#                -incremental \
#                -remap "$bazel_module=$xcode_module" \
#                -remap "$bazel_swift_object=$xcode_object" \
#                -remap "$bazel_objc_object=$xcode_object" \
#                -remap "$bazel_external=$xcode_external" \
#                -remap "$bazel_root=$BAZEL_WORKSPACE_ROOT" \
#                -remap "^([^//])=$BAZEL_WORKSPACE_ROOT/\$1" \
#                "$BAZEL_WORKSPACE_ROOT/$idx" \
#                "$BUILD_DIR"/../../Index/DataStore
#        fi
#    done
#fi
#
## Copy the .app so it can be run
#if [ "$PRODUCT_TYPE" = "com.apple.product-type.application" ]; then
#    APP=`$PROJECT_FILE_PATH/bep directory_output $BAZEL_BUILD_EVENT`
#    rm -rf "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
#    cp -r "$BAZEL_WORKSPACE_ROOT/$APP" "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
#    chmod -R u+w "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
#fi
#
#"""
#
#COPY_DYNAMIC_FRAMEWORK = """\
#set -euxo pipefail
#cd $BAZEL_WORKSPACE_ROOT
#
#TARGET={}
#LABEL={}
#
## Need to bazel build in order for it to be linked in bazel sandbox
#bazel build $LABEL
#
#rm -rf $TARGET_BUILD_DIR/$(basename $TARGET)
#cp -R bazel-$(basename $BAZEL_WORKSPACE_ROOT)/$TARGET $TARGET_BUILD_DIR/$(basename $TARGET)
#"""
#
#
#
#def _normalize_targetname(name):
#    if name.startswith("//"):
#        name = name[2:]
#    if name.startswith("@"):
#        name = name[1:]
#    return name.replace("/", "_").replace(":", "_")
#
#def _transitive_deps(targets, deps):
#    transitive = dict()
#    for dep in deps:
#        if dep not in targets:
#            continue
#        obj = targets[dep]
#        if obj['type'] in SUPPORTED_TYPES:
#            transitive[dep] = None
#            target_deps = _transitive_deps(targets, obj.get('deps', []))
#            transitive.update({k: None for k in target_deps})
#    return transitive.keys()
#
#
#def main(args):
#    project_name = args[1]
#    output_json = args[2]
#    infoplist = args[3]
#    json_files = args[4:]
#
#    targets = dict()
#    output = dict(
#        name = project_name,
#        #attributes = {},
#        options = {
#            "createIntermediateGroups": True,
#            "defaultConfig": "Debug",
#            "groupSortPosition": "none",
#            "settingPresets": "none",
#        },
#        settings = {
#            "base": {
#                "CC": "$PROJECT_FILE_PATH/clang-stub",
#                "CXX": "$CC",
#                "CLANG_ANALYZER_EXEC": "$CC",
#                "SWIFT_EXEC": "$PROJECT_FILE_PATH/swiftc-stub",
#                "LD": "$PROJECT_FILE_PATH/ld-stub",
#                "LIBTOOL": "/usr/bin/true",
#                "OTHER_LDFLAGS": "-fuse-ld=$PROJECT_FILE_PATH/ld-stub",
#                "USE_HEADERMAP": False,
#                "CODE_SIGNING_ALLOWED": False,
#                "DEBUG_INFORMATION_FORMAT": "dwarf",
#                "DONT_RUN_SWIFT_STDLIB_TOOL": True,
#                "SWIFT_OBJC_INTERFACE_HEADER_NAME": "",
#                "SWIFT_VERSION": 5,
#                "BAZEL_WORKSPACE_ROOT": "%%BWR%%",
#                "BAZEL_WORKSPACE_DIR": "%%BWD%%", # this path is the BAZEL_WORKSPACE_ROOT/bazel-$(basename BAZEL_WORKSPACE_ROOT)
#            },
#            "configs": {
#                "Debug": {
#                    "GCC_PREPROCESSOR_DEFINITIONS": "DEBUG",
#                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
#                },
#            }
#        },
#        configs = {
#            "Debug": "debug",
#            "Release": "release",
#        },
#        schemes = {},
#        targets = {},
#    )
#
#    for tinfo in json_files:
#        if not tinfo.endswith(".tulsiinfo"):
#            continue
#        with open(tinfo, encoding="UTF-8") as json_file:
#            try:
#                obj = json.load(json_file)
#                if obj['label'] in targets.keys():
#                    raise Exception("already in the map")
#                if obj['type'] in SUPPORTED_TYPES:
#                    name = obj['label']
#                    # normalize dependencies name
#                    if 'deps' in obj:
#                        obj['deps'] = [_normalize_targetname(dep) for dep in obj['deps']]
#                    targets[_normalize_targetname(name)] = obj
#            except Exception as e:
#                print("Got exception for file {}: {}".format(tinfo, e))
#                raise(e)
#
#    for k, v in targets.items():
#        typ = v['type']
#        if typ == "ios_framework" or typ == "ios_application" or typ == "ios_extension":
#            target_name = v['bundle_name']
#        elif typ in ["apple_dynamic_framework_import", "apple_static_framework_import"]:
#            target_name = k
#        else:
#            continue
#
#        # sources come from the swift_library in dependencies
#        sources = []
#        dependencies = []
#        objc_artifacts_paths = []
#
#        transitive_deps = _transitive_deps(targets, v.get('deps', []))
#        # take sources only from top level dependencies
#        for dep in v.get('deps', []):
#            if dep not in targets:
#                continue
#            obj = targets[dep]
#            if obj['type'] == "swift_library":
#                sources += [{"path": src['path'],
#                            "optional": True,
#                        } for src in obj.get('srcs', [])
#                        if src['src'] and
#                            _file_extension(src['path']) in SUPPORTED_EXTENSIONS
#                            and not src['path'].startswith("external")]
#        # Use transitive dependencies to create the proper dependencies
#        for dep in transitive_deps:
#            if dep not in targets:
#                continue
#            obj = targets[dep]
#            if obj['type'] == "objc_library":
#                # Find the artifact (.a) and use the path
#                artifacts = [os.path.dirname(a['path']) for a in obj.get('artifacts', [])]
#                if len(artifacts) == 1:
#                    objc_artifacts_paths.append('"$BAZEL_WORKSPACE_ROOT/{}"'.format(artifacts[0]))
#                # For good measure, also adds the includes
#                objc_artifacts_paths += [
#                    '"$BAZEL_WORKSPACE_DIR/{}"'.format(p) # BAZEL_WORKSPACE_DIR is the bazel-(projname) directory
#                    for p in obj.get('includes', [])
#                    if p != "."
#                    and not p.startswith("bazel-tulsi-includes")
#                ]
#            if obj['type'] in ["ios_framework", "apple_dynamic_framework_import", "apple_static_framework_import"]:
#                dependencies.append({"target": obj.get('bundle_name', dep), "embed": False})
#
#        target_settings = {
#            "PRODUCT_NAME": target_name,
#            "MACH_O_TYPE": "staticlib" if v.get('product_type', '') == "framework" else "$(inherited)",
#            "ONLY_ACTIVE_ARCH": "YES",
#            "CLANG_ENABLE_MODULES": "YES",
#            "CLANG_ENABLE_OBJ_ARC": "YES",
#            "BAZEL_TARGET_LABEL": v['label'],
#            "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited)",
#            "HEADER_SEARCH_PATHS": " ".join(objc_artifacts_paths),
#        }
#        if typ == "ios_application":
#            target_settings['PRODUCT_BUNDLE_IDENTIFIER'] = v['bundle_id']
#            target_settings['INFOPLIST_FILE'] = "$BAZEL_WORKSPACE_ROOT/" + infoplist
#        if typ == "ios_extension":
#            target_settings['PRODUCT_BUNDLE_IDENTIFIER'] = v['bundle_id']
#            target_settings['INFOPLIST_FILE'] = "$BAZEL_WORKSPACE_ROOT/" + v['infoplist']
#        target = _dict_ommit_none(
#            sources = sources, # sources will come from the swift_library in deps
#            type = TYPES_CORRELATIONS[typ],
#            platform = PLATFORM_TYPES[v['platform_type']],
#            dependencies = dependencies,
#            settings = target_settings,
#            preBuildScripts = [_dict_ommit_none(
#                name = "Build with Bazel",
#                script = BAZEL_BUILD_SCRIPT,
#            )],
#            linking = _dict_ommit_none(
#                embed = False,
#                link = False,
#                codeSign = False,
#            ),
#        )
#        if typ in ["apple_dynamic_framework_import", "apple_static_framework_import"]:
#            # this is a framework already built, we need to copy it to the Built directory
#            target['preBuildScripts'] = [
#                {"name": "Copy to built directory",
#                 "script": COPY_DYNAMIC_FRAMEWORK.format(v['framework_imports'][0]['path'], v['label'])}
#            ]
#        if 'build_file' in v:
#            target['sources'].append({
#                "path": v['build_file'],
#                "optional": True,
#            })
#        scheme = _dict_ommit_none(
#            build = _dict_ommit_none(
#                parallelizeBuild = False,
#                buildImplicitDependencies = False,
#                targets = {
#                    target_name: ["run", "test", "profile"],
#                },
#            ),
#            run = _dict_ommit_none(
#                targets = [target_name],
#                customLLDBInit = None,
#                commandLineArguments = {},
#                environmentVariables = {},
#            ),
#        )
#        if 'os_deployment_target' in v:
#            target['deploymentTarget'] = v['os_deployment_target']
#        output['targets'][target_name] = target
#        output['schemes'][target_name] = scheme
#
#    with open(output_json, 'w') as output_file:
#        json.dump(output, output_file)
#
#if __name__ == "__main__":
#    main(sys.argv)
