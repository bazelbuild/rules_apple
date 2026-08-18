load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load(
    "//apple:apple_imports.bzl",
    "apple_dynamic_xcframework_import",
    "apple_static_xcframework_import",
)
load(
    "//apple:apple_universal_binary.bzl",
    "apple_universal_binary",
)
load(
    "//apple:apple_xcframework.bzl",
    "apple_static_xcframework",
    "apple_xcframework",
)
load(
    "//apple:macos.bzl",
    "macos_bundle",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
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
    minimum_os_version = common.min_os_macos.min_deployment_target,
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
    minimum_os_version = common.min_os_macos.min_deployment_target,
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
    minimum_os_version = common.min_os_macos.min_deployment_target,
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
    minimum_os_version = common.min_os_macos.min_deployment_target,
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
    minimum_os_version = common.min_os_macos.min_deployment_target,
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
    minimum_os_version = common.min_os_macos.min_deployment_target,
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
    library_evolution = True,
    module_name = "ios_static_xcfmwk_with_swift",
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_for_static_xcfmwk_with_headers",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    library_evolution = True,
    module_name = "ios_static_xcfmwk_with_swift_generated_headers",
    tags = common.fixture_tags,
)

swift_library(
    name = "mixed_module_swift_lib_for_static_xcfmwk_with_headers_and_custom_headers",
    srcs = [
        "DummyFmwk.m",
        "DummyFmwk.swift",
    ],
    hdrs = ["DummyFmwk.h"],
    generates_header = True,
    library_evolution = True,
    module_name = "ios_static_xcfmwk_with_swift_generated_header_and_custom_headers",
    tags = common.fixture_tags,
    deps = [
    ],
)

swift_library(
    name = "mixed_module_swift_lib_for_static_xcfmwk_framework_with_headers_and_custom_headers",
    srcs = [
        "DummyFmwk.m",
        "DummyFmwk.swift",
    ],
    hdrs = ["DummyFmwk.h"],
    generates_header = True,
    library_evolution = True,
    module_name = "ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers",
    tags = common.fixture_tags,
    deps = [
    ],
)

swift_library(
    name = "swift_lib_for_static_xcfmwk_custom_bundle_name",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    library_evolution = True,
    module_name = "ios_static_xcfmwk_with_custom_bundle_name",
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_fmwk_lib",
    srcs = [
        "DummyFmwk.swift",
    ],
    library_evolution = True,
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "macos_static_xcframework",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    macos = {
        "device": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "macos_static_library_xcframework",
    bundle_format = "library",
    macos = {
        "device": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "macos_dynamic_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    macos = {
        "device": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "tvos_dynamic_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_versions = {
        "tvos": common.min_os_tvos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    tvos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "visionos_dynamic_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_versions = {
        "visionos": common.min_os_visionos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "watchos_dynamic_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_versions = {
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    watchos = {
        "simulator": [
            "arm64",
            "x86_64",
        ],
        "device": [
            "arm64",
            "arm64_32",
        ],
    },
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "watchos_static_xcframework",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_versions = {
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    watchos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": [
            "arm64_32",
            "arm64",
        ],
    },
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "multiplatform_dynamic_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    macos = {
        "device": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "tvos": common.min_os_tvos.min_deployment_target,
        "ios": common.min_os_ios.min_deployment_target,
        "visionos": common.min_os_visionos.min_deployment_target,
        "macos": common.min_os_macos.min_deployment_target,
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    tvos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    watchos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": [
            "arm64_32",
            "arm64",
        ],
    },
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_lipoed_xcframework_with_disabled_features",
    bundle_id = "com.google.example",
    features = [
        "-trivial_auto_var_init",
    ],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    secure_features = [
        "trivial_auto_var_init",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_lipoed_xcframework_with_trivial_auto_var_init",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    secure_features = [
        "trivial_auto_var_init",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_data_resource_bundle",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    resources = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "multiplatform_static_xcframework",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "tvos": common.min_os_tvos.min_deployment_target,
        "ios": common.min_os_ios.min_deployment_target,
        "visionos": common.min_os_visionos.min_deployment_target,
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    tvos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    watchos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": [
            "arm64_32",
            "arm64",
        ],
    },
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_data_resource_bundle",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    resources = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
        "//test/starlark_tests/resources:resource_bundle",
    ],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_without_correct_minimum_os_versions",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "tvos": common.min_os_tvos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_without_valid_minimum_os_versions",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "xros": common.min_os_tvos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_without_platforms",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_deps_resource_bundle",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
        "//test/starlark_tests/resources:resource_bundle",
    ],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_avoid_deps_non_localized_assets",
    avoid_deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
    ],
    bundle_format = "framework",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:common.h",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
    ],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_avoid_deps_resource_bundle",
    avoid_deps = [
        "//test/starlark_tests/resources:resource_bundle",
    ],
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
    ],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_resource_bundle_in_deps_and_avoid_deps",
    avoid_deps = [
        "//test/starlark_tests/resources:resource_bundle",
    ],
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
        "//test/starlark_tests/resources:resource_bundle",
    ],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_explicit_owners_structured_resources_in_deps_and_avoid_deps",
    avoid_deps = [
        "//test/starlark_tests/resources:objc_shared_lib_with_resources",
    ],
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
        "//test/starlark_tests/resources:objc_lib_with_no_srcs_and_structured_resources",
    ],
)

