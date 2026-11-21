# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""
Rule for packaging a macOS application into a .dmg disk image.
"""

load(
    "//apple:providers.bzl",
    "AppleBundleInfo",
)

# 2000-01-01T00:00:00Z. The packer stamps every catalog record of the volume
# with one time, so a fixed default keeps the image byte-stable across builds.
_DEFAULT_TIMESTAMP = 946684800

_FORMATS = {
    "UDRO": "udro",
    "UDZO": "udzo",
}

# The archive formats `dmg-packer` reads. It picks the format from the file
# extension. The longer extensions come first, so `.tar.gz` is not taken for
# `.gz`.
_ARCHIVE_EXTENSIONS = [".tar.gz", ".tgz", ".tar", ".zip"]

def _archive_stem(archive):
    for extension in _ARCHIVE_EXTENSIONS:
        if archive.basename.endswith(extension):
            return archive.basename[:-len(extension)]
    return archive.basename

def _bundle_input(ctx):
    """Returns the bundle to pack and the default volume name for it."""
    if bool(ctx.attr.app) == bool(ctx.attr.archive):
        fail("macos_dmg needs exactly one of `app` or `archive`.")

    if ctx.attr.archive:
        return ctx.file.archive, _archive_stem(ctx.file.archive)

    bundle_info = ctx.attr.app[AppleBundleInfo]
    if bundle_info.platform_type != "macos" or bundle_info.bundle_extension != ".app":
        fail(
            "macos_dmg can only package a macOS `.app` bundle, but {} is a {} `{}` bundle.".format(
                ctx.attr.app.label,
                bundle_info.platform_type,
                bundle_info.bundle_extension,
            ),
        )

    # The bundle archive is either a `.zip` holding `<name>.app` at its top
    # level, or a `<name>.app` tree artifact. The packer reads both directly.
    return bundle_info.archive, bundle_info.bundle_name

def _create_dmg(
        *,
        actions,
        dmg_packer,
        bundle,
        output,
        volume_name,
        background = None,
        format = "UDZO",
        partition_map = True,
        timestamp = _DEFAULT_TIMESTAMP,
        execution_requirements = {}):
    """Registers the action of `macos_dmg`, for a rule that must declare the disk image itself.

    Args:
      actions: The `actions` object of the rule context.
      dmg_packer: The executable of `@rules_apple//tools/dmg_packer`, built for
        the exec platform.
      bundle: The `File` to pack: a `.app` tree artifact, or an archive that the
        `archive` attribute of `macos_dmg` accepts.
      output: The `File` of the `.dmg` to write.
      volume_name: The volume name shown in Finder.
      background: See the `background` attribute of `macos_dmg`.
      format: See the `format` attribute of `macos_dmg`.
      partition_map: See the `partition_map` attribute of `macos_dmg`.
      timestamp: See the `timestamp` attribute of `macos_dmg`.
      execution_requirements: Additional execution requirements of the action.
    """
    args = actions.args()
    args.add("-app", bundle.path)
    args.add("-out", output)
    args.add("-name", volume_name)
    args.add("-mode", _FORMATS[format])
    args.add("-time", str(timestamp))
    args.add("-partition=%s" % ("true" if partition_map else "false"))

    inputs = [bundle]
    if background:
        args.add("-background", background)
        inputs.append(background)

    execution_requirements = dict(execution_requirements)
    if bundle.is_directory:
        # A sandbox stages every file of a tree artifact as an absolute symlink
        # into the execroot. The packer copies symlinks as symlinks, because a
        # bundle's own ones must stay links, so it would pack the sandbox links
        # instead of the files. Reading the tree artifact in place avoids that.
        execution_requirements["no-sandbox"] = "1"

    actions.run(
        executable = dmg_packer,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "MacosDmg",
        progress_message = "Packaging %{label} into a DMG",
        execution_requirements = execution_requirements,
    )

dmg_support = struct(
    create_dmg = _create_dmg,
)

def _macos_dmg_impl(ctx):
    bundle, default_volume_name = _bundle_input(ctx)

    dmg = ctx.actions.declare_file("%s.dmg" % ctx.label.name)

    _create_dmg(
        actions = ctx.actions,
        dmg_packer = ctx.executable._dmg_packer,
        bundle = bundle,
        output = dmg,
        volume_name = ctx.attr.volume_name or default_volume_name,
        background = ctx.file.background,
        format = ctx.attr.format,
        partition_map = ctx.attr.partition_map,
        timestamp = ctx.attr.timestamp,
    )

    return [
        DefaultInfo(files = depset([dmg])),
    ]

macos_dmg = rule(
    implementation = _macos_dmg_impl,
    attrs = {
        "app": attr.label(
            providers = [AppleBundleInfo],
            doc = """\
