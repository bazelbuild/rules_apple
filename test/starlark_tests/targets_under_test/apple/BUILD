load(
    "//apple:apple.bzl",
    "apple_dynamic_framework_import",
    "apple_dynamic_xcframework_import",
    "apple_static_framework_import",
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
load(
    "//test/starlark_tests:common.bzl",
    "common",
)
load(
    "//test/testdata/rules:dummy_test_runner.bzl",
    "dummy_test_runner",
)

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

# This is a list of Apple targets to be used for Starlark unit tests. These may not build correctly
# since most of them do not have any source dependencies, so they are all tagged as manual and
# notap to avoid them being built/tested when testing the
# //test/... package.

apple_bundle_version(
    name = "manual_1_2_build_1_2_3_version",
    build_version = "1.2.3",
    short_version_string = "1.2",
    tags = common.fixture_tags,
)

macos_bundle(
    name = "manual_1_2_build_1_2_3_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.baseline,
    tags = common.fixture_tags,
    version = ":manual_1_2_build_1_2_3_version",
)

apple_bundle_version(
    name = "only_build_version_1_2_3_version",
    build_version = "1.2.3",
    tags = common.fixture_tags,
)

macos_bundle(
    name = "only_build_version_1_2_3_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.baseline,
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
)

macos_bundle(
    name = "build_label_substitution_from_fallback_label_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.baseline,
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
)

macos_bundle(
    name = "short_version_string_defaults_to_build_version_substitution_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.baseline,
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
)

apple_bundle_version(
    name = "build_label_pattern_requires_capture_groups_fail",
    build_label_pattern = "MyApp_{version}_RC0*{candidate}",
    build_version = "{version}.{candidate}",
    fallback_build_label = "MyApp_1.2_RC03",
    tags = common.fixture_tags,
)

apple_bundle_version(
    name = "capture_groups_requires_build_label_pattern_fail",
    build_version = "{version}.{candidate}",
    capture_groups = {
        "foo": "bar",
    },
    fallback_build_label = "MyApp_1.2_RC03",
    tags = common.fixture_tags,
)

apple_bundle_version(
    name = "fallback_build_label_requires_build_label_pattern_fail",
    build_version = "1.2",
    fallback_build_label = "MyApp_1.2_RC03",
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
)

macos_bundle(
    name = "no_substitution_if_build_label_not_present_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.baseline,
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
)

macos_bundle(
    name = "build_label_pattern_does_not_short_circuit_literal_bundle",
    bundle_id = "com.google.example",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.baseline,
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_for_static_xcfmwk",
    srcs = ["DummyFmwk.swift"],
    module_name = "ios_static_xcfmwk_with_swift",
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_for_static_xcfmwk_with_headers",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    module_name = "ios_static_xcfmwk_with_swift_generated_headers",
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_for_static_xcfmwk_custom_bundle_name",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    module_name = "ios_static_xcfmwk_with_custom_bundle_name",
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_fmwk_lib",
    srcs = [
        "DummyFmwk.swift",
    ],
    module_name = "ios_dynamic_lipoed_swift_xcframework",
    tags = common.fixture_tags,
)

dummy_test_runner(
    name = "dummy_test_runner",
)

apple_xcframework(
    name = "ios_dynamic_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
        "ios": "9.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
    ] + ["ios_static_xcframework.xcframework/Info.plist"],
    cmd = """
unzip -oqq $(execpath :ios_static_xcframework.xcframework.zip) -d $(RULEDIR)
TEMP_DIR="$$(mktemp -d "$${TMPDIR:-/tmp}/xcframework_test_dir.XXXXXX")"
trap 'rm -rf "$${TEMP_DIR}"' ERR EXIT

xcframework_name="ios_static_xcframework"
xcframework_dirname="$$xcframework_name.xcframework"
xcframework_path="$(RULEDIR)/$$xcframework_dirname"

# Bazel creates skeleton output directories before running actions, remote that
# in order to replace later.
rm -rf "$(RULEDIR)/$$xcframework_dirname"

unzip -oqq "$(execpath :ios_static_xcframework.xcframework.zip)" -d "$$TEMP_DIR"
mv "$$TEMP_DIR/$$xcframework_dirname" "$(RULEDIR)/$$xcframework_dirname"
# Some inner directories like Headers don't have the "w" permission
chmod -R u+w "$(RULEDIR)/$$xcframework_dirname"
touch "$(RULEDIR)/$$xcframework_dirname"/Info.plist

declare -a platform_ids=( ios-arm64 ios-arm64_x86_64-simulator )

for platform_id in "$${platform_ids[@]}"
do
  mv "$(RULEDIR)/$$xcframework_dirname/$$platform_id/$$xcframework_name.framework/$$xcframework_name" "$(RULEDIR)/$$xcframework_dirname/$$platform_id/$$xcframework_name.a"
  mv "$(RULEDIR)/$$xcframework_dirname/$$platform_id/$$xcframework_name.framework/Headers" "$(RULEDIR)/$$xcframework_dirname/$$platform_id/"
  mv "$(RULEDIR)/$$xcframework_dirname/$$platform_id/$$xcframework_name.framework/Modules/module.modulemap" "$(RULEDIR)/$$xcframework_dirname/$$platform_id/Headers"
done
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
    ] + ["ios_static_xcframework_with_module_map.xcframework/Info.plist"],
    # rules_apple can't generate static XCFrameworks that are importable from
    # Swift now, but those exist. This manually generates one for testing.
    cmd = """
unzip -oqq $(execpath :ios_static_xcframework_with_module_map.xcframework.zip) -d $(RULEDIR)

xcframework_path="$(RULEDIR)/ios_static_xcframework_with_module_map.xcframework"
declare -a platform_ids=( ios-arm64 ios-arm64_x86_64-simulator )
touch "$$xcframework_path/Info.plist"

for platform_id in "$${platform_ids[@]}"
do
  modules_dir="$$xcframework_path/$$platform_id/Modules"
  mkdir -p "$$modules_dir"
  mv "$$xcframework_path/$$platform_id/ios_static_xcframework_with_module_map.framework/ios_static_xcframework_with_module_map" "$$xcframework_path/$$platform_id/ios_static_xcframework_with_module_map.a"
  mv "$$xcframework_path/$$platform_id/ios_static_xcframework_with_module_map.framework/Headers" "$$xcframework_path/$$platform_id/"
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
    srcs = [":ios_xcframework_bundling_static_fmwks.xcframework.zip"],
    outs = [
        "{0}/{1}/{2}/{3}".format(
            "ios_xcframework_bundling_static_fmwks.xcframework",
            platform_id,
            "ios_xcframework_bundling_static_fmwks.framework",
            file,
        )
        for file in [
            "Headers/ios_xcframework_bundling_static_fmwks.h",
            "Headers/shared.h",
            "Modules/module.modulemap",
            "ios_xcframework_bundling_static_fmwks",
        ]
        for platform_id in [
            "ios-arm64",
            "ios-arm64_x86_64-simulator",
        ]
    ] + ["ios_xcframework_bundling_static_fmwks.xcframework/Info.plist"],
    cmd = """
unzip -oqq $(execpath :ios_xcframework_bundling_static_fmwks.xcframework.zip) -d $(RULEDIR)
""",
)

