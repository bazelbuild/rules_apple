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

"""Actions that operate on modulemap files.

See documentation: https://clang.llvm.org/docs/Modules.html#module-map-language
"""

load("@build_bazel_rules_apple//apple/bundling:file_support.bzl",
     "file_support")
load("@build_bazel_rules_apple//apple/bundling:provider_support.bzl",
     "provider_support")


def _link_declarations(ctx):
  """Generates required link declarations for the current module.

  Args:
    ctx: The Skylark context.
  Returns:
    A list of library and framework link declarations against which a program
    should be linked if the module is imported.
  """
  # TODO(b/36513020): Generalize this by having the caller pass in dylibs and
  # frameworks rather than deriving them from the ctx.
  sdk_dylibs = depset()
  sdk_frameworks = depset()
  objc_providers = provider_support.matching_providers(ctx.attr.binary, "objc")
  for objc in objc_providers:
    sdk_frameworks += objc.sdk_framework
    sdk_dylibs += objc.sdk_dylib

  link_declarations = []
  for dylib in sdk_dylibs:
    # sdk_dylibs are passed in with a preceding "lib" e.g., libc++ - which
    # must be stripped for the link declarations in the module map - e.g., link
    # "c++".
    if not dylib.startswith("lib"):
      fail("linked sdk_dylib %s name must start with lib" % dylib)
    dylib_name = dylib[3:]
    link_declarations.append('link "%s"' % dylib_name)
  for framework_name in sdk_frameworks:
    link_declarations.append('link framework "%s"' % framework_name)
  return sorted(link_declarations)


def _framework_module_declaration(framework_name, members):
  """Generates a framework module declaration.

  Args:
    framework_name: The name of the framework module.
    members: Members including the headers that contribute to that module, its
        submodules, and other aspects of the module.
  Returns:
    A module declaration string.
  """
  module_declaration = ["framework module %s {" % framework_name]
  module_declaration += ["  " + member for member in members]
  module_declaration += ["}"]
  return "\n".join(module_declaration)


def _create_modulemap(ctx, framework_name, umbrella_header_filename):
  """Registers an action that creates a modulemap for the bundle.

  Args:
    ctx: The Skylark context.
    framework_name: The name of the framework.
    umbrella_header_filename: The name of the umbrella header for the framework.
  Returns:
    A modulemap `File` for the current module.
  """
  output_modulemap = file_support.intermediate(ctx, "%{name}-module.modulemap")

  module_members = [
      'umbrella header "%s"' % umbrella_header_filename,
      "export *",
      "module * { export * }"
  ]
  module_members += _link_declarations(ctx)

  module_declaration = _framework_module_declaration(framework_name,
                                                     module_members)
  ctx.file_action(output=output_modulemap, content=module_declaration)
  return output_modulemap


# Define the loadable module that lists the exported symbols in this file.
modulemap_actions = struct(
    create_modulemap=_create_modulemap,
)
