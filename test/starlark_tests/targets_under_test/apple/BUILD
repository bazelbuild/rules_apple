load(
    "//apple:apple.bzl",
    "apple_dynamic_xcframework_import",
    "apple_static_xcframework",
    "apple_static_xcframework_import",
    "apple_universal_binary",
    "apple_xcframework",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)
load(
    "//apple:macos.bzl",
    "macos_bundle",
)
load(
    "//apple:resources.bzl",
    "apple_core_data_model",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

TARGETS_UNDER_TEST_TAGS = [
    "manual",
    "notap",
]

# This is a list of Apple targets to be used for Starlark unit tests. These may not build correctly
# since most of them do not have any source dependencies, so they are all tagged as manual and
# notap to avoid them being built/tested when testing the
# //test/... package.

apple_bundle_version(
    name = "manual_1_2_build_1_2_3_version",
    build_version = "1.2.3",
    short_version_string = "1.2",
    tags = TARGETS_UNDER_TEST_TAGS,
)

macos_bundle(
    name = "manual_1_2_build_1_2_3_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = "10.10",
    tags = TARGETS_UNDER_TEST_TAGS,
    version = ":manual_1_2_build_1_2_3_version",
)

apple_bundle_version(
    name = "only_build_version_1_2_3_version",
    build_version = "1.2.3",
    tags = TARGETS_UNDER_TEST_TAGS,
)

macos_bundle(
    name = "only_build_version_1_2_3_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = "10.10",
    tags = TARGETS_UNDER_TEST_TAGS,
    version = ":only_build_version_1_2_3_version",
)

apple_bundle_version(
    name = "build_label_substitution_from_fallback_label_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    capture_groups = {
        # Testing double-escaped regex format. Buildifier errors when using single "\" chars
        # that are not part of Buildifier's known escape sequences.
        "version": "\\d+\\.\\d+",
        "candidate": "\\d+",
    },
    fallback_build_label = "MyApp_99.99_RC99",
    short_version_string = "{version}",
    tags = TARGETS_UNDER_TEST_TAGS,
)

macos_bundle(
    name = "build_label_substitution_from_fallback_label_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = "10.10",
    tags = TARGETS_UNDER_TEST_TAGS,
    version = ":build_label_substitution_from_fallback_label_version",
)

apple_bundle_version(
    name = "short_version_string_defaults_to_build_version_substitution_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    capture_groups = {
        "version": "\\d+\\.\\d+",
        "candidate": "\\d+",
    },
    fallback_build_label = "MyApp_1.2_RC03",
    tags = TARGETS_UNDER_TEST_TAGS,
)

macos_bundle(
    name = "short_version_string_defaults_to_build_version_substitution_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = "10.10",
    tags = TARGETS_UNDER_TEST_TAGS,
    version = ":short_version_string_defaults_to_build_version_substitution_version",
)

apple_bundle_version(
    name = "pattern_referencing_missing_capture_groups_fail",
    build_label_pattern = "MyApp_{version}_RC00",
    build_version = "{version}.{candidate}",
    capture_groups = {
        "version": "\\d+",
    },
    fallback_build_label = "MyApp_1.2_RC03",
    tags = TARGETS_UNDER_TEST_TAGS,
)

apple_bundle_version(
    name = "build_label_pattern_requires_capture_groups_fail",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    fallback_build_label = "MyApp_1.2_RC03",
    tags = TARGETS_UNDER_TEST_TAGS,
)

apple_bundle_version(
    name = "capture_groups_requires_build_label_pattern_fail",
    build_version = "{version}.{candidate}",
    capture_groups = {
        "foo": "bar",
    },
    fallback_build_label = "MyApp_1.2_RC03",
    tags = TARGETS_UNDER_TEST_TAGS,
)

apple_bundle_version(
    name = "fallback_build_label_requires_build_label_pattern_fail",
    build_version = "1.2",
    fallback_build_label = "MyApp_1.2_RC03",
    tags = TARGETS_UNDER_TEST_TAGS,
)

apple_bundle_version(
    name = "no_substitution_if_build_label_not_present_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    capture_groups = {
        # Testing regex using [] character classes that don't need extra escaping.
        "version": "[0-9]+[.][0-9]+",
        "candidate": "[0-9]+",
    },
    short_version_string = "{version}",
    tags = TARGETS_UNDER_TEST_TAGS,
)