apple_dynamic_xcframework_import(
    name = "ios_imported_dynamic_xcframework_old",
    tags = ["manual"],
    xcframework_imports = [":generated_ios_dynamic_xcframework"],
)

apple_dynamic_xcframework_import(
    name = "ios_imported_dynamic_xcframework_bundle_only",
    bundle_only = True,
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
    name = "ios_imported_static_xcframework_old",
    includes = ["Headers"],
    sdk_dylibs = [
        "z",
        "libc++",
    ],
    sdk_frameworks = ["AVFoundation"],
    tags = ["manual"],
    weak_sdk_frameworks = ["SwiftUI"],
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
            "arm64e",
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_lipoed_swift_xcframework",
    bundle_id = "com.google.example",
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
        "ios": common.min_os_ios.baseline,
    },
    tags = common.fixture_tags,
    deps = [":swift_fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_exclusively_ipad_device_family",
    bundle_id = "com.google.example",
    families_required = {
        "ios": ["ipad"],
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_multiple_infoplists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_data_resource_bundle",
    bundle_id = "com.google.example",
    data = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_deps_resource_bundle",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    linkopts = ["-x"],
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_stripped_two_exported_symbols_lists",
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
        "//test/starlark_tests/resources:ExportDontCallMeShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    linkopts = ["-x"],
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_dead_stripped",
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    linkopts = ["-dead_strip"],
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_xcframework(
    name = "ios_swift_xcframework_with_generated_header",
    bundle_id = "com.google.example",
    bundle_name = "SwiftFmwkWithGenHeader",
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
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":SwiftFmwkWithGenHeader"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_umbrella_header_conflict",
    bundle_id = "com.google.example",
    bundle_name = "UmbrellaHeaderConflict",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
        "//test/starlark_tests/resources:UmbrellaHeaderConflict.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_oldest_supported",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.oldest_supported,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib"],
)

objc_library(
    name = "fmwk_lib_with_resources",
    srcs = [
        "//test/starlark_tests/resources:shared.h",
        "//test/starlark_tests/resources:shared.m",
    ],
    data = ["//test/starlark_tests/resources:resource_bundle"],
    tags = common.fixture_tags,
)

apple_static_xcframework(
    name = "ios_static_xcframework_with_resources",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "9.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":fmwk_lib_with_resources"],
)

genrule(
    name = "generated_ios_static_xcframework_with_resources",
    testonly = 1,
    srcs = [":ios_static_xcframework_with_resources.xcframework.zip"],
    outs = [
        "{0}/{1}/{2}/{3}".format(
            "ios_static_xcframework_with_resources.xcframework",
            platform_id,
            "ios_static_xcframework_with_resources.framework",
            file,
        )
        for file in [
            "Headers/ios_static_xcframework_with_resources.h",
            "Headers/shared.h",
            "Modules/module.modulemap",
            "ios_static_xcframework_with_resources",
            "resource_bundle.bundle/custom_apple_resource_info.out",
            "resource_bundle.bundle/Info.plist",
        ]
        for platform_id in [
            "ios-arm64",
            "ios-arm64_x86_64-simulator",
        ]
    ] + ["ios_static_xcframework_with_resources.xcframework/Info.plist"],
    cmd = """
unzip -oqq $(execpath :ios_static_xcframework_with_resources.xcframework.zip) -d $(RULEDIR)
""",
)

apple_static_xcframework_import(
    name = "ios_static_xcframework_with_resources_import",
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = [":generated_ios_static_xcframework_with_resources"],
)

apple_static_xcframework_import(
    name = "ios_static_xcframework_with_resources_and_data",
    data = [
        "//test/starlark_tests/resources:localized_xibs_ios",
        "//test/starlark_tests/resources:sample.png",
    ],
    tags = ["manual"],
    xcframework_imports = [":generated_ios_static_xcframework_with_resources"],
)

apple_static_xcframework(
    name = "ios_xcframework_bundling_static_fmwks",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": "9.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
        "ios": "9.0",
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
        "ios": common.min_os_ios.baseline,
    },
    tags = common.fixture_tags,
    deps = [":StaticFmwkUpperLib"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks",
    ios = {
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
        "ios": common.min_os_ios.baseline,
    },
    tags = common.fixture_tags,
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
        "ios": common.min_os_ios.baseline,
    },
    tags = common.fixture_tags,
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
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [":swift_lib_for_static_xcfmwk_with_headers"],
)

apple_static_xcframework(
    name = "ios_static_xcframework",
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
        "ios": common.min_os_ios.baseline,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
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
    name = "dummy_fmwk_cc_src",
    outs = ["DummyFmwk.c"],
    cmd = "echo '#include <stdio.h>\nvoid doStuff() { printf(\"Framework method called\\n\"); }' > $@",
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

genrule(
    name = "dummy_fmwk_dependent_cc_src",
    outs = ["DummyFmwkDependent.c"],
    cmd = "echo '#include <stdio.h>\nvoid frameworkDependent() { printf(\"frameworkDependent() called\\n\"); }' > $@",
)

objc_library(
    name = "StaticFmwkUpperLib",
    srcs = [
        "DummyFmwk.h",
        "DummyFmwk.m",
    ],
    tags = common.fixture_tags,
    deps = [":StaticFmwkLowerLib"],
)

objc_library(
    name = "StaticFmwkCcUpperLib",
    srcs = [
        "DummyFmwk.c",
        "DummyFmwk.h",
    ],
    tags = common.fixture_tags,
    deps = [":StaticFmwkCcLowerLib"],
)

objc_library(
    name = "StaticFmwkLowerLib",
    srcs = ["DummyFmwkDependent.m"],
    tags = common.fixture_tags,
)

cc_library(
    name = "StaticFmwkCcLowerLib",
    srcs = ["DummyFmwkDependent.c"],
    tags = common.fixture_tags,
)

swift_library(
    name = "SwiftFmwkWithGenHeader",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    module_name = "SwiftFmwkWithGenHeader",
    tags = common.fixture_tags,
)

apple_universal_binary(
    name = "multi_arch_cc_binary",
    binary = "//test/starlark_tests/resources:cc_test_binary",
    minimum_os_version = common.min_os_macos.arm64_support,
    platform_type = "macos",
    tags = common.fixture_tags,
)

apple_universal_binary(
    name = "multi_arch_forced_cpus_cc_binary",
    binary = "//test/starlark_tests/resources:cc_test_binary",
    forced_cpus = [
        "x86_64",
        "arm64",
    ],
    minimum_os_version = common.min_os_macos.arm64_support,
    platform_type = "macos",
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------
# Targets for Apple dynamic framework import tests.

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFramework",
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:iOSDynamicFramework"],
)

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFrameworkWithBitcode",
    framework_imports = ["//test/testdata/fmwk:iOSDynamicFrameworkWithBitcode"],
)

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFrameworkWithDebugInfo",
    framework_imports = ["//test/testdata/fmwk:iOSDynamicFrameworkWithDebugInfo"],
)

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFrameworkWithDsym",
    dsym_imports = ["//test/testdata/fmwk:iOSDynamicFrameworkDsym"],
    framework_imports = ["//test/testdata/fmwk:iOSDynamicFramework"],
)

