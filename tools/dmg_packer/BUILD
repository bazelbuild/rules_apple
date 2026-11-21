licenses(["notice"])

# The `dmg-packer` tool from https://github.com/JetBrains/go-dmg-packer. It packs
# a macOS `.app` bundle into a `.dmg` without `hdiutil`, so it runs on any exec
# platform. Its version is pinned in the `go.mod` of this package.
alias(
    name = "dmg_packer",
    actual = "@com_github_jetbrains_go_dmg_packer//cmd/dmg-packer",
    visibility = ["//visibility:public"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = glob(["**"]),
    visibility = [
        "//tools:__pkg__",
    ],
)
