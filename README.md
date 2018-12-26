# Apple Rules for [Bazel](https://bazel.build)

[![Build Status](https://travis-ci.org/bazelbuild/rules_apple.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_apple)
[![Build status](https://badge.buildkite.com/cecd8d6951d939c6814f043af2935158f0556cb6c5fef3cb75.svg?branch=master)](https://buildkite.com/bazel/rules-apple-darwin)

This repository contains rules for [Bazel](https://bazel.build) that can be
used to bundle applications for Apple platforms.

These rules handle the linking and bundling of applications and extensions
(that is, the formation of an `.app` with an executable and resources,
archived in an `.ipa`). Compilation is still performed by the existing
[`objc_library` rule](https://bazel.build/versions/master/docs/be/objective-c.html#objc_library)
in Bazel, and by the
[`swift_library` rule](https://github.com/bazelbuild/rules_swift/blob/master/doc/rules.md#swift_library)
available from [rules_swift](https://github.com/bazelbuild/rules_swift).

## Reference documentation

[Click here](https://github.com/bazelbuild/rules_apple/tree/master/doc/index.md)
for the reference documentation for the rules and other definitions in this
repository.

## Quick setup

Add the following to your `WORKSPACE` file to add the external repositories,
replacing the version number in the `tag` attribute with the version of the
rules you wish to depend on:

```python
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "build_bazel_rules_apple",
    remote = "https://github.com/bazelbuild/rules_apple.git",
    tag = "0.11.0",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

git_repository(
    name = "build_bazel_rules_swift",
    remote = "https://github.com/bazelbuild/rules_swift.git",
    tag = "0.5.0",
)

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

git_repository(
    name = "build_bazel_apple_support",
    remote = "https://github.com/bazelbuild/apple_support.git",
    tag = "0.3.0",
)

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()
```

If you're going to use `ios_unit_test` or `ios_ui_test`, you'll also need to add
the following to your `WORKSPACE`, which is an external dependency needed to run
the tests.

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

http_file(
    name = "xctestrunner",
    executable = 1,
    urls = ["https://github.com/google/xctestrunner/releases/download/0.2.5/ios_test_runner.par"],
)
```

## Examples

Minimal example:

```python
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

objc_library(
    name = "Lib",
    srcs = glob([
        "**/*.h",
        "**/*.m",
    ]),
    resources = [
        ":Main.storyboard",
    ],
)

# Links code from "deps" into an executable, collects and compiles resources
# from "deps" and places them with the executable in an .app bundle, and then
# outputs an .ipa with the bundle in its Payload directory.
ios_application(
    name = "App",
    bundle_id = "com.example.app",
    families = ["iphone", "ipad"],
    infoplists = [":Info.plist"],
    deps = [":Lib"],
)
```

See the [examples](https://github.com/bazelbuild/rules_apple/tree/master/examples)
directory for sample applications.
