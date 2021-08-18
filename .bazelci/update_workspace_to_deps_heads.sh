#!/bin/bash

# Copyright 2019 The Bazel Authors. All rights reserved.
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

set -eu

# Modify the WORKSPACE to pull in the master branches of some deps.
/usr/bin/sed \
  -i "" \
  -e \
    's/apple_rules_dependencies()/apple_rules_dependencies(ignore_version_differences = True)/' \
  -e \
    '/^workspace.*/a \
\
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")\
\
git_repository(\
\    name = "bazel_skylib",\
\    remote = "https://github.com/bazelbuild/bazel-skylib.git",\
\    branch = "main",\
)\
\
git_repository(\
\    name = "build_bazel_apple_support",\
\    remote = "https://github.com/bazelbuild/apple_support.git",\
\    branch = "master",\
)\
\
git_repository(\
\    name = "build_bazel_rules_swift",\
\    remote = "https://github.com/bazelbuild/rules_swift.git",\
\    branch = "master",\
)\
' \
  WORKSPACE