apple_static_xcframework(
    name = "static_framework_xcframework_with_device_dependent_resources_in_deps",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
        "tvos": common.min_os_tvos.min_deployment_target,
        "visionos": common.min_os_visionos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    tvos = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
        "//test/starlark_tests/resources:ios_device_dependent_resources",
        "//test/starlark_tests/resources:tvos_device_dependent_resources",
        "//test/starlark_tests/resources:visionos_device_dependent_resources",
    ],
)

apple_static_xcframework(
    name = "static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
    avoid_deps = [
        "//test/starlark_tests/resources:tvos_device_dependent_resources",
        "//test/starlark_tests/resources:visionos_device_dependent_resources",
    ],
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
        "tvos": common.min_os_tvos.min_deployment_target,
        "visionos": common.min_os_visionos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    tvos = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    deps = [
        "//test/starlark_tests/resources:fmwk_lib",
        "//test/starlark_tests/resources:ios_device_dependent_resources",
        "//test/starlark_tests/resources:tvos_device_dependent_resources",
        "//test/starlark_tests/resources:visionos_device_dependent_resources",
    ],
)

apple_static_xcframework(
    name = "ios_swift_static_framework_xcframework_with_arch_dependent_swift_in_deps",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    bundle_name = "arch_dependent_swift",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:arch_dependent_swift",
    ],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_no_bundle_id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_xcframework(
    name = "ios_dynamic_xcframework_with_invalid_character_bundle_id",
    bundle_id = "my#bundle",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_no_bundle_id",
    bundle_format = "framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    resources = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_framework_xcframework_with_invalid_character_bundle_id",
    bundle_format = "framework",
    bundle_id = "my#bundle",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": ["x86_64"],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    resources = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":SwiftFmwkWithGenHeader"],
)

apple_xcframework(
    name = "ios_swift_xcframework_with_two_top_level_modules",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        ":SwiftFmwkWithGenHeader",
        ":SwiftSecondModuleForFmwk",
    ],
)

apple_xcframework(
    name = "ios_swift_xcframework_with_invalid_module_deps",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":SwiftFmwkWithInvalidModuleDeps"],
)

# Reserved as an input for import_dynamic_(xc)framework rules; must be referenced as a List of Files
# as an input to one of such rules.
apple_xcframework(
    name = "ios_swift_3p_xcframework_with_generated_header",
    bundle_id = "com.google.example",
    bundle_name = "Swift3PFmwkWithGenHeader",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":Swift3PFmwkWithGenHeader"],
)

apple_xcframework(
    name = "multiplatform_xcframework_to_avoid",
    bundle_id = "com.google.lowerexample",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
        "tvos": common.min_os_tvos.min_deployment_target,
        "visionos": common.min_os_visionos.min_deployment_target,
    },
    tags = common.fixture_tags,
    tvos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    deps = [
        ":StaticFmwkLowerLib",
        # We need either an objc_library or a swift_library here to get resources that can be
        # "avoided" by the other framework. This is because the logic to avoid framework resources
        # is bound to this internal concept of "owners", an attribute which is only automatically
        # set by objc_library in specific configurations (contains srcs, non_arc_srcs or deps) and
        # swift_library to indicate that the library "owns" those resources, and that downstream
        # resource processing will avoid bundling them if they're already bundled by an upstream
        # Apple bundle target.
        "//test/starlark_tests/resources:objc_lib_with_resource_group_referencing_resource_deps",
    ],
)

