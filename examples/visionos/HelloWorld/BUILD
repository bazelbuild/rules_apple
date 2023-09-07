load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//apple:visionos.bzl", "visionos_application")
load("//apple:versioning.bzl", "apple_bundle_version")

swift_library(
    name = "Sources",
    srcs = [
        "Sources/App.swift",
    ],
)

apple_bundle_version(
    name = "HelloWorldVersion",
    build_version = "1.0",
)

visionos_application(
    name = "HelloWorld",
    bundle_id = "com.example.hello-world",
    infoplists = [":Info.plist"],
    minimum_os_version = "1.0",
    target_compatible_with = select({
        "//:supports_visionos_setting": [],
        "//conditions:default": ["@platforms//:incompatible"],
    }),
    version = ":HelloWorldVersion",
    deps = [":Sources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    target_compatible_with = select({
        "//:supports_visionos_setting": [],
        "//conditions:default": ["@platforms//:incompatible"],
    }),
    targets = [":HelloWorld"],
)
