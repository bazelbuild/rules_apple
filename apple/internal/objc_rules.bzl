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

"""Implementation of objc rules."""

def _objc_category_linkage_file_impl(ctx):
    """Implementation of objc_category_linkage_file.

    Creates a source file with a unique symbol in it so that the linker does not
    generate warnings at link time for static libraries with no symbols in them.
    """
    output = ctx.outputs.out
    label = _label_to_c_symbol(ctx.label)
    content = '__attribute__((visibility("default"))) char k{}_ExportToSuppressLibToolWarning = 0;'.format(label)
    ctx.actions.write(output = output, content = content)

objc_category_linkage_file = rule(
    implementation = _objc_category_linkage_file_impl,
    outputs = {"out": "%{name}.c"},
)

def _string_to_c_symbol(in_string):
    """Converts a string to a valid c symbol

    Args:
      in_string: string to convert

    Returns:
      converted string
    """
    out_string = ""
    for sub in in_string.elems():
        if sub.isalnum():
            out_string = out_string + sub
        else:
            out_string = out_string + "_"
    return out_string

def _label_to_c_symbol(in_label):
    """Converts a label to a valid c symbol

    Args:
      in_label: label to convert

    Returns:
      converted string
    """
    workspace = _string_to_c_symbol(in_label.workspace_root)
    package = _string_to_c_symbol(in_label.package)
    name = _string_to_c_symbol(in_label.name)
    return "{}_{}_{}".format(workspace, package, name)
