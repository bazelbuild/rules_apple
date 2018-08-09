workspace(name = "build_bazel_rules_apple")

load("//apple:repositories.bzl", "apple_rules_dependencies")

apple_rules_dependencies()

# Used by our integration tests, but not a required dependency for all users of
# these rules.

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

http_file(
    name = "xctestrunner",
    executable = 1,
    url = "https://github.com/google/xctestrunner/releases/download/0.2.3/ios_test_runner.par",
)