macos_bundle(
    name = "no_substitution_if_build_label_not_present_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = "10.10",
    tags = TARGETS_UNDER_TEST_TAGS,
    version = ":no_substitution_if_build_label_not_present_version",
)

apple_bundle_version(
    name = "build_label_pattern_does_not_short_circuit_literal_version",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "1.2.3",
    capture_groups = {
        "version": "[0-9]+[.][0-9]+",
        "candidate": "[0-9]+",
    },
    short_version_string = "1.2",
    tags = TARGETS_UNDER_TEST_TAGS,
)

macos_bundle(
    name = "build_label_pattern_does_not_short_circuit_literal_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = "10.10",
    tags = TARGETS_UNDER_TEST_TAGS,
    version = ":build_label_pattern_does_not_short_circuit_literal_version",
)

sh_binary(
    name = "ipa_post_processor_verify_codesigning",
    srcs = [
        "ipa_post_processor_verify_codesigning.sh",
    ],
    tags = ["requires-darwin"],
)

apple_core_data_model(
    name = "swift_data_model",
    srcs = [
        "//test/starlark_tests/resources:swift_datamodel",
    ],
)

apple_core_data_model(
    name = "objc_data_model",
    srcs = [
        "//test/starlark_tests/resources:objc_datamodel",
    ],
)

apple_core_data_model(
    name = "combined_swift_objc_data_model",
    srcs = [
        "//test/starlark_tests/resources:objc_datamodel",
        "//test/starlark_tests/resources:swift_datamodel",
    ],
)

apple_core_data_model(
    name = "no_code_generation_data_model",
    srcs = [
        "//test/starlark_tests/resources:no_code_generation_datamodel",
    ],
    tags = ["manual"],
)

