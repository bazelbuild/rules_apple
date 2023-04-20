# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Definitions for handling Bazel repositories used by the Apple rules."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _colorize(text, color):
    """Applies ANSI color codes around the given text."""
    return "\033[1;{color}m{text}{reset}".format(
        color = color,
        reset = "\033[0m",
        text = text,
    )

def _green(text):
    return _colorize(text, "32")

def _yellow(text):
    return _colorize(text, "33")

def _warn(msg):
    """Outputs a warning message."""

    # buildifier: disable=print
    print("\n{prefix} {msg}\n".format(
        msg = msg,
        prefix = _yellow("WARNING:"),
    ))

def _maybe(repo_rule, name, ignore_version_differences, **kwargs):
    """Executes the given repository rule if it hasn't been executed already.

    Args:
      repo_rule: The repository rule to be executed (e.g.,
          `http_archive`.)
      name: The name of the repository to be defined by the rule.
      ignore_version_differences: If `True`, warnings about potentially
          incompatible versions of depended-upon repositories will be silenced.
      **kwargs: Additional arguments passed directly to the repository rule.
    """
    if native.existing_rule(name):
        if not ignore_version_differences:
            # Verify that the repository is being loaded from the same URL and tag
            # that we asked for, and warn if they differ.
            # TODO(allevato): This isn't perfect, because the user could load from the
            # same commit SHA as the tag, or load from an HTTP archive instead of a
            # Git repository, but this is a good first step toward validating.
            # Long-term, we should extend this function to support dependencies other
            # than Git.
            existing_repo = native.existing_rule(name)
            if (existing_repo.get("remote") != kwargs.get("remote") or
                existing_repo.get("tag") != kwargs.get("tag")):
                expected = "{url} (tag {tag})".format(
                    tag = kwargs.get("tag"),
                    url = kwargs.get("remote"),
                )
                existing = "{url} (tag {tag})".format(
                    tag = existing_repo.get("tag"),
                    url = existing_repo.get("remote"),
                )

                _warn("""\
`build_bazel_rules_apple` depends on `{repo}` loaded from {expected}, but we \
have detected it already loaded into your workspace from {existing}. You may \
run into compatibility issues. To silence this warning, pass \
`ignore_version_differences = True` to `apple_rules_dependencies()`.
""".format(
                    existing = _yellow(existing),
                    expected = _green(expected),
                    repo = name,
                ))
        return

    repo_rule(name = name, **kwargs)