apple_xcframework(
    name = "multiplatform_xcframework_with_avoid_frameworks",
    avoid_frameworks = [":multiplatform_xcframework_to_avoid"],
    bundle_id = "com.google.upperexample",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
        "tvos": common.min_os_tvos.min_deployment_target,
        "visionos": common.min_os_visionos.min_deployment_target,
    },
    tags = common.fixture_tags,
    tvos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    deps = [
        ":StaticFmwkUpperLib",
        "//test/starlark_tests/resources:objc_lib_with_resource_group_referencing_resource_deps",
    ],
)

apple_xcframework(
    name = "upper_multiplatform_xcframework_with_avoid_frameworks",
    avoid_frameworks = [":multiplatform_xcframework_with_avoid_frameworks"],
    bundle_id = "com.google.topmostexample",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
        "tvos": common.min_os_tvos.min_deployment_target,
        "visionos": common.min_os_visionos.min_deployment_target,
    },
    tags = common.fixture_tags,
    tvos = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    visionos = {
        "simulator": [
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    deps = [
        ":FmwkUppermostLib",
        "//test/starlark_tests/resources:apple_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_lib_with_resource_group_referencing_resource_deps",
    ],
)

apple_xcframework(
    name = "upper_ios_swift_xcframework_with_avoid_frameworks",
    avoid_frameworks = [":multiplatform_xcframework_with_avoid_frameworks"],
    bundle_id = "com.google.upperexample",
    bundle_name = "SwiftFmwkWithObjcDepsAndGenHeader",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        ":SwiftFmwkWithObjcDepsAndGenHeader",
    ],
)

apple_xcframework(
    name = "reduced_architecture_ios_xcframework_to_avoid",
    bundle_id = "com.google.lowerexample",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        ":StaticFmwkLowerLib",
        # We need either an objc_library or a swift_library here to get resources that can be
        # "avoided" by the other framework. This is because the logic to avoid framework resources
        # is bound to this internal concept of "owners", an attribute which is only automatically
        # set by objc_library in specific configurations (contains srcs, non_arc_srcs or deps) and
        # swift_library to indicate that the library "owns" those resources, and that downstream
        # resource processing will avoid bundling them if they're already bundled by an upstream
        # Apple bundle target.
        "//test/starlark_tests/resources:objc_lib_with_resource_group_referencing_resource_deps",
    ],
)

apple_xcframework(
    name = "ios_xcframework_with_avoid_frameworks_referencing_insufficient_architectures",
    avoid_frameworks = [":reduced_architecture_ios_xcframework_to_avoid"],
    bundle_id = "com.google.upperexample",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        ":StaticFmwkUpperLib",
        "//test/starlark_tests/resources:objc_lib_with_resource_group_referencing_resource_deps",
    ],
)

apple_xcframework(
    name = "reduced_environment_ios_xcframework_to_avoid",
    bundle_id = "com.google.lowerexample",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        ":StaticFmwkLowerLib",
        # We need either an objc_library or a swift_library here to get resources that can be
        # "avoided" by the other framework. This is because the logic to avoid framework resources
        # is bound to this internal concept of "owners", an attribute which is only automatically
        # set by objc_library in specific configurations (contains srcs, non_arc_srcs or deps) and
        # swift_library to indicate that the library "owns" those resources, and that downstream
        # resource processing will avoid bundling them if they're already bundled by an upstream
        # Apple bundle target.
        "//test/starlark_tests/resources:objc_lib_with_resource_group_referencing_resource_deps",
    ],
)

apple_xcframework(
    name = "ios_xcframework_with_avoid_frameworks_referencing_insufficient_environments",
    avoid_frameworks = [":reduced_environment_ios_xcframework_to_avoid"],
    bundle_id = "com.google.upperexample",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        ":StaticFmwkUpperLib",
        "//test/starlark_tests/resources:objc_lib_with_resource_group_referencing_resource_deps",
    ],
)

