# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Partial implementation for gathering cc_info dylibs."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)

def _cc_info_dylibs_partial_impl(
        *,
        embedded_targets):
    """Implementation for the CcInfo dylibs processing partial."""
    bundle_files = []

    for target in embedded_targets:
        cc_info = target[CcInfo]
        for linker_input in cc_info.linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                if library.dynamic_library:
                    bundle_files.append(
                        (processor.location.framework, None, depset([library.dynamic_library])),
                    )

    return struct(bundle_files = bundle_files)

def cc_info_dylibs_partial(
        *,
        embedded_targets):
    """Constructor for the CcInfo dylibs processing partial.

    Args:
        embedded_targets: The list of targets that may have CcInfo specifying dylibs that need to be bundled.

    Returns:
      A partial that returns the bundle location of all dylibs contained in the embedded_targets CcInfo, if there were any to
      bundle.
    """
    return partial.make(
        _cc_info_dylibs_partial_impl,
        embedded_targets = embedded_targets,
    )
