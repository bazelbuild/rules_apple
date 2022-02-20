load(
    "//apple:macos.bzl",
    "macos_application",
    "macos_bundle",
    "macos_command_line_application",
    "macos_dylib",
    "macos_extension",
    "macos_kernel_extension",
    "macos_quick_look_plugin",
    "macos_ui_test",
    "macos_unit_test",
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

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

macos_application(
    name = "app",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    app_icons = ["//test/starlark_tests/resources:MacAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:apple_localized_assets_lib",
        "//test/starlark_tests/resources:apple_non_localized_assets_lib",
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:bundle_library_apple_lib",
        "//test/starlark_tests/resources:empty_strings_file_lib",
        "//test/starlark_tests/resources:nested_bundle_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_basic_swift",
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:swift_main_lib",
    ],
)

macos_application(
    name = "app_multiple_infoplists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_special_linkopts",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = [
        "-alias",
        "_main",
        "_linkopts_test_main",
        "-exported_symbol",
        "_linkopts_test_main",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_space",
    bundle_id = "com.google.example",
    bundle_name = "app with space",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_different_extension",
    bundle_extension = "xpc",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_minimum_deployment_os_version",
    bundle_extension = "xpc",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_deployment_os_version = "11.0",
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_application(
    name = "app_with_ext",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_extension(
    name = "ext",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_ext_and_symbols_in_bundle",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    include_symbols_in_bundle = True,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_imported_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

objc_library(
    name = "dynamic_fmwk_depending_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    tags = FIXTURE_TAGS,
    deps = [":imported_macos_dynamic_fmwk"],
)

apple_dynamic_framework_import(
    name = "imported_macos_dynamic_fmwk",
    framework_imports = [":generated_macos_dynamic_fmwk"],
    tags = FIXTURE_TAGS,
)

generate_import_framework(
    name = "generated_macos_dynamic_fmwk",
    archs = ["x86_64"],
    libtype = "dynamic",
    minimum_os_version = "10.11",
    sdk = "macosx",
    tags = FIXTURE_TAGS,
)

# ---------------------------------------------------------------------------------------

macos_bundle(
    name = "bundle",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_for_app",
    bundle_id = "com.google.example",
    bundle_loader = ":app",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_for_cmd_app",
    bundle_id = "com.google.example",
    bundle_loader = ":cmd_app_basic",
    infoplists = [
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_dead_stripped",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_special_linkopts",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = [
        "-alias",
        "_anotherFunctionShared",
        "_linkopts_test_anotherFunctionShared",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_with_different_extension",
    bundle_extension = "prefPane",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_command_line_application(
    name = "cmd_app_basic",
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_basic_swift",
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:swift_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_info_plists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_info_and_launchd_plists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    launchdplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:launchd.plist",
    ],
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_special_linkopts",
    linkopts = [
        "-alias",
        "_main",
        "_linkopts_test_main",
    ],
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_dead_stripped",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionMain.exp",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_dylib(
    name = "dylib",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_dylib(
    name = "dylib_dead_stripped",
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "10.11",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_kernel_extension(
    name = "kext",
    bundle_id = "com.google.kext",
    infoplists = [
        "//test/starlark_tests/resources/kext_resources:Info-IOKit.plist",
    ],
    minimum_os_version = "10.13",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources/kext_resources:kext_lib",
    ],
)

macos_kernel_extension(
    name = "kext_dead_stripped",
    bundle_id = "com.google.kext",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources/kext_resources:Info-IOKit.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "10.13",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
        "//test/starlark_tests/resources/kext_resources:kext_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_quick_look_plugin(
    name = "ql_plugin",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_quick_look_plugin(
    name = "ql_plugin_dead_stripped",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionMain.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_quick_look_plugin(
    name = "ql_plugin_special_linkopts",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = [
        "-alias",
        "_main",
        "_linkopts_test_main",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_ui_test(
    name = "ui_test",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_unit_test(
    name = "unit_test",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = FIXTURE_TAGS,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)