apple_dynamic_framework_import(
    name = "macOSImportedDynamicFramework",
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:macOSDynamicFramework"],
)

apple_dynamic_framework_import(
    name = "macOSImportedDynamicFrameworkWithBitcode",
    framework_imports = ["//test/testdata/fmwk:macOSDynamicFrameworkWithBitcode"],
)

apple_dynamic_framework_import(
    name = "macOSImportedDynamicFrameworkWithDebugInfo",
    framework_imports = ["//test/testdata/fmwk:macOSDynamicFrameworkWithDebugInfo"],
)

apple_dynamic_framework_import(
    name = "macOSImportedDynamicFrameworkWithDsym",
    dsym_imports = ["//test/testdata/fmwk:macOSDynamicFrameworkDsym"],
    framework_imports = ["//test/testdata/fmwk:macOSDynamicFramework"],
)

# ---------------------------------------------------------------------------------------
# Targets for Apple static framework import tests.

apple_static_framework_import(
    name = "iOSImportedStaticFramework",
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:iOSStaticFramework"],
)

apple_static_framework_import(
    name = "iOSImportedStaticFrameworkWithData",
    data = ["//test/starlark_tests/resources:sample.png"],
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:iOSSwiftStaticFramework"],
)

apple_static_framework_import(
    name = "iOSImportedStaticFrameworkWithDataAndBundle",
    data = ["//test/starlark_tests/resources:localized_xibs_ios"],
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:iOSStaticFramework"],
)

