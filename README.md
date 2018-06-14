# Apple Rules for [Bazel](https://bazel.build)

[![Build Status](https://travis-ci.org/bazelbuild/rules_apple.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_apple)
[![Build status](https://badge.buildkite.com/cecd8d6951d939c6814f043af2935158f0556cb6c5fef3cb75.svg)](https://buildkite.com/bazel/rules-apple-darwin)

This repository contains rules for [Bazel](https://bazel.build) that can be
used to bundle applications for Apple platforms. They replace the bundling
rules defined in Bazel itself (such as `ios_application`, `ios_extension`, and
`apple_watch2_extension`). This repository also contains rules that run XCTest
based unit and UI tests, replacing the Bazel `ios_test` rule.

These rules handle the linking and bundling of applications and extensions
(that is, the formation of an `.app` with an executable and resources,
archived in an `.ipa`). Compilation is still performed by the existing
[`objc_library` rule](https://bazel.build/versions/master/docs/be/objective-c.html#objc_library)
in Bazel; to link those dependencies, these bundling rules use Bazel's
[`apple_binary` rule](https://bazel.build/versions/master/docs/be/objective-c.html#apple_binary)
under the hood.

## Reference documentation

[Click here](https://github.com/bazelbuild/rules_apple/tree/master/doc/index.md)
for the reference documentation for the rules and other definitions in this
repository.

## Quick setup

Add the following to your `WORKSPACE` file to add the external repositories,
replacing the version number in the `tag` attribute with the version of the
rules you wish to depend on:

```python
git_repository(
    name = "build_bazel_rules_apple",
    remote = "https://github.com/bazelbuild/rules_apple.git",
    tag = "0.5.0",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)
apple_rules_dependencies()
```

If you're going to use `ios_unit_test` or `ios_ui_test`, you'll also need to add
the following to your `WORKSPACE`, which is an external dependency needed to run
the tests.

```python
http_file(
    name = "xctestrunner",
    executable = 1,
    url = "https://github.com/google/xctestrunner/releases/download/0.2.3/ios_test_runner.par",
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

## Migrating from the built-in rules

Even though the rules in this repository have the same names as their built-in
counterparts, they cannot be intermixed; for example, an `ios_application` from
this repository cannot have an extension that is a built-in `ios_extension` or
vice versa.

The wiki for this repository contains a
[migration guide](https://github.com/bazelbuild/rules_apple/wiki/Migrating-from-the-native-rules)
describing in detail the differences between the old and new rules and how to
update your build targets.

## Coming soon

* Support for compiling texture atlases
* Improved rules for creating resource bundles