The macOS application to package, for example a `macos_application` target.
Exactly one of `app` or `archive` must be set.
""",
        ),
        "archive": attr.label(
            allow_single_file = _ARCHIVE_EXTENSIONS,
            doc = """\
An archive holding the macOS application to package: a `.zip`, `.tar`,
`.tar.gz` or `.tgz` file with one `.app` folder at its top level. Loose files
beside the folder are ignored. Exactly one of `app` or `archive` must be set.

A zip made on Windows carries no POSIX modes. In that case only the files under
`Contents/MacOS` are made executable, so use a tar archive if the bundle needs
the execute bit anywhere else.
""",
        ),
        "background": attr.label(
            allow_single_file = [".png", ".jpg", ".jpeg", ".tif", ".tiff"],
            doc = """\
An optional picture to place in the `/.background/` folder of the volume.
""",
        ),
        "format": attr.string(
            default = "UDZO",
            values = _FORMATS.keys(),
            doc = """\
The format of the disk image. `UDZO` is a zlib-compressed read-only image.
`UDRO` is an uncompressed read-only image.
""",
        ),
        "partition_map": attr.bool(
            default = True,
            doc = """\
Whether to frame the volume in a GUID partition table, as
`hdiutil create -layout GPTSPUD` does.
""",
        ),
        "timestamp": attr.int(
            default = _DEFAULT_TIMESTAMP,
            doc = """\
The Unix timestamp written to every record of the volume. The default is
2000-01-01T00:00:00Z, which keeps the image reproducible. `0` uses the time
of the build.
""",
        ),
        "volume_name": attr.string(
            doc = """\
The volume name shown in Finder. Defaults to the bundle name of `app`, or to
the file name of `archive` without its extension.
""",
        ),
        "_dmg_packer": attr.label(
            default = Label("//tools/dmg_packer"),
            executable = True,
            cfg = "exec",
            doc = """\
The `dmg-packer` tool from https://github.com/JetBrains/go-dmg-packer.
""",
        ),
    },
    doc = """\
Packages a macOS application into a `.dmg` disk image.

The image holds the application, an `/Applications` symlink to drag it onto,
an optional background picture, and a Finder layout for the drag-to-install
window.

The image is built by [`dmg-packer`](https://github.com/JetBrains/go-dmg-packer),
which is written in pure Go and needs neither `hdiutil` nor any other macOS
tooling. The action can therefore run on a macOS or a Linux exec platform.
Windows exec platforms are not supported, because the packer unpacks the
bundle to disk and NTFS keeps neither POSIX modes nor symlinks.

The application is packaged as it is built, including its code signature. The
image itself is not signed or notarized.

Example:

````starlark
load("@rules_apple//apple:dmg.bzl", "macos_dmg")
load("@rules_apple//apple:macos.bzl", "macos_application")

macos_application(
    name = "MyApp",
    bundle_id = "com.example.myapp",
    ...
)

macos_dmg(
    name = "MyApp_dmg",
    app = ":MyApp",
    background = "dmg_background.png",
    volume_name = "My App",
)

# Or from an archive built elsewhere, which holds `MyApp.app` at its top level.
macos_dmg(
    name = "MyApp_from_archive_dmg",
    archive = "MyApp-1.2.3-arm64.tar.gz",
    volume_name = "My App",
)
````
""",
)
