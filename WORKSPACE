workspace(name = "build_bazel_rules_apple")

load("//apple:repositories.bzl", "apple_rules_dependencies")

apple_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()

# Setup the Skylib dependency, this is required to use the Starlark unittest
# framework. Since this is only used for rules_apple's tests, we configure it
# here in the WORKSPACE file. This also can't be added to
# `apple_rules_dependencies()` since we need to load the bzl file, so if we
# wanted to load it inside of a macro, it would need to be in a different file
# to begin with.
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()
