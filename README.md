# Apple Rules for [Bazel](https://bazel.build)

[![Build status](https://badge.buildkite.com/cecd8d6951d939c6814f043af2935158f0556cb6c5fef3cb75.svg?branch=master)](https://buildkite.com/bazel/rules-apple-darwin)

This repository contains rules for [Bazel](https://bazel.build) that can be
used to bundle applications for Apple platforms.

These rules handle the linking and bundling of applications and extensions
(that is, the formation of an `.app` with an executable and resources,
archived in an `.ipa`). Compilation is still performed by the existing
[`objc_library` rule](https://bazel.build/reference/be/objective-c#objc_library)
in Bazel, and by the
[`swift_library` rule](https://github.com/bazelbuild/rules_swift/blob/master/doc/rules.md#swift_library)
available from [rules_swift](https://github.com/bazelbuild/rules_swift).

If you are looking for an easy way to build mixed language frameworks, check out [rules_ios](https://github.com/bazel-ios/rules_ios).

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
    sha256 = "36072d4f3614d309d6a703da0dfe48684ec4c65a89611aeb9590b45af7a3e592",
    url = "https://github.com/bazelbuild/rules_apple/releases/download/1.0.1/rules_apple.1.0.1.tar.gz",
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
    "@build_bazel_rules_swift//swift:extras.bzl",
    "swift_rules_extra_dependencies",
)

swift_rules_extra_dependencies()

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
    minimum_os_version = "15.0",
    deps = [":Lib"],
)
```

See the [examples](https://github.com/bazelbuild/rules_apple/tree/master/examples)
directory for sample applications.

## Supported bazel versions

rules_apple and rules_swift are often affected by changes in bazel
itself. This means you generally need to update these rules as you
update bazel.

You can also see the supported bazel versions in the notes for each
release on the [releases
page](https://github.com/bazelbuild/rules_apple/releases).

Besides these constraint this repo follows [semver](https://semver.org/)
as best as we can since the 1.0.0 release.

| Bazel release | Minimum supported rules version | Final supported rules version|
|:-------------------:|:-------------------:|:-------------------------:|
| 6.x (most recent rolling) | 0.34.2 | current |
| 5.x | 0.33.0 | current |
| 4.x | 0.30.0 | 0.32.0 |
| 3.x | 0.20.0 | 0.21.2 |
