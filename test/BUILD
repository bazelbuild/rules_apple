licenses(["notice"])

# Export shell test utilities so can can be pulled in as data to the tests.
exports_files(["apple_shell_testutils.sh"])

# List of dependencies to be used in Starlark verifier tests.
filegroup(
    name = "apple_verification_test_deps",
    testonly = 1,
    srcs = [
        "apple_shell_testutils.sh",
        "unittest.bash",
    ],
    visibility = [
        "//test/starlark_tests:__subpackages__",
    ],
)
