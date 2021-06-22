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
"""Reads tulsiinfo files generated by the Tulsi aspect, and output a JSON file
that can be read by xcodegen."""

import sys
import json
import os.path

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
SUPPORTED_EXTENSIONS = [
    ".swift",
    ".m",
    ".mm",
    ".h",
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

BAZEL_BUILD_SCRIPT = """\
set -euxo pipefail
cd $BAZEL_WORKSPACE_ROOT

export DATE_SUFFIX="$(date +%Y%m%d.%H%M%S%L)"
export BAZEL_BUILD_EVENT="$BUILD_DIR/build-event-$DATE_SUFFIX.json"

OPTIONS=(
    "--build_event_json_file=$BAZEL_BUILD_EVENT"
    "--build_event_json_file_path_conversion=no"
    "--build_event_publish_all_actions"
    "--use_top_level_targets_for_symlinks"
    "--features=swift.index_while_building"
)

if [ -n "${TARGET_DEVICE_IDENTIFIER:-}" ] && [ "$PLATFORM_NAME" = "iphoneos" ]; then
    echo "Builds with --ios_multi_cpus=arm64 since the target is an iOS device."
    OPTIONS+=("--ios_multi_cpus=arm64")
fi

# Generate a .app instead of .ipa
if [ "$PRODUCT_TYPE" = "com.apple.product-type.application" ]; then
    OPTIONS+=(
        "--define=apple.experimental.tree_artifact_outputs=1"
        "--define=apple.add_debugger_entitlement=1"
        "--define=apple.propagate_embedded_extra_outputs=1"
    )
fi

bazel build \
    "${OPTIONS[@]}" \
    $BAZEL_TARGET_LABEL

# Copy swiftmodule/swiftdoc if found
MODULES=`$PROJECT_FILE_PATH/bep swiftmodule $BAZEL_BUILD_EVENT | uniq || true`
if [[ ! -z $MODULES ]]; then
    for mod in $MODULES; do
        if [[ -f $mod ]]; then
            doc="${mod%.swiftmodule}.swiftdoc"
            framework="${mod%.swiftmodule}.framework"
            mod_name=$(basename "$mod")
            doc_name=$(basename "$doc")
            mod_bundle="$BUILT_PRODUCTS_DIR/$(basename "$framework")/Modules/$mod_name"
            mkdir -p "$mod_bundle"

            cp "$mod" "$mod_bundle/$ARCHS.swiftmodule"
            cp "$doc" "$mod_bundle/$ARCHS.swiftdoc"

            ios_mod_name="$ARCHS-$LLVM_TARGET_TRIPLE_VENDOR-$SWIFT_PLATFORM_TARGET_PREFIX$LLVM_TARGET_TRIPLE_SUFFIX"
            cp "$mod" "$mod_bundle/$ios_mod_name.swiftmodule"
            cp "$doc" "$mod_bundle/$ios_mod_name.swiftdoc"

            chmod -R +w "$mod_bundle"

            # also copy it in the build artifact as Xcode will ditto it into place,
            # so if we don't put them there, it will be replaced by empty files
            obj_norm="$OBJECT_FILE_DIR_normal/$ARCHS"
            mkdir -p "$obj_norm"
            if [[ ! -s "$obj_norm/$mod_name" ]]; then
                cp "$mod" "$obj_norm/$mod_name"
            fi
            if [[ ! -s "$obj_norm/$doc_name" ]]; then
                cp "$doc" "$obj_norm/$doc_name"
            fi
            chmod -R +w "$obj_norm"
        fi
    done
fi

# Example: /private/var/tmp/_bazel_<username>/<hash>/execroot/<workspacename>
readonly bazel_root="^/private/var/tmp/_bazel_.+?/.+?/execroot/[^/]+"
readonly bazel_bin="^(?:$bazel_root/)?bazel-out/.+?/bin"

# Object file paths are fundamental to how Xcode loads from the indexstore. If
# the `OutputFile` does not match what Xcode looks for, then those parts of the
# indexstore will not be found and used.
readonly bazel_swift_object="$bazel_bin/.*/(.+?)(?:_swift)?_objs/.*/(.+?)[.]swift[.]o$"
readonly bazel_objc_object="$bazel_bin/.*/_objs/(?:arc/|non_arc/)?(.+?)-(?:objc|cpp)/(.+?)[.]o$"
readonly xcode_object="$CONFIGURATION_TEMP_DIR/\$1.build/Objects-normal/$ARCHS/\$2.o"

# Bazel built `.swiftmodule` files are copied to `DerivedData`. Since modules
# are referenced by indexstores, their paths are remapped.
readonly bazel_module="$bazel_bin/.*/(.+?)[.]swiftmodule$"
readonly xcode_module="$BUILT_PRODUCTS_DIR/\$1.swiftmodule/$ARCHS.swiftmodule"

# External dependencies are available via the `bazel-<workspacename>` symlink.
# This remapping, in combination with `xcode-index-preferences.json`, enables
# index features for external dependencies, such as jump-to-definition.
readonly bazel_external="$bazel_root/external"
readonly xcode_external="$BAZEL_WORKSPACE_ROOT/bazel-$(basename "$BAZEL_WORKSPACE_ROOT")/external"

# Handle index stores
INDEXSTORES=`$PROJECT_FILE_PATH/bep indexstore $BAZEL_BUILD_EVENT | uniq || true`
if [[ ! -z $INDEXSTORES ]]; then
    for idx in $INDEXSTORES; do
        if [[ -e "$BAZEL_WORKSPACE_ROOT/$idx" ]]; then
            $PROJECT_FILE_PATH/index-import \
                -incremental \
                -remap "$bazel_module=$xcode_module" \
                -remap "$bazel_swift_object=$xcode_object" \
                -remap "$bazel_objc_object=$xcode_object" \
                -remap "$bazel_external=$xcode_external" \
                -remap "$bazel_root=$BAZEL_WORKSPACE_ROOT" \
                -remap "^([^//])=$BAZEL_WORKSPACE_ROOT/\$1" \
                "$BAZEL_WORKSPACE_ROOT/$idx" \
                "$BUILD_DIR"/../../Index/DataStore
        fi
    done
fi

# Copy the .app so it can be run
if [ "$PRODUCT_TYPE" = "com.apple.product-type.application" ]; then
    APP=`$PROJECT_FILE_PATH/bep directory_output $BAZEL_BUILD_EVENT`
    rm -rf "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
    cp -r "$BAZEL_WORKSPACE_ROOT/$APP" "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
    chmod -R u+w "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
fi

"""

COPY_DYNAMIC_FRAMEWORK = """\
set -euxo pipefail
cd $BAZEL_WORKSPACE_ROOT

TARGET={}
LABEL={}

# Need to bazel build in order for it to be linked in bazel sandbox
bazel build $LABEL

rm -rf $TARGET_BUILD_DIR/$(basename $TARGET)
cp -R bazel-$(basename $BAZEL_WORKSPACE_ROOT)/$TARGET $TARGET_BUILD_DIR/$(basename $TARGET)
"""

def _dict_ommit_none(**kwargs):
    return {k: v
            for k, v in kwargs.items()
            if v is not None}

def _file_extension(filename):
    _, ext = os.path.splitext(filename)
    return ext

def _normalize_targetname(name):
    if name.startswith("//"):
        name = name[2:]
    if name.startswith("@"):
        name = name[1:]
    return name.replace("/", "_").replace(":", "_")

def _transitive_deps(targets, deps):
    transitive = dict()
    for dep in deps:
        if dep not in targets:
            continue
        obj = targets[dep]
        if obj['type'] in SUPPORTED_TYPES:
            transitive[dep] = None
            target_deps = _transitive_deps(targets, obj.get('deps', []))
            transitive.update({k: None for k in target_deps})
    return transitive.keys()


def main(args):
    project_name = args[1]
    output_json = args[2]
    infoplist = args[3]
    json_files = args[4:]

    targets = dict()
    output = dict(
        name = project_name,
        #attributes = {},
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
                "BAZEL_WORKSPACE_DIR": "%%BWD%%", # this path is the BAZEL_WORKSPACE_ROOT/bazel-$(basename BAZEL_WORKSPACE_ROOT)
            },
            "configs": {
                "Debug": {
                    "GCC_PREPROCESSOR_DEFINITIONS": "DEBUG",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                },
            }
        },
        configs = {
            "Debug": "debug",
            "Release": "release",
        },
        schemes = {},
        targets = {},
    )

    for tinfo in json_files:
        if not tinfo.endswith(".tulsiinfo"):
            continue
        with open(tinfo, encoding="UTF-8") as json_file:
            try:
                obj = json.load(json_file)
                if obj['label'] in targets.keys():
                    raise Exception("already in the map")
                if obj['type'] in SUPPORTED_TYPES:
                    name = obj['label']
                    # normalize dependencies name
                    if 'deps' in obj:
                        obj['deps'] = [_normalize_targetname(dep) for dep in obj['deps']]
                    targets[_normalize_targetname(name)] = obj
            except Exception as e:
                print("Got exception for file {}: {}".format(tinfo, e))
                raise(e)

    for k, v in targets.items():
        typ = v['type']
        if typ == "ios_framework" or typ == "ios_application" or typ == "ios_extension":
            target_name = v['bundle_name']
        elif typ in ["apple_dynamic_framework_import", "apple_static_framework_import"]:
            target_name = k
        else:
            continue

        # sources come from the swift_library in dependencies
        sources = []
        dependencies = []
        objc_artifacts_paths = []

        transitive_deps = _transitive_deps(targets, v.get('deps', []))
        # take sources only from top level dependencies
        for dep in v.get('deps', []):
            if dep not in targets:
                continue
            obj = targets[dep]
            if obj['type'] == "swift_library":
                sources += [{"path": src['path'],
                            "optional": True,
                        } for src in obj.get('srcs', [])
                        if src['src'] and
                            _file_extension(src['path']) in SUPPORTED_EXTENSIONS
                            and not src['path'].startswith("external")]
        # Use transitive dependencies to create the proper dependencies
        for dep in transitive_deps:
            if dep not in targets:
                continue
            obj = targets[dep]
            if obj['type'] == "objc_library":
                # Find the artifact (.a) and use the path
                artifacts = [os.path.dirname(a['path']) for a in obj.get('artifacts', [])]
                if len(artifacts) == 1:
                    objc_artifacts_paths.append('"$BAZEL_WORKSPACE_ROOT/{}"'.format(artifacts[0]))
                # For good measure, also adds the includes
                objc_artifacts_paths += [
                    '"$BAZEL_WORKSPACE_DIR/{}"'.format(p) # BAZEL_WORKSPACE_DIR is the bazel-(projname) directory
                    for p in obj.get('includes', [])
                    if p != "."
                    and not p.startswith("bazel-tulsi-includes")
                ]
            if obj['type'] in ["ios_framework", "apple_dynamic_framework_import", "apple_static_framework_import"]:
                dependencies.append({"target": obj.get('bundle_name', dep), "embed": False})

        target_settings = {
            "PRODUCT_NAME": target_name,
            "MACH_O_TYPE": "staticlib" if v.get('product_type', '') == "framework" else "$(inherited)",
            "ONLY_ACTIVE_ARCH": "YES",
            "CLANG_ENABLE_MODULES": "YES",
            "CLANG_ENABLE_OBJ_ARC": "YES",
            "BAZEL_TARGET_LABEL": v['label'],
            "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited)",
            "HEADER_SEARCH_PATHS": " ".join(objc_artifacts_paths),
        }
        if typ == "ios_application":
            target_settings['PRODUCT_BUNDLE_IDENTIFIER'] = v['bundle_id']
            target_settings['INFOPLIST_FILE'] = "$BAZEL_WORKSPACE_ROOT/" + infoplist
        if typ == "ios_extension":
            target_settings['PRODUCT_BUNDLE_IDENTIFIER'] = v['bundle_id']
            target_settings['INFOPLIST_FILE'] = "$BAZEL_WORKSPACE_ROOT/" + v['infoplist']
        target = _dict_ommit_none(
            sources = sources, # sources will come from the swift_library in deps
            type = TYPES_CORRELATIONS[typ],
            platform = PLATFORM_TYPES[v['platform_type']],
            dependencies = dependencies,
            settings = target_settings,
            preBuildScripts = [_dict_ommit_none(
                name = "Build with Bazel",
                script = BAZEL_BUILD_SCRIPT,
            )],
            linking = _dict_ommit_none(
                embed = False,
                link = False,
                codeSign = False,
            ),
        )
        if typ in ["apple_dynamic_framework_import", "apple_static_framework_import"]:
            # this is a framework already built, we need to copy it to the Built directory
            target['preBuildScripts'] = [
                {"name": "Copy to built directory",
                 "script": COPY_DYNAMIC_FRAMEWORK.format(v['framework_imports'][0]['path'], v['label'])}
            ]
        if 'build_file' in v:
            target['sources'].append({
                "path": v['build_file'],
                "optional": True,
            })
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
                commandLineArguments = {},
                environmentVariables = {},
            ),
        )
        if 'os_deployment_target' in v:
            target['deploymentTarget'] = v['os_deployment_target']
        output['targets'][target_name] = target
        output['schemes'][target_name] = scheme

    with open(output_json, 'w') as output_file:
        json.dump(output, output_file)

if __name__ == "__main__":
    main(sys.argv)