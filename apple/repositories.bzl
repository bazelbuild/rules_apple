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

def apple_rules_dependencies(ignore_version_differences = False):
    """Fetches repositories that are dependencies of the `rules_apple` workspace.

    Users should call this macro in their `WORKSPACE` to ensure that all of the
    dependencies of the Apple rules are downloaded and that they are isolated from
    changes to those dependencies.

    Args:
      ignore_version_differences: If `True`, warnings about potentially
          incompatible versions of depended-upon repositories will be silenced.
    """
    _maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
        ],
        sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "build_bazel_apple_support",
        sha256 = "741366f79d900c11e11d8efd6cc6c66a31bfb2451178b58e0b5edc6f1db17b35",
        urls = [
            "https://github.com/bazelbuild/apple_support/releases/download/0.10.0/apple_support.0.10.0.tar.gz",
        ],
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "build_bazel_rules_swift",
        urls = [
            "https://github.com/bazelbuild/rules_swift/releases/download/0.22.0/rules_swift.0.22.0.tar.gz",
        ],
        sha256 = "653e8756001616500b110fd156694de7899278bb7480aba22b2f156438a1d810",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "subpar",
        urls = [
            "https://github.com/google/subpar/archive/2.0.0.tar.gz",
        ],
        strip_prefix = "subpar-2.0.0",
        sha256 = "b80297a1b8d38027a86836dbadc22f55dc3ecad56728175381aa6330705ac10f",
        ignore_version_differences = ignore_version_differences,
    )

    _maybe(
        http_archive,
        name = "xctestrunner",
        urls = [
            "https://github.com/google/xctestrunner/archive/5a1b0c158f2debace60722ddbcb5035e3387810e.tar.gz",
        ],
        strip_prefix = "xctestrunner-5a1b0c158f2debace60722ddbcb5035e3387810e",
        sha256 = "cae8b4dc21f793161b45d48f00db56d04174de7dfcfb990da64a69c2d06a6450",
        ignore_version_differences = ignore_version_differences,
    )
