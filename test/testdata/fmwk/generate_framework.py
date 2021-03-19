#!/usr/bin/env python3
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

import argparse
import os
import shutil
import subprocess
import sys


_LIBTYPE_ARG = [
    "dynamic",
    "static",
]

_SDK_TO_VERSION_ARG = {
    "iphonesimulator": "-mios-simulator-version-min",
    "ios": "-miphoneos-version-min",
    "macosx": "-mmacos-version-min",
    "appletvsimulator": "-mtvos-simulator-version-min",
    "appletvos": "-mtvos-version-min",
    "watchsimulator": "-mwatchos-simulator-version-min",
    "watchos": "-mwatchos-version-min",
}


def _version_arg_for_sdk(sdk, minimum_os_version):
  """Returns the clang minimum version argument for a given SDK as a string."""
  return "{0}={1}".format(_SDK_TO_VERSION_ARG[sdk], minimum_os_version)


def _build_library_binary(archs, sdk, minimum_os_version, embed_bitcode,
                          embed_debug_info, source_file, output_path):
  """Builds the library binary from a source file, writes to output_path."""
  output_lib = os.path.join(os.path.dirname(output_path),
                            os.path.basename(source_file) + ".o")

  # Start assembling the list of arguments with what we know will remain.
  # constant.
  library_cmd = ["xcrun", "-sdk", sdk, "clang",
                 _version_arg_for_sdk(sdk, minimum_os_version)]

  if embed_bitcode:
    library_cmd.append("-fembed-bitcode")

  if embed_debug_info:
    library_cmd.append("-g")

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
  subprocess.check_call(library_cmd, env=os.environ.copy())
  return output_lib


def _generate_dynamic_cmd(name, sdk, minimum_os_version, framework_path, archs):
  """Generate the common set of commands to create this dynamic framework."""
  framework_cmd = ["xcrun", "-sdk", sdk, "clang", "-fobjc-link-runtime",
                   _version_arg_for_sdk(sdk, minimum_os_version), "-dynamiclib"]

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


def _build_framework_binary(name, sdk, minimum_os_version, framework_path,
                            libtype, embed_bitcode, embed_debug_info, archs,
                            source_file):
  """Builds the framework binary from a source file, saves to framework_path."""
  output_lib = _build_library_binary(archs, sdk, minimum_os_version,
                                     embed_bitcode, embed_debug_info,
                                     source_file, framework_path)

  # Delete any existing framework files, if they are already there.
  if os.path.exists(framework_path):
    shutil.rmtree(framework_path)
  os.makedirs(framework_path)

  # Run the command to assemble the framework output.
  custom_env = os.environ.copy()

  if libtype == "dynamic":
    framework_cmd = _generate_dynamic_cmd(name, sdk, minimum_os_version,
                                          framework_path, archs)
  elif libtype == "static":
    framework_cmd = ["xcrun", "libtool"]
    custom_env.update({"ZERO_AR_DATE": "1"})
  else:
    print("Internal Error: Unexpected library type: {}".format(libtype))
    return 1
  framework_cmd.append(output_lib)
  framework_cmd.extend([
      "-o",
      os.path.join(framework_path, name),
  ])

  if embed_bitcode:
    bcsymbolmap_path = os.path.join(os.path.dirname(framework_path),
                                    os.path.basename(name) + ".bcsymbolmap")
    framework_cmd.extend([
        "-fembed-bitcode",
        "-Xlinker",
        "-bitcode_verify",
        "-Xlinker",
        "-bitcode_hide_symbols",
        "-Xlinker",
        "-bitcode_symbol_map",
        "-Xlinker",
        bcsymbolmap_path,
    ])

  subprocess.check_call(framework_cmd, env=custom_env)
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
      "--sdk", type=str, required=True, choices=_SDK_TO_VERSION_ARG.keys(),
      help="sdk for the generated framework"
  )
  parser.add_argument(
      "--minimum_os_version", type=str, required=True, help="minimum OS "
      "version number for the generated framework"
  )
  parser.add_argument(
      "--libtype", type=str, required=True, choices=_LIBTYPE_ARG, help=
      "library type for the generated framework"
  )
  parser.add_argument(
      "--embed_bitcode", action="store_true", default=False, help="embed "
      "bitcode in the final framework binary"
  )
  parser.add_argument(
      "--embed_debug_info", action="store_true", default=False, help="embed "
      "debug information in the framework binary"
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
  status_code = _build_framework_binary(args.name, args.sdk,
                                        args.minimum_os_version,
                                        args.framework_path,
                                        args.libtype, args.embed_bitcode,
                                        args.embed_debug_info, args.arch,
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
