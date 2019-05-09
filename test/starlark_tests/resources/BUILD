licenses(["notice"])

package(
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

# Exports all files in this package as targets to make it easier to depend on them.
# Because these are for Starlark tests, we can scope the visibility to just this
# package.
exports_files(
    glob(["**"]),
    visibility = ["//test/starlark_tests:__subpackages__"],
)

objc_library(
    name = "objc_shared_lib",
    srcs = ["shared.m"],
)

objc_library(
    name = "objc_main_lib",
    srcs = ["main.m"],
)

objc_library(
    name = "objc_test_lib",
    srcs = ["test.m"],
)