def apple_rules_dependencies(ignore_version_differences = False, include_bzlmod_ready_dependencies = True):
    """Fetches repositories that are dependencies of the `rules_apple` workspace.

    Users should call this macro in their `WORKSPACE` to ensure that all of the
    dependencies of the Apple rules are downloaded and that they are isolated from
    changes to those dependencies.

    Args:
      ignore_version_differences: If `True`, warnings about potentially
          incompatible versions of depended-upon repositories will be silenced.
      include_bzlmod_ready_dependencies: Whether or not bzlmod-ready
             dependencies should be included.
    """

    if include_bzlmod_ready_dependencies:
        _maybe(
            http_archive,
            name = "bazel_skylib",
            urls = [
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
            ],
            sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
            ignore_version_differences = ignore_version_differences,
        )

        _maybe(
            http_archive,
            name = "build_bazel_apple_support",
            sha256 = "9a2338d6f8dad3244f823f2dc6084a03e4d0fbb27ca892dc970e6890d5b48184",
            urls = [
                "https://github.com/bazelbuild/apple_support/releases/download/1.5.0/apple_support.1.5.0.tar.gz",
            ],
            ignore_version_differences = ignore_version_differences,
        )

        _maybe(
            http_archive,
            name = "build_bazel_rules_swift",
            sha256 = "bf2861de6bf75115288468f340b0c4609cc99cc1ccc7668f0f71adfd853eedb3",
            urls = [
                "https://github.com/bazelbuild/rules_swift/releases/download/1.7.1/rules_swift.1.7.1.tar.gz",
            ],
            ignore_version_differences = ignore_version_differences,
        )

        _maybe(
            http_archive,
            name = "rules_xcodeproj",
            sha256 = "7967b372bd1777214ce65c87a82ac0630150b7504b443de0315ea52e45758e0c",
            urls = [
                "https://github.com/MobileNativeFoundation/rules_xcodeproj/releases/download/1.3.3/release.tar.gz",
            ],
            ignore_version_differences = ignore_version_differences,
            patch_cmds = [
                """\
build_file_additions=$(cat <<EOF
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//xcodeproj:for_bazel_tests",
    ],
    visibility = ["//visibility:public"],
)
EOF
)

echo "${build_file_additions}" >> BUILD

build_file_additions=$(cat <<EOF
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//xcodeproj/internal:for_bazel_tests",
    ],
    visibility = ["//visibility:public"],
)
EOF
)

chmod 777 xcodeproj/BUILD
echo "${build_file_additions}" >> xcodeproj/BUILD

build_file_additions=$(cat <<EOF
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = ["//visibility:public"],
)
EOF
)

chmod 777 xcodeproj/internal/BUILD
echo "${build_file_additions}" >> xcodeproj/internal/BUILD
""",
            ],
        )

    _maybe(
        http_archive,
        name = "xctestrunner",
        urls = [
            "https://github.com/google/xctestrunner/archive/24629f3e6c0dda397f14924b64eb45d04433c07e.tar.gz",
        ],
        strip_prefix = "xctestrunner-24629f3e6c0dda397f14924b64eb45d04433c07e",
        sha256 = "6e692722c3b3d5f2573357870c78febe8419b18ab28565bc6a1d9ddd28c8ec51",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "com_github_apple_swift-argument-parser",
        build_file_content = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ArgumentParser",
    srcs = glob(["Sources/ArgumentParser/**/*.swift"]),
    deps = [":ArgumentParserToolInfo"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "ArgumentParserToolInfo",
    srcs = glob(["Sources/ArgumentParserToolInfo/**/*.swift"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**/*"]),
    visibility = ["//visibility:public"],
)
""",
        sha256 = "44782ba7180f924f72661b8f457c268929ccd20441eac17301f18eff3b91ce0c",
        strip_prefix = "swift-argument-parser-1.2.2",
        url = "https://github.com/apple/swift-argument-parser/archive/refs/tags/1.2.2.tar.gz",
        ignore_version_differences = ignore_version_differences,
        patch_cmds = [
            # Bazel does not support paths with spaces. See: https://github.com/bazelbuild/bazel/issues/4327
            "mv 'Sources/ArgumentParser/Parsable Properties' 'Sources/ArgumentParser/ParsableProperties'",
            "mv 'Sources/ArgumentParser/Parsable Types' 'Sources/ArgumentParser/ParsableTypes'",
        ],
    )

    _maybe(
        http_archive,
        name = "com_github_jakeheis_SwiftCLI",
        build_file_content = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SwiftCLI",
    srcs = glob(["Sources/**/*.swift"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**/*"]),
    visibility = ["//visibility:public"],
)
""",
        sha256 = "8a86d45baa86e17c92d25a6ff65798593992204169a9e2616f61b6c5cd130bb1",
        strip_prefix = "SwiftCLI-6.0.3",
        url = "https://github.com/jakeheis/SwiftCLI/archive/refs/tags/6.0.3.tar.gz",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "com_github_mtynior_ColorizeSwift",
        build_file_content = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ColorizeSwift",
    srcs = glob(["Sources/**/*.swift"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**/*"]),
    visibility = ["//visibility:public"],
)
""",
        sha256 = "f36b4f06b50c1b9d6270da478d13173bf8f424e463d42e8027395a82ebfeeac8",
        strip_prefix = "ColorizeSwift-1.6.0",
        url = "https://github.com/mtynior/ColorizeSwift/archive/refs/tags/1.6.0.tar.gz",
        ignore_version_differences = ignore_version_differences,
    )
