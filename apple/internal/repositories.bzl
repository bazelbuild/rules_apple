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

def apple_rules_dependencies():
    """Fetches repositories that are dependencies of the `rules_apple` workspace.
    """

    http_archive(
        name = "xctestrunner",
        urls = [
            "https://github.com/google/xctestrunner/archive/8710f141dfb0a3efe2744f865f914783259c24b0.tar.gz",
        ],
        strip_prefix = "xctestrunner-8710f141dfb0a3efe2744f865f914783259c24b0",
        sha256 = "34d3b9bcb3dcb5b2a0bf2cd4be58c03f6a0f0eb4329f87cd758461aeb00e9326",
        patch_args = ["-p1"],
        patches = [
            # https://github.com/google/xctestrunner/pull/76
            "//tools/patches:xctestrunner_loads.patch",
            # https://github.com/google/xctestrunner/pull/71
            "//tools/patches:xctestrunner_framework.patch",
        ],
    )
