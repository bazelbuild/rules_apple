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

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

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

def apple_rules_dependencies(ignore_version_differences = False):
    """Fetches repositories that are dependencies of the `rules_apple` workspace.

    Users should call this macro in their `WORKSPACE` to ensure that all of the
    dependencies of the Swift rules are downloaded and that they are isolated from
    changes to those dependencies.

    Args:
      ignore_version_differences: If `True`, warnings about potentially
          incompatible versions of depended-upon repositories will be silenced.
    """
    _maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/0.8.0/bazel-skylib.0.8.0.tar.gz",
        ],
        sha256 = "2ef429f5d7ce7111263289644d233707dba35e39696377ebab8b0bc701f7818e",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "build_bazel_apple_support",
        urls = [
            "https://github.com/bazelbuild/apple_support/releases/download/0.6.0/apple_support.0.6.0.tar.gz",
        ],
        sha256 = "7356dbd44dea71570a929d1d4731e870622151a5f27164d966dda97305f33471",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "build_bazel_rules_swift",
        urls = [
            "https://github.com/bazelbuild/rules_swift/releases/download/0.8.0/rules_swift.0.8.0.tar.gz",
        ],
        sha256 = "31aad005a9c4e56b256125844ad05eb27c88303502d74138186f9083479f93a6",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_file,
        name = "xctestrunner",
        executable = 1,
        sha256 = "126cb383a02d2f4f6991d6094c3d7e004a8a1f3a9d0b77760cd1cfeabbba6fef",
        urls = ["https://github.com/google/xctestrunner/releases/download/0.2.7/ios_test_runner.par"],
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        new_git_repository,
        name = "com_github_libusb_libusb",
        commit = "c14ab5fc4d22749aab9e3534d56012718a0b0f67",
        remote = "git@github.com:libusb/libusb.git",
        build_file = "@build_bazel_rules_apple//:third_party/com_github_libusb_libusb/BUILD.bazel.in",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        git_repository,
        name = "boringssl",
        commit = "96666abbe1604161201e18f2704b8db1774107d8",
        remote = "https://boringssl.googlesource.com/boringssl",
        patches = [
            "@build_bazel_rules_apple//:third_party/boringssl/0001-Add-decrepit-x509-helpers.patch",
        ],
        patch_args = ["-p1"],
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        new_git_repository,
        name = "com_github_libimobiledevice_libusbmuxd",
        commit = "c75605d862cd1c312494f6c715246febc26b2e05",
        remote = "git@github.com:libimobiledevice/libusbmuxd.git",
        build_file = "@build_bazel_rules_apple//:third_party/com_github_libimobiledevice_libusbmuxd/BUILD.bazel.in",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        new_git_repository,
        name = "com_github_libimobiledevice_libimobiledevice",
        commit = "0584aa90c93ff6ce46927b8d67887cb987ab9545",
        remote = "git@github.com:libimobiledevice/libimobiledevice.git",
        build_file = "@build_bazel_rules_apple//:third_party/com_github_libimobiledevice_libimobiledevice/BUILD.bazel.in",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        new_git_repository,
        name = "com_github_libimobiledevice_libplist",
        commit = "bec850fe399639f3b8582a39386216970dea15ed",
        remote = "git@github.com:libimobiledevice/libplist.git",
        build_file = "@build_bazel_rules_apple//:third_party/com_github_libimobiledevice_libplist/BUILD.bazel.in",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        new_git_repository,
        name = "com_github_libimobiledevice_ideviceinstaller",
        commit = "f14def7cd9303a0fe622732fae9830ae702fdd7c",
        remote = "git@github.com:libimobiledevice/ideviceinstaller.git",
        build_file = "@build_bazel_rules_apple//:third_party/com_github_libimobiledevice_ideviceinstaller/BUILD.bazel.in",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "org_libzip",
        urls = ["https://libzip.org/download/libzip-1.5.2.tar.gz"],
        strip_prefix = "libzip-1.5.2",
        build_file = "@build_bazel_rules_apple//:third_party/org_libzip/BUILD.bazel.in",
        sha256 = "be694a4abb2ffe5ec02074146757c8b56084dbcebf329123c84b205417435e15",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "net_zlib",
        urls = ["https://zlib.net/zlib-1.2.11.tar.gz"],
        strip_prefix = "zlib-1.2.11",
        sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
        build_file = "@build_bazel_rules_apple//:third_party/net_zlib/BUILD.bazel.in",
        ignore_version_differences = ignore_version_differences,
    )
