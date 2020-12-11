# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Support functions for modules operations."""

load(
    "@bazel_skylib//lib:types.bzl",
    "types",
)

# Copied from @rules_swift///internal:compiling.bzl
def _derive_module_name(*args):
    """Returns a derived module name from the given build label.

    For targets whose module name is not explicitly specified, the module name
    is computed by creating an underscore-delimited string from the components
    of the label, replacing any non-identifier characters also with underscores.

    This mapping is not intended to be reversible.

    Args:
        *args: Either a single argument of type `Label`, or two arguments of
            type `str` where the first argument is the package name and the
            second argument is the target name.

    Returns:
        The module name derived from the label.
    """
    if (len(args) == 1 and
        hasattr(args[0], "package") and
        hasattr(args[0], "name")):
        label = args[0]
        package = label.package
        name = label.name
    elif (len(args) == 2 and
          types.is_string(args[0]) and
          types.is_string(args[1])):
        package = args[0]
        name = args[1]
    else:
        fail("derive_module_name may only be called with a single argument " +
             "of type 'Label' or two arguments of type 'str'.")

    package_part = (package.lstrip("//").replace("/", "_").replace("-", "_")
        .replace(".", "_"))
    name_part = name.replace("-", "_")
    if package_part:
        return package_part + "_" + name_part
    return name_part

modules = struct(
    derive_name = _derive_module_name
)
