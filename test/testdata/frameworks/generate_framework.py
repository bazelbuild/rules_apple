# Lint as: python2, python3
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

from __future__ import absolute_import
from __future__ import print_function
import argparse
import os
import shutil
import subprocess
import sys

_PY3 = sys.version_info[0] == 3


def _check_output(args, custom_env=None):
  """Wrapper for subprocess, executes Popen and raises errors if found."""
  env = os.environ.copy()
  if custom_env:
    env.update(custom_env)
  proc = subprocess.Popen(
      args,
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      env=env)
  stdout, stderr = proc.communicate()

  # Only decode the output for Py3 so that the output type matches
  # the native string-literal type. This prevents Unicode{Encode,Decode}Errors
  # in Py2.
  if _PY3:
    # The invoked tools don't specify what encoding they use, so for lack of a
    # better option, just use utf8 with error replacement. This will replace
    # incorrect utf8 byte sequences with '?', which avoids UnicodeDecodeError
    # from raising.
    stdout = stdout.decode("utf8", "replace")
    stderr = stderr.decode("utf8", "replace")

  if proc.returncode != 0:
    # print the stdout and stderr, as the exception won't print it.
    print("ERROR:{stdout}\n\n{stderr}".format(stdout=stdout, stderr=stderr))
    raise subprocess.CalledProcessError(proc.returncode, args)
  return stdout, stderr


def _build_library_binary(archs, source_file, output_path):
  """Builds the library binary from a source file, writes to output_path."""
  output_lib = os.path.join(os.path.dirname(output_path),
                            os.path.basename(source_file) + ".o")

  # Start assembling the list of arguments with what we know will remain.
  # constant.
  library_cmd = ["xcrun", "-sdk", "iphonesimulator", "clang",
                 "-mios-simulator-version-min=11"]

  # Append archs.
  for arch in archs:
    library_cmd.extend([
        "-arch", arch
    ])

  # Append source file.
  library_cmd.extend([
      "-c", source_file
  ])

  # Add the output library.
  if os.path.exists(output_lib):
    os.remove(output_lib)
  library_cmd.extend([
      "-o", output_lib
  ])

  # Run the command to assemble the output library.
  stdout, stderr = _check_output(library_cmd)
  if stdout:
    print(stdout)
  if stderr:
    print(stderr)
  return output_lib


def _generate_dynamic_cmd(name, framework_path, archs):
  """Generate the common set of commands to create this dynamic framework."""
  framework_cmd = ["xcrun", "-sdk", "iphonesimulator", "clang",
                   "-fobjc-link-runtime", "-mios-simulator-version-min=11.0",
                   "-dynamiclib"]
  framework_cmd.extend([
      "-install_name",
      "@rpath/{}/{}".format(os.path.basename(framework_path), name),
  ])
  for arch in archs:
    framework_cmd.extend([
        "-arch",
        arch,
    ])

  return framework_cmd


def _build_framework_binary(name, framework_path, libtype, archs, source_file):
  """Builds the framework binary from a source file, saves to framework_path."""
  output_lib = _build_library_binary(archs, source_file, framework_path)

  # Delete any existing framework files, if they are already there.
  if os.path.exists(framework_path):
    shutil.rmtree(framework_path)
  os.makedirs(framework_path)

  # Run the command to assemble the framework output.
  framework_cmd = ""
  custom_env = None

  if libtype == "dynamic":
    framework_cmd = _generate_dynamic_cmd(name, framework_path, archs)
  elif libtype == "static":
    framework_cmd = ["xcrun", "libtool"]
    custom_env = {"ZERO_AR_DATE": "1"}
  else:
    print("Internal Error: Unexpected library type: {}".format(libtype))
    return 1
  framework_cmd.append(output_lib)
  framework_cmd.extend([
      "-o",
      os.path.join(framework_path, name),
  ])

  stdout, stderr = _check_output(framework_cmd, custom_env)
  if stdout:
    print(stdout)
  if stderr:
    print(stderr)
  return 0


def _generate_umbrella_header(name, header_path, header_files):
  """Generates a single umbrella header given a sequence of header files."""
  header_text = "#import <Foundation/Foundation.h>\n"
  for header_file in header_files:
    header_text += "#import <{}>\n".format(
        os.path.join(name, os.path.basename(header_file))
    )
  with open(os.path.join(header_path, name + ".h"), "w") as umbrella_header:
    umbrella_header.write(header_text)


def _generate_module_map(name, module_map_path):
  """Generates a single module map given a sequence of header files."""
  module_map_text = """
framework module {0} {{
  umbrella header "{0}.h"

  export *
  module * {{ export * }}
}}
""".format(name)
  if os.path.exists(module_map_path):
    shutil.rmtree(module_map_path)
  os.makedirs(module_map_path)
  with open(module_map_path + "/module.modulemap", "w") as module_map:
    module_map.write(module_map_text)


def _generate_xml_plist(name, plist_path):
  """Generates an XML Plist using the name as preferred identifier."""
  plist_text = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>{0}</string>
  <key>CFBundleIdentifier</key>
  <string>org.bazel.{0}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>{0}</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
</dict>
</plist>
""".format(name)
  with open(plist_path + "/Info.plist", "w") as infoplist:
    infoplist.write(plist_text)


def _copy_headers(name, framework_path, header_files):
  """Copies headers and generates text files to further reference them."""
  if header_files:
    header_path = framework_path + "/Headers"
    if os.path.exists(header_path):
      shutil.rmtree(header_path)
    os.makedirs(header_path)
    for header_file in header_files:
      shutil.copy2(header_file, header_path)

    _generate_umbrella_header(name, header_path, header_files)

    module_map_path = framework_path + "/Modules"
    _generate_module_map(name, module_map_path)


def main():
  parser = argparse.ArgumentParser(description="framework generator")
  parser.add_argument(
      "--name", type=str, required=True, help="name of the generated framework"
  )
  parser.add_argument(
      "--libtype", type=str, required=True, help="library type for the "
      "generated framework, can be `dynamic` or `static`"
  )
  parser.add_argument(
      "--framework_path", type=str, required=True, help="path to create the "
      "framework's contents in"
  )
  parser.add_argument(
      "--arch", type=str, action="append", required=True, help="binary slice "
      "architecture to build with for the final framework binary"
  )
  parser.add_argument(
      "--header_file", type=str, action="append", help="header files used to "
      "build the framework binary"
  )
  parser.add_argument(
      "--source_file", type=str, required=True, help="source file used to "
      "build the framework binary"
  )
  args = parser.parse_args()

  # Step 1: Build the framework binary, output to the framework path.
  status_code = _build_framework_binary(args.name, args.framework_path,
                                        args.libtype, args.arch,
                                        args.source_file)
  if status_code:
    return status_code

  # Step 2: Generate module maps, copy headers.
  _copy_headers(args.name, args.framework_path, args.header_file)

  # Step 3: Generate the Info.plist.
  _generate_xml_plist(args.name, args.framework_path)

  return status_code


if __name__ == "__main__":
  sys.exit(main())
