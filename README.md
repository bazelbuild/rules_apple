# Apple Rules for [Bazel](https://bazel.build)

> :warning: **NOTE**: At the time of this writing, the most recent Bazel
> release is **0.4.5.** These rules are *not* compatible with that release;
> they are only compatible with Bazel at **master**. Until the next release of
> Bazel, you will need to
> [build Bazel from source](https://bazel.build/versions/master/docs/install-compile-source.html)
> if you wish to use them.

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

[Click here](https://github.com/bazelbuild/rules_apple/tree/master/apple/doc/index.md)
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
    tag = "0.0.1",
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

* macOS support
* Support for compiling texture atlases
* Improved rules for creating resource bundles
