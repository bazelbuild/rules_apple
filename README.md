# Apple Rules for [Bazel](https://bazel.build)

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

[Click here](https://github.com/bazelbuild/rules_apple/tree/master/doc)
for the reference documentation for the rules and other definitions in this
repository.

## Quick setup

Add the following to your `WORKSPACE` file to add the external repositories,
replacing the version number in the `tag` attribute with the version of the
rules you wish to depend on:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_apple",
    sha256 = "84f34c95e68f65618b54c545f75e2df73559af47fb42ae28b17189fcebb7ed17",
    url = "https://github.com/bazelbuild/rules_apple/releases/download/0.31.1/rules_apple.0.31.1.tar.gz",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

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
    data = [
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
