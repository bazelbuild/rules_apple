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

"""Support functions for working with framework-related artifacts."""


def _get_link_declarations(dylibs=[], frameworks=[]):
  """Returns the module map lines that link to the given dylibs and frameworks.

  Args:
    dylibs: A sequence of library names (which must begin with "lib") that will
        be referenced in the module map.
    frameworks: A sequence of framework names that will be referenced in the
        module map.
  Returns:
    A list of "link" and "link framework" lines that reference the given
    libraries and frameworks.
  """
  link_lines = []

  for dylib in dylibs:
    if not dylib.startswith("lib"):
      fail("Linked libraries must start with 'lib' but found %s", dylib)
    link_lines.append('link "%s"' % dylib[3:])
  for framework in frameworks:
    link_lines.append('link framework "%s"' % framework)

  return link_lines


def _get_umbrella_header_declaration(basename):
  """Returns the module map line that references an umbrella header.

  Args:
    basename: The basename of the umbrella header file to be referenced in the
        module map.
  Returns:
    The module map line that references the umbrella header.
  """
  return 'umbrella header "%s"' % basename


def _create_modulemap(
    actions,
    output,
    module_name,
    umbrella_header_name,
    sdk_dylibs,
    sdk_frameworks):
  """Creates a modulemap for a framework.

  Args:
    actions: The actions module from a rule or aspect context.
    output: A declared `File` to which the module map will be written.
    module_name: The name of the module to declare in the module map file.
    umbrella_header_name: The basename of the umbrella header file, or None if
        there is no umbrella header.
    sdk_dylibs: A list of system dylibs to list in the module.
    sdk_frameworks: A list of system frameworks to list in the module.
  """
  declarations = []
  if umbrella_header_name:
      declarations.append(
          _get_umbrella_header_declaration(umbrella_header_name))
  declarations.extend([
      "export *",
      "module * { export *}",
  ])
  declarations.extend(_get_link_declarations(sdk_dylibs, sdk_frameworks))

  content = (
      ("framework module %s {\n" % module_name) +
      "\n".join(["  " + decl for decl in declarations]) +
      "}\n"
  )
  actions.write(output=output, content=content)


def _create_umbrella_header(actions, output, headers):
  """Creates an umbrella header that imports a list of other headers.

  Args:
    actions: The `actions` module from a rule or aspect context.
    output: A declared `File` to which the umbrella header will be written.
    headers: A list of header files to be imported by the umbrella header.
  """
  import_lines = ['#import "%s"' % f.basename for f in headers]
  content = "\n".join(import_lines) + "\n"
  actions.write(output=output, content=content)


# Define the loadable module that lists the exported symbols in this file.
framework_support = struct(
    create_modulemap=_create_modulemap,
    create_umbrella_header=_create_umbrella_header,
)
