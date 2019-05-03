licenses(["notice"])

load(
    "//test/starlark_tests:ios_application_tests.bzl",
    "ios_application_test_suite",
)
load(
    "//test/starlark_tests:ios_extension_tests.bzl",
    "ios_extension_test_suite",
)
load(
    "//test/starlark_tests:ios_framework_tests.bzl",
    "ios_framework_test_suite",
)
load(
    "//test/starlark_tests:ios_imessage_application_tests.bzl",
    "ios_imessage_application_test_suite",
)
load(
    "//test/starlark_tests:ios_sticker_pack_extension_tests.bzl",
    "ios_sticker_pack_extension_test_suite",
)
load(
    "//test/starlark_tests:ios_ui_test_tests.bzl",
    "ios_ui_test_test_suite",
)
load(
    "//test/starlark_tests:ios_unit_test_tests.bzl",
    "ios_unit_test_test_suite",
)

ios_application_test_suite()

ios_extension_test_suite()

ios_framework_test_suite()

ios_imessage_application_test_suite()

ios_sticker_pack_extension_test_suite()

ios_ui_test_test_suite()

ios_unit_test_test_suite()

test_suite(
    name = "all_tests",
)