apple_static_framework_import(
    name = "iOSImportedSwiftStaticFramework",
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:iOSSwiftStaticFramework"],
)

apple_static_framework_import(
    name = "iOSImportedSwiftStaticFrameworkWithoutModuleInterface",
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:iOSSwiftStaticFrameworkWithoutModuleInterfaces"],
    has_swift = True,
)

apple_static_framework_import(
    name = "macOSImportedStaticFramework",
    features = ["-swift.layering_check"],
    framework_imports = ["//test/testdata/fmwk:macOSStaticFramework"],
)

# ---------------------------------------------------------------------------------------
# Targets for Apple dynamic XCFramework import tests.

apple_dynamic_xcframework_import(
    name = "ios_imported_dynamic_xcframework",
    features = ["-swift.layering_check"],
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = ["//test/testdata/xcframeworks:generated_dynamic_xcframework_with_headers"],
)

apple_dynamic_xcframework_import(
    name = "ios_imported_swift_dynamic_xcframework",
    features = ["-swift.layering_check"],
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = [":ios_swift_dynamic_xcframework"],
)

apple_dynamic_xcframework_import(
    name = "ios_imported_swift_dynamic_xcframework_without_swift_files",
    features = ["-swift.layering_check"],
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = [":ios_swift_dynamic_xcframework_without_swiftmodule"],
)

