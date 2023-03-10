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
    "apple_static_framework_import",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)
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
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_application(
    name = "app_with_swift_ext",
    bundle_id = "com.google.example",
    extensions = [":swift_ext"],
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:objc_main_lib"],
)

tvos_extension(
    name = "swift_ext",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:swift_main_lib",
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_application(
    name = "app_with_runtime_framework_using_import_static_lib_dep",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_imported_static_framework"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_framework(
    name = "fmwk",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

tvos_framework(
    name = "fmwk_with_imported_static_framework",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        ":static_fmwk_depending_lib",
    ],
)

# ---------------------------------------------------------------------------------------

objc_library(
    name = "dynamic_fmwk_depending_lib",
    tags = common.fixture_tags,
    deps = [":imported_tvos_dynamic_fmwk"],
)

apple_dynamic_framework_import(
    name = "imported_tvos_dynamic_fmwk",
    framework_imports = [":generated_tvos_dynamic_fmwk"],
    tags = common.fixture_tags,
)

generate_import_framework(
    name = "generated_tvos_dynamic_fmwk",
    archs = ["x86_64"],
    libtype = "dynamic",
    minimum_os_version = common.min_os_tvos.baseline,
    sdk = "appletvsimulator",
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------

objc_library(
    name = "static_fmwk_depending_lib",
    deps = [":imported_tvos_static_fmwk"],
)

apple_static_framework_import(
    name = "imported_tvos_static_fmwk",
    framework_imports = [":generated_tvos_static_fmwk"],
)

generate_import_framework(
    name = "generated_tvos_static_fmwk",
    archs = ["x86_64"],
    libtype = "static",
    minimum_os_version = common.min_os_tvos.baseline,
    sdk = "appletvsimulator",
)

# ---------------------------------------------------------------------------------------

tvos_static_framework(
    name = "static_fmwk",
    hdrs = [
        "//test/starlark_tests/resources:shared.h",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

tvos_static_framework(
    name = "swift_static_fmwk",
    bundle_name = "swift_static_fmwk",
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [":swift_fmwk_lib"],
)

swift_library(
    name = "swift_fmwk_lib",
    srcs = ["//test/testdata/sources:main.swift"],
    module_name = "swift_static_fmwk",
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------

tvos_ui_test(
    name = "ui_test",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_ui_test(
    name = "ui_test_custom_bundle_id",
    bundle_id = "my.test.bundle.id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_ui_test(
    name = "ui_test_invalid_bundle_id",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_ui_test(
    name = "ui_test_dummy_runner",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_unit_test(
    name = "unit_test",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.arm_sim_support,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_custom_bundle_id",
    bundle_id = "my.test.bundle.id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_invalid_bundle_id",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_with_fmwk",
    frameworks = [
        ":fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_with_fmwk_from_objc_library_runtime_deps",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        ":objc_lib_with_runtime_dep_fmwk",
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_with_imported_fmwk",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_with_host_importing_same_fmwk",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":app_with_imported_fmwk",
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_dummy_runner",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_with_swift_deps",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.arm_sim_support,
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_swift_depending_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_application(
    name = "app_with_direct_swift_dep",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [":swift_lib"],
)

tvos_application(
    name = "app_with_indirect_swift_dep",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [":objc_to_swift_lib"],
)

tvos_application(
    name = "app_with_direct_swift_dep_stable_abi",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.stable_swift_abi,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [":swift_lib"],
)

swift_library(
    name = "swift_lib",
    srcs = ["//test/testdata/sources:main.swift"],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_to_swift_lib",
    tags = common.fixture_tags,
    deps = [":swift_lib"],
)

# ---------------------------------------------------------------------------------------
# Targets for the app/test resource deduping test.

objc_library(
    name = "shared_lib",
    data = [
        "//test/starlark_tests/resources:basic_bundle",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "app_lib",
    data = [
        "//test/starlark_tests/resources:empty.strings",
    ],
    tags = common.fixture_tags,
    deps = [":shared_lib"],
)

objc_library(
    name = "test_lib",
    data = [
        "//test/starlark_tests/resources:nonlocalized.strings",
    ],
    tags = common.fixture_tags,
    deps = [":app_lib"],
)

objc_library(
    name = "main_lib",
    tags = common.fixture_tags,
    deps = [
        ":app_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_framework(
    name = "dedupe_test_fmwk",
    bundle_id = "com.fmwk",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [
        ":shared_lib",
    ],
)

tvos_application(
    name = "dedupe_test_app",
    bundle_id = "com.app",
    frameworks = [
        ":dedupe_test_fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":main_lib",
    ],
)

tvos_unit_test(
    name = "dedupe_test_test",
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":dedupe_test_app",
    deps = [
        ":test_lib",
    ],
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
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
)

tvos_dynamic_framework(
    name = "basic_framework",
    bundle_id = "com.google.example.framework",
    bundle_name = "BasicFramework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [":objc_lib_with_runtime_dep_fmwk"],
)

tvos_application(
    name = "app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    deps = [":objc_lib_with_inner_lib_with_runtime_dep_fmwk"],
)

tvos_application(
    name = "app_with_load_and_runtime_framework_dep",
    bundle_id = "com.google.example",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
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

# ---------------------------------------------------------------------------------------

tvos_extension(
    name = "ext_for_bundle_loader",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_common_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

tvos_unit_test(
    name = "unit_test_with_bundle_loader",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_tvos.baseline,
    tags = common.fixture_tags,
    test_host = ":ext_for_bundle_loader",
    deps = [
        "//test/starlark_tests/resources:objc_common_test_lib",
    ],
)
