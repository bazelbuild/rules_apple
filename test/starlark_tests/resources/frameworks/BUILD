load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")

package(
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

licenses(["notice"])

# The following target resides under this package due to conflicting actions
# generating the compiled Swift module interface file (`.swiftmodule`) from
# this target and the associated framework/XCFramework import rules which
# compile the Swift module interface file.
swift_library(
    name = "swift_library",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.swift"],
    features = [
        "swift.emit_swiftinterface",
        "swift.enable_library_evolution",
    ],
    generates_header = True,
    module_name = "iOSSwiftStaticFramework",
)

# Exports all files in this package as targets to make it easier to depend on them.
# Because these are for Starlark tests, we can scope the visibility to just this
# package.
exports_files(
    glob(["**"]),
    visibility = ["//test:__subpackages__"],
)
