<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules for creating macOS disk images.

<a id="macos_dmg"></a>

## macos_dmg

<pre>
load("@rules_apple//apple:dmg.bzl", "macos_dmg")

macos_dmg(<a href="#macos_dmg-name">name</a>, <a href="#macos_dmg-app">app</a>, <a href="#macos_dmg-archive">archive</a>, <a href="#macos_dmg-background">background</a>, <a href="#macos_dmg-format">format</a>, <a href="#macos_dmg-partition_map">partition_map</a>, <a href="#macos_dmg-timestamp">timestamp</a>, <a href="#macos_dmg-volume_name">volume_name</a>)
</pre>

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

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="macos_dmg-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="macos_dmg-app"></a>app |  The macOS application to package, for example a `macos_application` target. Exactly one of `app` or `archive` must be set.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_dmg-archive"></a>archive |  An archive holding the macOS application to package: a `.zip`, `.tar`, `.tar.gz` or `.tgz` file with one `.app` folder at its top level. Loose files beside the folder are ignored. Exactly one of `app` or `archive` must be set.<br><br>A zip made on Windows carries no POSIX modes. In that case only the files under `Contents/MacOS` are made executable, so use a tar archive if the bundle needs the execute bit anywhere else.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_dmg-background"></a>background |  An optional picture to place in the `/.background/` folder of the volume.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="macos_dmg-format"></a>format |  The format of the disk image. `UDZO` is a zlib-compressed read-only image. `UDRO` is an uncompressed read-only image.   | String | optional |  `"UDZO"`  |
| <a id="macos_dmg-partition_map"></a>partition_map |  Whether to frame the volume in a GUID partition table, as `hdiutil create -layout GPTSPUD` does.   | Boolean | optional |  `True`  |
| <a id="macos_dmg-timestamp"></a>timestamp |  The Unix timestamp written to every record of the volume. The default is 2000-01-01T00:00:00Z, which keeps the image reproducible. `0` uses the time of the build.   | Integer | optional |  `946684800`  |
| <a id="macos_dmg-volume_name"></a>volume_name |  The volume name shown in Finder. Defaults to the bundle name of `app`, or to the file name of `archive` without its extension.   | String | optional |  `""`  |


<a id="dmg_common.create_dmg"></a>

## dmg_common.create_dmg

<pre>
load("@rules_apple//apple:dmg.bzl", "dmg_common")

dmg_common.create_dmg(*, <a href="#dmg_common.create_dmg-actions">actions</a>, <a href="#dmg_common.create_dmg-dmg_packer">dmg_packer</a>, <a href="#dmg_common.create_dmg-bundle">bundle</a>, <a href="#dmg_common.create_dmg-output">output</a>, <a href="#dmg_common.create_dmg-volume_name">volume_name</a>, <a href="#dmg_common.create_dmg-background">background</a>, <a href="#dmg_common.create_dmg-format">format</a>,
                      <a href="#dmg_common.create_dmg-partition_map">partition_map</a>, <a href="#dmg_common.create_dmg-timestamp">timestamp</a>, <a href="#dmg_common.create_dmg-execution_requirements">execution_requirements</a>)
</pre>

Registers the action of `macos_dmg`, for a rule that must declare the disk image itself.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="dmg_common.create_dmg-actions"></a>actions |  The `actions` object of the rule context.   |  none |
| <a id="dmg_common.create_dmg-dmg_packer"></a>dmg_packer |  The executable of `@rules_apple//tools/dmg_packer`, built for the exec platform.   |  none |
| <a id="dmg_common.create_dmg-bundle"></a>bundle |  The `File` to pack: a `.app` tree artifact, or an archive that the `archive` attribute of `macos_dmg` accepts.   |  none |
| <a id="dmg_common.create_dmg-output"></a>output |  The `File` of the `.dmg` to write.   |  none |
| <a id="dmg_common.create_dmg-volume_name"></a>volume_name |  The volume name shown in Finder.   |  none |
| <a id="dmg_common.create_dmg-background"></a>background |  See the `background` attribute of `macos_dmg`.   |  `None` |
| <a id="dmg_common.create_dmg-format"></a>format |  See the `format` attribute of `macos_dmg`.   |  `"UDZO"` |
| <a id="dmg_common.create_dmg-partition_map"></a>partition_map |  See the `partition_map` attribute of `macos_dmg`.   |  `True` |
| <a id="dmg_common.create_dmg-timestamp"></a>timestamp |  See the `timestamp` attribute of `macos_dmg`.   |  `946684800` |
| <a id="dmg_common.create_dmg-execution_requirements"></a>execution_requirements |  Additional execution requirements of the action.   |  `{}` |


