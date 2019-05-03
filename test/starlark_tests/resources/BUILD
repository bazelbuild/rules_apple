licenses(["notice"])

# Exports all files in this package as targets to make it easier to depend on them.
# Because these are for Starlark tests, we can scope the visibility to just this
# package.
exports_files(
    glob(["**"]),
    visibility = ["//test/starlark_tests:__subpackages__"],
)
