load(
    "//apple:tvos.bzl",
    "tvos_application",
    "tvos_dynamic_framework",
    "tvos_extension",
    "tvos_framework",
    "tvos_static_framework",
    "tvos_ui_test",
    "tvos_unit_test",
)
load(
    "//apple:apple.bzl",
    "apple_dynamic_framework_import",
)
load("//test/starlark_tests:common.bzl", "FIXTURE_TAGS")
load(
    "//test/testdata/fmwk:generate_framework.bzl",
    "generate_import_framework",
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

tvos_application(
    name = "app",
    app_icons = ["//test/starlark_tests/resources:TVBrandAssets.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_application(
    name = "app_multiple_infoplists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_application(
    name = "app_with_ext",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_application(
    name = "app_with_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_application(
    name = "app_with_two_fmwk_provisioned",
    bundle_id = "com.google.example",
    frameworks = [
        ":fmwk_with_provisioning",
        ":second_fmwk_with_provisioning",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_application(
    name = "app_with_fmwk_with_fmwk_provisioned",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_fmwk_with_provisioning"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_application(
    name = "app_with_fmwk_with_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_application(
    name = "app_with_imported_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_framework(
    name = "fmwk",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

tvos_framework(
    name = "fmwk_dead_stripped",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

tvos_framework(
    name = "fmwk_with_provisioning",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

tvos_framework(
    name = "second_fmwk_with_provisioning",
    bundle_id = "com.google.example.frameworktoo",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

tvos_framework(
    name = "fmwk_with_fmwk",
    bundle_id = "com.google.example.frameworkception",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

tvos_framework(
    name = "fmwk_with_fmwk_with_provisioning",
    bundle_id = "com.google.example.frameworkception",
    frameworks = [":fmwk_with_provisioning"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

objc_library(
    name = "dynamic_fmwk_depending_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    tags = FIXTURE_TAGS,
    deps = [":imported_tvos_dynamic_fmwk"],
)

apple_dynamic_framework_import(
    name = "imported_tvos_dynamic_fmwk",
    framework_imports = [":generated_tvos_dynamic_fmwk"],
    tags = FIXTURE_TAGS,
)

generate_import_framework(
    name = "generated_tvos_dynamic_fmwk",
    archs = ["x86_64"],
    libtype = "dynamic",
    minimum_os_version = "9.0",
    sdk = "appletvsimulator",
    tags = FIXTURE_TAGS,
)

# ---------------------------------------------------------------------------------------

tvos_static_framework(
    name = "static_fmwk",
    hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_ui_test(
    name = "ui_test",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_ui_test(
    name = "unit_test",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_no_host",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_application(
    name = "app_with_direct_swift_dep",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [":swift_lib"],
)

tvos_application(
    name = "app_with_indirect_swift_dep",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [":objc_to_swift_lib"],
)

tvos_application(
    name = "app_with_direct_swift_dep_stable_abi",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "12.2",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [":swift_lib"],
)

swift_library(
    name = "swift_lib",
    srcs = ["//test/testdata/sources:main.swift"],
    tags = FIXTURE_TAGS,
)

objc_library(
    name = "objc_to_swift_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    tags = FIXTURE_TAGS,
    deps = [":swift_lib"],
)

# ---------------------------------------------------------------------------------------

swift_library(
    name = "basic_framework_lib",
    srcs = [
        "//test/starlark_tests/resources:BasicFramework.swift",
    ],
    features = ["swift.no_generated_module_map"],
    generates_header = True,
    module_name = "BasicFramework",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
)

tvos_dynamic_framework(
    name = "basic_framework",
    bundle_id = "com.google.example.framework",
    bundle_name = "BasicFramework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "14.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_lib",
    ],
)

swift_library(
    name = "basic_framework_with_direct_dependency_lib",
    srcs = [
        "//test/starlark_tests/resources:DirectDependencyTest.swift",
    ],
    features = ["swift.no_generated_module_map"],
    generates_header = True,
    module_name = "DirectDependencyTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        ":basic_framework_lib",
    ],
)

tvos_dynamic_framework(
    name = "basic_framework_with_direct_dependency",
    bundle_id = "com.google.example.framework",
    bundle_name = "DirectDependencyTest",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "14.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_direct_dependency_lib",
    ],
)

swift_library(
    name = "basic_framework_with_transitive_dependency_lib",
    srcs = [
        "//test/starlark_tests/resources:TransitiveDependencyTest.swift",
    ],
    features = ["swift.no_generated_module_map"],
    generates_header = True,
    module_name = "TransitiveDependencyTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        ":basic_framework_lib",
        ":basic_framework_with_direct_dependency_lib",
    ],
)

tvos_dynamic_framework(
    name = "basic_framework_with_transitive_dependency",
    bundle_id = "com.google.example.framework",
    bundle_name = "TransitiveDependencyTest",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "14.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_transitive_dependency_lib",
    ],
)

tvos_dynamic_framework(
    name = "dynamic_fmwk_with_multiple_dependencies",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "14.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_lib",
        ":basic_framework_with_direct_dependency_lib",
    ],
)

tvos_dynamic_framework(
    name = "dynamic_fmwk_with_objc_library",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "14.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_application(
    name = "app_with_objc_library_dep_with_tvos_framework_runtime_dep",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [":objc_lib_with_runtime_dep_fmwk"],
)

tvos_application(
    name = "app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [":objc_lib_with_inner_lib_with_runtime_dep_fmwk"],
)

tvos_application(
    name = "app_with_load_and_runtime_framework_dep",
    bundle_id = "com.google.example",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [":objc_lib_with_runtime_dep_fmwk"],
)

objc_library(
    name = "objc_lib_with_inner_lib_with_runtime_dep_fmwk",
    srcs = ["//test/starlark_tests/resources:main.m"],
    runtime_deps = [":fmwk_with_fmwk"],
    deps = [":objc_lib_with_runtime_dep_fmwk"],
)

objc_library(
    name = "objc_lib_with_runtime_dep_fmwk",
    srcs = ["//test/starlark_tests/resources:main.m"],
    runtime_deps = [":fmwk_with_provisioning"],
)