apple_static_xcframework(
    name = "ios_static_xcframework_min_deployment_target",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_objc_with_no_public_headers",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": ["arm64"],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
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
        "ios": common.min_os_ios.min_deployment_target,
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
        "ios": common.min_os_ios.min_deployment_target,
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
        "ios": common.min_os_ios.min_deployment_target,
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
        "ios": common.min_os_ios.min_deployment_target,
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":swift_lib_for_static_xcfmwk_with_headers"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_with_swift_generated_header_and_custom_headers",
    ios = {
        "device": ["arm64"],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":mixed_module_swift_lib_for_static_xcfmwk_with_headers_and_custom_headers"],
)

apple_static_xcframework(
    name = "ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers",
    bundle_format = "framework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "device": ["arm64"],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":mixed_module_swift_lib_for_static_xcfmwk_framework_with_headers_and_custom_headers"],
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
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_with_pointer_authentication",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "secure_features_ios_static_xcframework_with_rule_level_disabled_features",
    features = [
        "-trivial_auto_var_init",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    secure_features = [
        "trivial_auto_var_init",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "secure_features_ios_static_xcframework_with_trivial_auto_var_init",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    secure_features = [
        "trivial_auto_var_init",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_swift_static_xcframework_with_broad_avoid_deps",
    avoid_deps = [":swift_lib_for_static_xcfmwk"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":swift_lib_for_static_xcfmwk"],
)

apple_static_xcframework(
    name = "ios_swift_static_framework_xcframework_with_broad_avoid_deps",
    avoid_deps = [":swift_lib_for_static_xcfmwk"],
    bundle_format = "framework",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":swift_lib_for_static_xcfmwk"],
)

apple_static_xcframework(
    name = "ios_swift_static_xcframework_with_two_top_level_modules",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [
        ":SwiftFmwkWithGenHeader",
        ":SwiftSecondModuleForFmwk",
    ],
)

apple_static_xcframework(
    name = "ios_swift_static_xcframework_with_invalid_module_deps",
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    tags = common.fixture_tags,
    deps = [":SwiftFmwkWithInvalidModuleDeps"],
)

apple_static_xcframework(
    name = "ios_swift_static_xcframework_with_invalid_attrs_for_library_outputs",
    bundle_id = "com.google.invalid-attrs",
    families_required = {
        "ios": ["ipad"],
    },
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
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
        "ios": common.min_os_ios.min_deployment_target,
    },
    resources = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = [":SwiftFmwkWithInvalidModuleDeps"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_without_correct_minimum_os_versions",
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
        "tvos": common.min_os_tvos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_without_valid_minimum_os_versions",
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
        "xros": common.min_os_tvos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_without_platforms",
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_framework_without_correct_minimum_os_versions",
    bundle_format = "framework",
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
        "tvos": common.min_os_tvos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_framework_without_valid_minimum_os_versions",
    bundle_format = "framework",
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
        "xros": common.min_os_tvos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

apple_static_xcframework(
    name = "ios_static_xcframework_framework_without_platforms",
    bundle_format = "framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:fmwk_lib"],
)

genrule(
    name = "dummy_fmwk_topmost_objc_hdr",
    outs = ["DummyUpperFmwk.h"],
    cmd = "echo '#ifndef SDK_UPPER_FRAMEWORK_H_\n#define SDK_UPPER_FRAMEWORK_H_\n void doUpperStuff(); \n#endif\n// SDK_UPPER_FRAMEWORK_H_' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_topmost_objc_src",
    outs = ["DummyUpperFmwk.m"],
    cmd = "echo '#import <Foundation/Foundation.h>\n#import \"DummyFmwk.h\"\nvoid doUpperStuff() { doStuff(); }' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_objc_hdr",
    outs = ["DummyFmwk.h"],
    cmd = "echo '#ifndef SDK_FRAMEWORK_H_\n#define SDK_FRAMEWORK_H_\n void doStuff(); \n#endif\n// SDK_FRAMEWORK_H_' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_objc_src",
    outs = ["DummyFmwk.m"],
    cmd = "echo '#import <Foundation/Foundation.h>\nvoid doStuff() { NSLog(@\"Framework method called\"); }' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_cc_src",
    outs = ["DummyFmwk.c"],
    cmd = "echo '#include <stdio.h>\nvoid doStuff() { printf(\"Framework method called\\n\"); }' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_swift_src",
    outs = ["DummyFmwk.swift"],
    cmd = "echo 'import Foundation\n@objc public class SharedClass: NSObject {\n@objc public func doSomethingShared() {\nNSLog(\"Doing something shared!\")\n}\n}\n' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_swift_second_src",
    outs = ["DummyFmwkSecondModule.swift"],
    cmd = "echo 'import Foundation\n@objc public class SecondSharedClass: NSObject {\n@objc public func doSomethingShared() {\nNSLog(\"Doing something shared again!\")\n}\n}\n' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_dependent_objc_src",
    outs = ["DummyFmwkDependent.m"],
    cmd = "echo '#import <Foundation/Foundation.h>\nvoid frameworkDependent() { NSLog(@\"frameworkDependent() called\"); }' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "dummy_fmwk_dependent_cc_src",
    outs = ["DummyFmwkDependent.c"],
    cmd = "echo '#include <stdio.h>\nvoid frameworkDependent() { printf(\"frameworkDependent() called\\n\"); }' > $@",
    tags = common.fixture_tags,
)

objc_library(
    name = "StaticFmwkLib",
    srcs = [
        "DummyFmwk.h",
        "DummyFmwk.m",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "StaticFmwkUpperLib",
    srcs = [
        "DummyFmwk.m",
    ],
    hdrs = [
        "DummyFmwk.h",
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

# buildozer: disable=no-hdrs-no-alwayslink
cc_library(
    name = "StaticFmwkCcLowerLib",
    srcs = ["DummyFmwkDependent.c"],
    tags = common.fixture_tags,
)

objc_library(
    name = "FmwkUppermostLib",
    srcs = [
        "DummyUpperFmwk.m",
    ],
    hdrs = [
        "DummyUpperFmwk.h",
    ],
    tags = common.fixture_tags,
    deps = [":StaticFmwkUpperLib"],
)

swift_library(
    name = "SwiftFmwkWithGenHeader",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    library_evolution = True,
    module_name = "SwiftFmwkWithGenHeader",
    tags = common.fixture_tags,
)

swift_library(
    name = "SwiftFmwkWithObjcDepsAndGenHeader",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    library_evolution = True,
    module_name = "SwiftFmwkWithObjcDepsAndGenHeader",
    tags = common.fixture_tags,
    deps = [
        ":StaticFmwkUpperLib",
    ],
)

swift_library(
    name = "SwiftSecondModuleForFmwk",
    srcs = ["DummyFmwkSecondModule.swift"],
    library_evolution = True,
    module_name = "SwiftSecondModuleForFmwk",
    tags = common.fixture_tags,
)

swift_library(
    name = "SwiftFmwkWithInvalidModuleDeps",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    library_evolution = True,
    module_name = "SwiftFmwkWithInvalidModuleDeps",
    tags = common.fixture_tags,
    deps = [
        ":SwiftSecondModuleForFmwk",
    ],
)

# Reserved as an input for import_dynamic_(xc)framework rules; referenced by an apple_xcframework
# rule treated as a List of Files that properly declares a bundle_name matching this module_name.
swift_library(
    name = "Swift3PFmwkWithGenHeader",
    srcs = ["DummyFmwk.swift"],
    generates_header = True,
    library_evolution = True,
    module_name = "Swift3PFmwkWithGenHeader",
    tags = common.fixture_tags,
)

apple_universal_binary(
    name = "multi_arch_cc_binary",
    binary = "//test/starlark_tests/resources:cc_test_binary",
    minimum_os_version = common.min_os_macos.min_deployment_target,
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
    minimum_os_version = common.min_os_macos.min_deployment_target,
    platform_type = "macos",
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------
# Targets for Apple dynamic XCFramework import tests.

apple_dynamic_xcframework_import(
    name = "ios_imported_xcframework_with_static_xcframework",
    tags = common.fixture_tags,
    xcframework_imports = [":generated_static_xcframework"],
)

objc_library(
    name = "generated_static_xcframework_lib",
    srcs = ["//test/starlark_tests/resources:dummy.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_static_xcframework(
    name = "generated_static_xcframework_xcframework",
    bundle_name = "generated_static_xcframework",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
    deps = [
        ":generated_static_xcframework_lib",
    ],
)

genrule(
    name = "generated_static_xcframework",
    srcs = [":generated_static_xcframework_xcframework"],
    outs = [
        "generated_static_xcframework/generated_static_xcframework.xcframework/Info.plist",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64/Headers/generated_static_xcframework/SharedClass.h",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64/Headers/generated_static_xcframework/generated_static_xcframework.h",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64/Headers/generated_static_xcframework/module.modulemap",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64/generated_static_xcframework.a",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64_x86_64-simulator/Headers/generated_static_xcframework/SharedClass.h",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64_x86_64-simulator/Headers/generated_static_xcframework/generated_static_xcframework.h",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64_x86_64-simulator/Headers/generated_static_xcframework/module.modulemap",
        "generated_static_xcframework/generated_static_xcframework.xcframework/ios-arm64_x86_64-simulator/generated_static_xcframework.a",
    ],
    cmd = common.extract_xcframework_cmd("generated_static_xcframework"),
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------
# Targets for Apple static XCFramework import tests.

apple_static_xcframework_import(
    name = "ios_imported_xcframework_with_static_frameworks_no_root_infoplists",
    tags = common.fixture_tags,
    xcframework_imports = [":generated_static_framework_xcframework_without_root_infoplist"],
)

objc_library(
    name = "generated_static_framework_xcframework_without_root_infoplist_lib",
    srcs = ["//test/starlark_tests/resources:dummy.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_static_xcframework(
    name = "generated_static_framework_xcframework_without_root_infoplist_xcframework",
    bundle_name = "generated_static_framework_xcframework_without_root_infoplist",
    ios = {
        "simulator": [
            "x86_64",
            "arm64",
        ],
        "device": [
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
    deps = [
        ":generated_static_framework_xcframework_without_root_infoplist_lib",
    ],
)

genrule(
    name = "generated_static_framework_xcframework_without_root_infoplist",
    srcs = [":generated_static_framework_xcframework_without_root_infoplist_xcframework"],
    outs = [
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/Info.plist",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/SharedClass.h",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/generated_static_framework_xcframework_without_root_infoplist.h",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Modules/module.modulemap",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/generated_static_framework_xcframework_without_root_infoplist",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/SharedClass.h",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/generated_static_framework_xcframework_without_root_infoplist.h",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Modules/module.modulemap",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/generated_static_framework_xcframework_without_root_infoplist",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Resources/generated_static_framework_xcframework_without_root_infoplist.bundle/Info.plist",
        "generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Resources/generated_static_framework_xcframework_without_root_infoplist.bundle/Info.plist",
    ],
    cmd = """
        out_dir="$(@D)"
        mkdir -p "$$out_dir/generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework"
        unzip -q -o $< -d "$$out_dir/generated_static_framework_xcframework_without_root_infoplist"
        archive_dir="$$out_dir/generated_static_framework_xcframework_without_root_infoplist/generated_static_framework_xcframework_without_root_infoplist.xcframework"

        # Transform ios-arm64
        mkdir -p "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework"
        mv "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.a" "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/generated_static_framework_xcframework_without_root_infoplist"
        mkdir -p "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Headers" && mv "$$archive_dir/ios-arm64/Headers/generated_static_framework_xcframework_without_root_infoplist"/* "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/"
        mkdir -p "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Modules"
        mv "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/module.modulemap" "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Modules/"
        mkdir -p "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Resources/generated_static_framework_xcframework_without_root_infoplist.bundle"
        touch "$$archive_dir/ios-arm64/generated_static_framework_xcframework_without_root_infoplist.framework/Resources/generated_static_framework_xcframework_without_root_infoplist.bundle/Info.plist"

        # Transform ios-arm64_x86_64-simulator
        mkdir -p "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework"
        mv "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.a" "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/generated_static_framework_xcframework_without_root_infoplist"
        mkdir -p "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Headers" && mv "$$archive_dir/ios-arm64_x86_64-simulator/Headers/generated_static_framework_xcframework_without_root_infoplist"/* "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/"
        mkdir -p "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Modules"
        mv "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Headers/module.modulemap" "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Modules/"
        mkdir -p "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Resources/generated_static_framework_xcframework_without_root_infoplist.bundle"
        touch "$$archive_dir/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Resources/generated_static_framework_xcframework_without_root_infoplist.bundle/Info.plist"

        # NOTE: Intentionally omitting root Info.plist to test missing root Info.plist failure mode.
    """,
    tags = common.fixture_tags,
)