objc_library(
    name = "fmwk_lib",
    srcs = [
        "//test/starlark_tests/resources:shared.h",
        "//test/starlark_tests/resources:shared.m",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
)

objc_library(
    name = "objc_lib_with_sdk_dylibs_and_sdk_framework",
    srcs = [
        "//test/starlark_tests/resources:shared.h",
        "//test/starlark_tests/resources:shared.m",
    ],
    linkopts = ["-lc++"],
    sdk_dylibs = ["libsqlite3"],
    sdk_frameworks = ["UIKit"],
    tags = TARGETS_UNDER_TEST_TAGS,
)

swift_library(
    name = "swift_lib_for_static_xcfmwk",
    srcs = ["DummyFmwk.swift"],
    module_name = "ios_static_xcfmwk_with_swift",
    tags = TARGETS_UNDER_TEST_TAGS,
)

swift_library(
    name = "swift_lib_for_static_xcfmwk_with_headers",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    module_name = "ios_static_xcfmwk_with_swift_generated_headers",
    tags = TARGETS_UNDER_TEST_TAGS,
)

swift_library(
    name = "swift_lib_for_static_xcfmwk_custom_bundle_name",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    module_name = "ios_static_xcfmwk_with_custom_bundle_name",
    tags = TARGETS_UNDER_TEST_TAGS,
)

swift_library(
    name = "swift_fmwk_lib",
    srcs = [
        "DummyFmwk.swift",
    ],
    module_name = "ios_dynamic_lipoed_swift_xcframework",
    tags = TARGETS_UNDER_TEST_TAGS,
)

apple_xcframework(
    name = "ios_dynamic_xcframework",
    bundle_id = "com.google.example",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

genrule(
    name = "generate_umbrella_header",
    outs = ["Umbrella.h"],
    cmd = 'echo "#import \\"shared.h\\"" > $(OUTS)',
)

apple_xcframework(
    name = "ios_dynamic_xcframework_umbrella_header",
    bundle_id = "com.google.example",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    umbrella_header = ":generate_umbrella_header",
    deps = [":fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_umbrella_header",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    umbrella_header = ":generate_umbrella_header",
    deps = [":fmwk_lib"],
)

# Generate importable dynamic XCFramework files
genrule(
    name = "generated_ios_dynamic_xcframework",
    testonly = 1,
    srcs = [":ios_dynamic_xcframework.xcframework.zip"],
    outs = ["ios_dynamic_xcframework.xcframework/Info.plist"] + [
        "{0}/{1}/{2}/{3}".format(
            "ios_dynamic_xcframework.xcframework",
            platform_id,
            "ios_dynamic_xcframework.framework",
            file,
        )
        for file in [
            "Headers/ios_dynamic_xcframework.h",
            "Headers/shared.h",
            "Modules/module.modulemap",
            "ios_dynamic_xcframework",
            "Info.plist",
        ]
        for platform_id in [
            "ios-arm64",
            "ios-x86_64-simulator",
        ]
    ],
    cmd = """
unzip -oqq $(execpath :ios_dynamic_xcframework.xcframework.zip) -d $(RULEDIR)
""",
)

# Generate importable static XCFramework files with static archives
genrule(
    name = "generated_ios_static_xcframework",
    testonly = 1,
    srcs = [":ios_static_xcframework.xcframework.zip"],
    outs = [
        "{0}/{1}/{2}".format(
            "ios_static_xcframework.xcframework",
            platform_id,
            file,
        )
        for (platform_id, platform) in [
            ("ios-arm64", "device"),
            ("ios-arm64_x86_64-simulator", "simulator"),
        ]
        for file in [
            "Headers/shared.h",
            "ios_static_xcframework.a",
        ]
    ],
    cmd = """
unzip -oqq $(execpath :ios_static_xcframework.xcframework.zip) -d $(RULEDIR)
""",
)

# Generate importable static XCFramework files with static archives and module
# map
genrule(
    name = "generated_ios_static_xcframework_with_module_map",
    testonly = 1,
    srcs = [":ios_static_xcframework_with_module_map.xcframework.zip"],
    outs = [
        "{0}/{1}/{2}".format(
            "ios_static_xcframework_with_module_map.xcframework",
            platform_id,
            file,
        )
        for (platform_id, platform) in [
            ("ios-arm64", "device"),
            ("ios-arm64_x86_64-simulator", "simulator"),
        ]
        for file in [
            "Headers/shared.h",
            "Modules/module.modulemap",
            "ios_static_xcframework_with_module_map.a",
        ]
    ],
    # rules_apple can't generate static XCFrameworks that are importable from
    # Swift now, but those exist. This manually generates one for testing.
    cmd = """
unzip -oqq $(execpath :ios_static_xcframework_with_module_map.xcframework.zip) -d $(RULEDIR)

xcframework_path="$(RULEDIR)/ios_static_xcframework_with_module_map.xcframework"
declare -a platform_ids=( ios-arm64 ios-arm64_x86_64-simulator )

for platform_id in "$${platform_ids[@]}"
do
  modules_dir="$$xcframework_path/$$platform_id/Modules"
  mkdir -p "$$modules_dir"
  cat > "$$modules_dir/module.modulemap" << EOF
module ios_static_xcframework_with_module_map {
  header "../Headers/shared.h"
}
EOF
done
""",
)

# rules_apple can't generate static XCFrameworks bundling static frameworks
# now. We manually generate one for testing.
genrule(
    name = "generated_ios_xcframework_bundling_static_fmwks",
    testonly = 1,
    srcs = [":ios_static_xcframework.xcframework.zip"],
    outs = [
        "{0}/{1}/{2}/{3}".format(
            "ios_xcframework_bundling_static_fmwks.xcframework",
            platform_id,
            "ios_xcframework_bundling_static_fmwks.framework",
            file,
        )
        for file in [
            "Headers/ios_static_xcframework.h",
            "Headers/shared.h",
            "Modules/module.modulemap",
            "ios_xcframework_bundling_static_fmwks",
        ]
        for platform_id in [
            "ios-arm64",
            "ios-arm64_x86_64-simulator",
        ]
    ],
    cmd = """
# Generating into a temporary directory, then rename and move it to RULEDIR to
# avoid having to create another source `apple_static_xcframework` testing
# target.
TEMP_DIR="$$(mktemp -d "$${TMPDIR:-/tmp}/generated_ios_xcframework_bundling_static_fmwks.XXXXXX")"
trap 'rm -rf "$${TEMP_DIR}"' ERR EXIT

xcframework_name="ios_xcframework_bundling_static_fmwks"
xcframework_dirname="$$xcframework_name.xcframework"
xcframework_path="$(RULEDIR)/$$xcframework_dirname"

# Bazel creates skeleton output directories before running actions, remote that
# in order to replace later.
rm -rf "$(RULEDIR)/$$xcframework_dirname"

unzip -qq "$(execpath :ios_static_xcframework.xcframework.zip)" -d "$$TEMP_DIR"
mv "$$TEMP_DIR/ios_static_xcframework.xcframework" "$$TEMP_DIR/$$xcframework_dirname"
mv "$$TEMP_DIR/$$xcframework_dirname" "$(RULEDIR)/"
# Some inner directories like Headers don't have the "w" permission
chmod -R u+w "$(RULEDIR)/$$xcframework_dirname"

declare -a platform_ids=( ios-arm64 ios-arm64_x86_64-simulator )

for platform_id in "$${platform_ids[@]}"
do
  platform_dir="$$xcframework_path/$$platform_id"
  framework_dir="$$platform_dir/$$xcframework_name.framework"
  mkdir -p "$$framework_dir"
  mv "$$platform_dir/ios_static_xcframework"*.a "$$framework_dir/$$xcframework_name"
  modules_dir="$$framework_dir/Modules"
  mkdir -p "$$modules_dir"
  mv "$$platform_dir/Headers/module.modulemap" "$$modules_dir/"
  sed -i "" "s/^module/framework module/g" "$$modules_dir/module.modulemap"
  mv "$$platform_dir/Headers" "$$framework_dir/"
done
""",
)

apple_dynamic_xcframework_import(
    name = "ios_imported_dynamic_xcframework",
    tags = ["manual"],
    xcframework_imports = [":generated_ios_dynamic_xcframework"],
)

apple_dynamic_xcframework_import(
    name = "ios_imported_dynamic_xcframework_with_lib_ids",
    library_identifiers = {
        "ios_device": "ios-arm64",
        "ios_simulator": "ios-x86_64-simulator",
    },
    tags = ["manual"],
    xcframework_imports = [":generated_ios_dynamic_xcframework"],
)

apple_static_xcframework_import(
    name = "ios_imported_static_xcframework",
    includes = ["Headers"],
    tags = ["manual"],
    xcframework_imports = [":generated_ios_static_xcframework"],
)

apple_static_xcframework_import(
    name = "ios_imported_static_xcframework_with_lib_ids",
    library_identifiers = {
        "ios_device": "ios-arm64",
        "ios_simulator": "ios-arm64_x86_64-simulator",
    },
    tags = ["manual"],
    xcframework_imports = [":generated_ios_static_xcframework"],
)

apple_static_xcframework_import(
    name = "ios_imported_xcframework_bundling_static_xcfmwks",
    tags = ["manual"],
    xcframework_imports = [":generated_ios_xcframework_bundling_static_fmwks"],
)

apple_static_xcframework_import(
    name = "ios_imported_static_xcframework_with_module_map",
    tags = ["manual"],
    xcframework_imports = [":generated_ios_static_xcframework_with_module_map"],
)

apple_xcframework(
    name = "ios_dynamic_lipoed_xcframework",
    bundle_id = "com.google.example",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "i386",
            "arm64",
            "x86_64",
        ],
        "device": [
            "armv7",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_lipoed_swift_xcframework",
    bundle_id = "com.google.example",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "arm64",
            "x86_64",
        ],
        "device": [
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": "10.0",
    },
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":swift_fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_min_ver_10",
    bundle_id = "com.google.example",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "10.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_exclusively_ipad_device_family",
    bundle_id = "com.google.example",
    families_required = {
        "ios": ["ipad"],
    },
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_multiple_infoplists",
    bundle_id = "com.google.example",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_data_resource_bundle",
    bundle_id = "com.google.example",
    data = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_deps_resource_bundle",
    bundle_id = "com.google.example",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [
        ":fmwk_lib",
        "//test/starlark_tests/resources:resource_bundle",
    ],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_stripped",
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    linkopts = ["-x"],
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_stripped_two_exported_symbols_lists",
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
        "//test/starlark_tests/resources:ExportDontCallMeShared.exp",
    ],
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    linkopts = ["-x"],
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_dead_stripped",
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    linkopts = ["-dead_strip"],
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_swift_xcframework_with_generated_header",
    bundle_id = "com.google.example",
    bundle_name = "SwiftFmwkWithGenHeader",
    framework_type = ["dynamic"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "arm64",
            "x86_64",
        ],
        "device": [
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":SwiftFmwkWithGenHeader"],
)

apple_static_xcframework(
    name = "ios_static_xcframework",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

# This doesn't actually generate an XCFramework with module maps (we manually
# add them later), but this needs to be a different name from the above target
# to avoid conflicts.
apple_static_xcframework(
    name = "ios_static_xcframework_with_module_map",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_with_avoid_deps",
    avoid_deps = [":StaticFmwkLowerLib"],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":StaticFmwkUpperLib"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks",
    ios = {
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":objc_lib_with_sdk_dylibs_and_sdk_framework"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_with_swift",
    ios = {
        "device": ["arm64"],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":swift_lib_for_static_xcfmwk"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_with_swift_and_bundle_name",
    bundle_name = "ios_static_xcfmwk_with_custom_bundle_name",
    ios = {
        "device": ["arm64"],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":swift_lib_for_static_xcfmwk_custom_bundle_name"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_with_swift_generated_headers",
    ios = {
        "device": ["arm64"],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": "8.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":swift_lib_for_static_xcfmwk_with_headers"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_min_os_12",
    ios = {
        "simulator": [
            "arm64",
            "x86_64",
        ],
        "device": [
            "arm64",
            "x86_64",
        ],
    },
    minimum_os_versions = {
        "ios": "12.0",
    },
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":fmwk_lib"],
)

genrule(
    name = "dummy_fmwk_objc_hdr",
    outs = ["DummyFmwk.h"],
    cmd = "echo '#ifndef SDK_FRAMEWORK_H_\n#define SDK_FRAMEWORK_H_\n void doStuff(); \n#endif\n// SDK_FRAMEWORK_H_' > $@",
)

genrule(
    name = "dummy_fmwk_objc_src",
    outs = ["DummyFmwk.m"],
    cmd = "echo '#import <Foundation/Foundation.h>\nvoid doStuff() { NSLog(@\"Framework method called\"); }' > $@",
)

genrule(
    name = "dummy_fmwk_swift_src",
    outs = ["DummyFmwk.swift"],
    cmd = "echo 'import Foundation\n@objc public class SharedClass: NSObject {\n@objc public func doSomethingShared() {\nNSLog(\"Doing something shared!\")\n}\n}\n' > $@",
)

genrule(
    name = "dummy_fmwk_dependent_objc_src",
    outs = ["DummyFmwkDependent.m"],
    cmd = "echo '#import <Foundation/Foundation.h>\nvoid frameworkDependent() { NSLog(@\"frameworkDependent() called\"); }' > $@",
)

objc_library(
    name = "StaticFmwkUpperLib",
    srcs = [
        "DummyFmwk.h",
        "DummyFmwk.m",
    ],
    tags = TARGETS_UNDER_TEST_TAGS,
    deps = [":StaticFmwkLowerLib"],
)

objc_library(
    name = "StaticFmwkLowerLib",
    srcs = ["DummyFmwkDependent.m"],
    tags = TARGETS_UNDER_TEST_TAGS,
)

swift_library(
    name = "SwiftFmwkWithGenHeader",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    module_name = "SwiftFmwkWithGenHeader",
    tags = TARGETS_UNDER_TEST_TAGS,
)

apple_universal_binary(
    name = "multi_arch_cc_binary",
    binary = "//test/starlark_tests/resources:cc_test_binary",
    minimum_os_version = "11.0",
    platform_type = "macos",
    tags = TARGETS_UNDER_TEST_TAGS,
)

apple_universal_binary(
    name = "multi_arch_forced_cpus_cc_binary",
    binary = "//test/starlark_tests/resources:cc_test_binary",
    forced_cpus = [
        "x86_64",
        "arm64",
    ],
    minimum_os_version = "11.0",
    platform_type = "macos",
    tags = TARGETS_UNDER_TEST_TAGS,
)