genrule(
    name = "ios_swift_dynamic_xcframework",
    srcs = [":ios_swift_xcframework_with_generated_header.xcframework.zip"],
    outs = [
        "SwiftFmwkWithGenHeader.xcframework/Info.plist",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Info.plist",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/SwiftFmwkWithGenHeader",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Headers/SwiftFmwkWithGenHeader.h",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftdoc",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftinterface",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/module.modulemap",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/SwiftFmwkWithGenHeader",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Headers/SwiftFmwkWithGenHeader.h",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Info.plist",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftdoc",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftinterface",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftdoc",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftinterface",
        "SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/module.modulemap",
    ],
    cmd = "unzip -qq $(execpath :ios_swift_xcframework_with_generated_header.xcframework.zip) -d $(RULEDIR)",
)

genrule(
    name = "ios_swift_dynamic_xcframework_without_swiftmodule",
    srcs = [":ios_swift_xcframework_with_generated_header.xcframework.zip"],
    outs = [
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/Info.plist",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Info.plist",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/SwiftFmwkWithGenHeader",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Headers/SwiftFmwkWithGenHeader.h",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/module.modulemap",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/SwiftFmwkWithGenHeader",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Headers/SwiftFmwkWithGenHeader.h",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Info.plist",
        "ios_swift_dynamic_xcframework_without_swiftmodule/SwiftFmwkWithGenHeader.xcframework/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/module.modulemap",
    ],
    cmd = "unzip -qq $(execpath :ios_swift_xcframework_with_generated_header.xcframework.zip) -d $(RULEDIR)/ios_swift_dynamic_xcframework_without_swiftmodule",
)

apple_dynamic_xcframework_import(
    name = "ios_imported_xcframework_with_libraries",
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = ["//test/testdata/xcframeworks:generated_static_xcframework"],
)

# ---------------------------------------------------------------------------------------
# Targets for Apple static XCFramework import tests.

apple_static_xcframework_import(
    name = "ios_imported_static_xcframework",
    features = ["-swift.layering_check"],
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = ["//test/testdata/xcframeworks:generated_static_xcframework_with_headers"],
)

apple_static_xcframework_import(
    name = "ios_imported_xcframework_with_static_frameworks",
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = ["//test/testdata/xcframeworks:generated_dynamic_xcframework"],
)

apple_static_xcframework_import(
    name = "ios_imported_swift_static_xcframework",
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = ["//test/testdata/xcframeworks:generated_swift_static_xcframework"],
)

apple_static_xcframework_import(
    name = "ios_imported_swift_static_xcframework_without_swiftmodule_and_has_swift_enabled",
    has_swift = True,
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = ["//test/testdata/xcframeworks:generated_swift_static_xcframework_without_swiftmodule"],
)

apple_static_xcframework_import(
    name = "ios_imported_static_xcframework_base",
    tags = common.fixture_tags,
    xcframework_imports = ["//test/testdata/xcframeworks:generated_static_xcframework_base"],
)

apple_static_xcframework_import(
    name = "ios_imported_static_xcframework_depends_on_base",
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
    xcframework_imports = ["//test/testdata/xcframeworks:generated_static_xcframework_depends_on_base"],
    deps = [":ios_imported_static_xcframework_base"],
)
