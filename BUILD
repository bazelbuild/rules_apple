package(default_visibility = ["//visibility:public"])

licenses(["notice"])

exports_files(["LICENSE"])

# Targets that are built by Bazel CI that are not tests.
#
# By default, Bazel CI would build "//...", but this also ends up
# building targets like objc_libraries that do not build on their
# own because they require a platform type to be passed down by
# the apple_binary that depends on them. So, we explicitly list
# any targets here that we want to build (such as the example
# apps).
filegroup(
    name = "for_bazel_ci_build",
    srcs = [
        "//examples/ios/HelloWorld",
        "//examples/ios/HelloWorldSwift",
        "//examples/macos/CommandLine",
        "//examples/macos/CommandLineSwift",
        "//examples/macos/HelloToday",
        "//examples/macos/HelloWorld",
        "//examples/macos/HelloWorldSwift",
        "//examples/tvos/HelloWorld",
        "//examples/watchos/HelloWorld",
    ],
)

# Targets that are built and tested by Bazel CI, not including
# "//test/..."" (which is part of the CI config).
filegroup(
    name = "for_bazel_ci_test",
    srcs = [
        "//examples/ios/Squarer:SquarerTests",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = [
        "WORKSPACE",
        "//apple:for_bazel_tests",
        "//common:for_bazel_tests",
        "//tools:for_bazel_tests",
    ],
    visibility = ["//:__subpackages__"],
)
