# TODO(nglevin): describe this package.

load(
    "//apple:visionos.bzl",
    "visionos_application",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

visionos_application(
    name = "app",
    app_icons = ["//test/starlark_tests/resources:VisionAppIcon.xcassets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_visionos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_visionos.mobileprovision",
    tags = common.fixture_tags,
)
