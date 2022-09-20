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

"""Rules to generate dSYM bundle from given framework for testing."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")

def _dsym_info_plist_content(framework_name):
    return """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleIdentifier</key>
    <string>com.apple.xcode.dsym.{}.framework.dSYM</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>dSYM</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
  </dict>
</plist>
""".format(framework_name)

def _get_framework_binary_file(framework_imports, framework_binary_path):
    for framework_import in framework_imports:
        if framework_import.path == framework_binary_path:
            return framework_import

    fail("Framework must contain a binary named after the framework")

def _generate_import_framework_dsym_impl(ctx):
    framework_imports = ctx.files.framework_imports
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "framework_imports",
    )

    framework_dir = framework_groups.keys()[0]
    framework_dir_name = paths.basename(framework_dir)
    framework_name = paths.split_extension(framework_dir_name)[0]
    framework_binary_path = paths.join(framework_dir, framework_name)

    framework_binary = _get_framework_binary_file(
        framework_imports,
        framework_binary_path,
    )
    inputs = [framework_binary]

    dsym_dir_name = framework_dir_name + ".dSYM"

    # Generate dSYM bundle's DWARF binary
    dsym_binary_file = ctx.actions.declare_file(
        paths.join(
            dsym_dir_name,
            "Contents",
            "Resources",
            "DWARF",
            framework_name,
        ),
    )
    args = ctx.actions.args()
    args.add("dsymutil")
    args.add("--flat")
    args.add("--out", dsym_binary_file)
    args.add(framework_binary)
    apple_support.run(
        ctx,
        inputs = inputs,
        outputs = [dsym_binary_file],
        executable = "/usr/bin/xcrun",
        arguments = [args],
        mnemonic = "GenerateImportedAppleFrameworkDsym",
    )

    # Write dSYM bundle's Info.plist
    dsym_info_plist = ctx.actions.declare_file(
        paths.join(dsym_dir_name, "Contents", "Info.plist"),
    )
    ctx.actions.write(
        content = _dsym_info_plist_content(framework_name),
        output = dsym_info_plist,
    )

    outputs = [dsym_binary_file, dsym_info_plist]

    return [
        DefaultInfo(files = depset(outputs)),
    ]

generate_import_framework_dsym = rule(
    implementation = _generate_import_framework_dsym_impl,
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "framework_imports": attr.label_list(
            allow_files = True,
            doc = "The list of files under a `.framework` directory.",
        ),
    }),
    fragments = ["apple"],
    doc = """
Generates a dSYM bundle from given framework for testing. NOTE: The generated
dSYM's DWARF binary doesn't actually contain any debug symbol.
""",
)
