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

"""Proxy file for referencing resource processing actions."""

load(
    "@build_bazel_rules_apple//apple/bundling/experimental/resource_actions:actool.bzl",
    _compile_asset_catalog="compile_asset_catalog",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/resource_actions:datamodel.bzl",
    _compile_datamodels="compile_datamodels",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/resource_actions:ibtool.bzl",
    _compile_storyboard="compile_storyboard",
    _link_storyboards="link_storyboards",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/resource_actions:plist.bzl",
    _compile_plist="compile_plist",
    _merge_resource_infoplists="merge_resource_infoplists",
    _merge_root_infoplists="merge_root_infoplists",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/resource_actions:png.bzl",
    _copy_png="copy_png",
)

resource_actions = struct(
    compile_asset_catalog=_compile_asset_catalog,
    compile_datamodels=_compile_datamodels,
    compile_plist=_compile_plist,
    compile_storyboard=_compile_storyboard,
    copy_png=_copy_png,
    link_storyboards=_link_storyboards,
    merge_resource_infoplists=_merge_resource_infoplists,
    merge_root_infoplists=_merge_root_infoplists,
)
