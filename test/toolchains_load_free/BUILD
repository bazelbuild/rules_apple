load("@bazel_skylib//rules:diff_test.bzl", "diff_test")

licenses(["notice"])

genquery(
    name = "toolchains_buildfiles",
    expression = "buildfiles(//apple/internal/toolchains:mac_toolchain_declaration)",
    scope = ["//apple/internal/toolchains:mac_toolchain_declaration"],
)

diff_test(
    name = "toolchains_load_free_test",
    size = "small",
    file1 = ":toolchains_buildfiles",
    file2 = "toolchains_buildfiles.golden",
)
