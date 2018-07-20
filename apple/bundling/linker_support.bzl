# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Support functions for interacting with the linker."""

def _sectcreate_objc_provider(segname, sectname, file):
    """Returns an objc provider that propagates a section in a linked binary.

    This function creates a new objc provider that contains the necessary linkopts
    to create a new section in the binary to which the provider is propagated; it
    is equivalent to the `ld` flag `-sectcreate segname sectname file`. This can
    be used, for example, to embed entitlements in a simulator executable (since
    they are not applied during code signing).

    Args:
      segname: The name of the segment in which the section will be created.
      sectname: The name of the section to create.
      file: The file whose contents will be used as the content of the section.

    Returns:
      An objc provider that propagates the section linkopts.
    """

    # linkopts get deduped, so use a single option to pass then through as a
    # set.
    linkopts = ["-Wl,-sectcreate,%s,%s,%s" % (segname, sectname, file.path)]
    return apple_common.new_objc_provider(
        linkopt = depset(linkopts, order = "topological"),
        link_inputs = depset([file]),
    )

# Define the loadable module that lists the exported symbols in this file.
linker_support = struct(
    sectcreate_objc_provider = _sectcreate_objc_provider,
)
