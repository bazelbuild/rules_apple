# Apple Rules for [Bazel](https://bazel.build)

> :warning: **NOTE**: At the time of this writing, the most recent Bazel
> release is **0.4.5.** These rules are *not* compatible with that release;
> they are only compatible with Bazel at **master**. Until the next release of
> Bazel, you will need to
> [build Bazel from source](https://bazel.build/versions/master/docs/install-compile-source.html)
> if you wish to use them.

This repository contains rules for [Bazel](https://bazel.build) that can be
used to bundle applications for Apple platforms. They replace the bundling
rules defined in Bazel itself (such as `ios_application`, `ios_extension`, and
`apple_watch2_extension`).

These rules handle the linking and bundling of applications and extensions
(that is, the formation of an `.app` with an executable and resources,
archived in an `.ipa`). Compilation is still performed by the existing
[`objc_library` rule](https://bazel.build/versions/master/docs/be/objective-c.html#objc_library)
in Bazel; to link those dependencies, these bundling rules use Bazel's
[`apple_binary` rule](https://bazel.build/versions/master/docs/be/objective-c.html#apple_binary)
under the hood.

## Rules

* [ios_application](#ios_application)
* [ios_extension](#ios_extension)
* [ios_framework](#ios_framework) (_experimental_)
* [tvos_application](#tvos_application)
* [tvos_extension](#tvos_extension)
* [watchos_application](#watchos_application)
* [watchos_extension](#watchos_extension)
* [swift_library](#swift_library)

## Other types

* [apple_product_type](#apple_product_type)

## Setup

Add the following to your `WORKSPACE` file to add the external repositories,
replacing the version number in the `tag` attribute with the version of the
rules you wish to depend on:

```python
git_repository(
    name = "build_bazel_rules_apple",
    remote = "https://github.com/bazelbuild/rules_apple.git",
    tag = "0.0.1",
)
```

## Examples

Minimal example:

```python
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

objc_library(
    name = "Lib",
    srcs = glob([
        "**/*.h",
        "**/*.m",
    ]),
    resources = [
        ":Main.storyboard",
    ],
)

# Links code from "deps" into an executable, collects and compiles resources
# from "deps" and places them with the executable in an .app bundle, and then
# outputs an .ipa with the bundle in its Payload directory.
ios_application(
    name = "App",
    bundle_id = "com.example.app",
    families = ["iphone", "ipad"],
    infoplists = [":Info.plist"],
    deps = [":Lib"],
)
```

See the [examples](https://github.com/bazelbuild/rules_apple/tree/master/examples)
directory for sample applications.

## Migrating from the built-in rules

Even though the rules in this repository have the same names as their built-in
counterparts, they cannot be intermixed; for example, an `ios_application` from
this repository cannot have an extension that is a built-in `ios_extension` or
vice versa.

The wiki for this repository contains a
[migration guide](https://github.com/bazelbuild/rules_apple/wiki/Migrating-from-the-native-rules)
describing in detail the differences between the old and new rules and how to
update your build targets.

## Coming soon

* macOS support
* Support for compiling texture atlases
* Improved rules for creating resource bundles

## ios_application

```python
ios_application(name, app_icons, bundle_id, entitlements, extensions, families,
frameworks, infoplists, ipa_post_processor, launch_images, launch_storyboard,
linkopts, product_type, provisioning_profile, settings_bundle, strings, deps)
```

Builds and bundles an iOS application.

The named target produced by this macro is an IPA file. This macro also creates
a target named `{name}.apple_binary` that represents the linked executable
inside the application bundle.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>app_icons</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the app icons for the application. Each file
        must have a containing directory named <code>*.xcassets/*.appiconset</code> and
        there may be only one such <code>.appiconset</code> directory in the list.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        application.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the application.
        If absent, the default entitlements from the provisioning profile will
        be used.</p>
        <p>The following variables are substituted in the entitlements file:
        <code>$(CFBundleIdentifier)</code> with the bundle ID of the application
        and <code>$(AppIdentifierPrefix)</code> with the value of the
        <code>ApplicationIdentifierPrefix</code> key from the target's
        provisioning profile.</p>
      </td>
    </tr>
    <tr>
      <td><code>extensions</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of extensions (see <a href="#ios_extension"><code>ios_extension</code></a>)
        to include in the final application bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>families</code></td>
      <td>
        <p><code>List of strings; required</code></p>
        <p>A list of device families supported by this application. Valid values
        are <code>iphone</code> and <code>ipad</code>; at least one must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>frameworks</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of framework targets (see <a href="#ios_framework"><code>ios_framework</code></a>)
        that this application depends on.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the application. At least one
        file must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>ipa_post_processor</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A tool that edits this target's IPA output after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the IPA (that is, the <code>Payload</code> directory will
        be present in this directory).</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>launch_images</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the launch images for the application. Each file
        must have a containing directory named<code>*.xcassets/*.launchimage</code> and
        there may be only one such <code>.launchimage</code> directory in the list.</p>
        <p>It is recommended that you use a <code>launch_storyboard</code> instead if
        you are targeting only iOS 8 and later.</p>
      </td>
    </tr>
    <tr>
      <td><code>launch_storyboard</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The <code>.storyboard</code> or <code>.xib</code> file that should
        be used as the launch screen for the application. The provided file will
        be compiled into the appropriate format (<code>.storyboardc</code> or
        <code>.nib</code>) and placed in the root of the final bundle. The
        generated file will also be registered in the bundle's <code>Info.plist</code>
        under the key <code>UILaunchStoryboardName</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra flags that the underlying
        <code>apple_binary</code> target created by this rule should pass to the
        linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>product_type</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string denoting a special type of application, such as
        a Messages Application in iOS 10 and higher. See
        <a href="#apple_product_type"><code>apple_product_type</code></a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the application. This value is optional (and unused) for
        simulator builds but <strong>required for device builds.</strong></p>
      </td>
    </tr>
    <tr>
      <td><code>settings_bundle</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>An <code>objc_bundle</code> target that contains the files that make up
        the application's settings bundle. These files will be copied into the
        root of the final application bundle in a directory named
        <code>Settings.bundle</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final application bundle, unless a file's immediate containing
        directory is named <code>*.lproj</code>, in which case it will be placed
        under a directory with the same name in the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>watch_application</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A <code>watchos_application</code> target that represents an Apple
        Watch application that should be embedded in the application.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final application.</p>
      </td>
    </tr>
  </tbody>
</table>

## ios_extension

```python
ios_extension(name, app_icons, bundle_id, entitlements, families, frameworks,
infoplists, ipa_post_processor, linkopts, product_type, provisioning_profile,
strings, deps)
```

Builds and bundles an iOS application extension.

The named target produced by this macro is a ZIP file. This macro also creates a
target named `{name}.apple_binary` that represents the linked binary
executable inside the extension bundle.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>app_icons</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the app icons for the extension. Each file
        must have a containing directory named<code>*.xcassets/*.appiconset</code> and
        there may be only one such <code>.appiconset</code> directory in the list.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        extension.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the extension.
        If absent, the default entitlements from the provisioning profile will
        be used.</p>
        <p>The following variables are substituted in the entitlements file:
        <code>$(CFBundleIdentifier)</code> with the bundle ID of the extension
        and <code>$(AppIdentifierPrefix)</code> with the value of the
        <code>ApplicationIdentifierPrefix</code> key from the target's
        provisioning profile.</p>
      </td>
    </tr>
    <tr>
      <td><code>families</code></td>
      <td>
        <p><code>List of strings; required</code></p>
        <p>A list of device families supported by this extension. Valid values
        are <code>iphone</code> and <code>ipad</code>; at least one must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>frameworks</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of framework targets (see <a href="#ios_framework"><code>ios_framework</code></a>)
        that this extension depends on.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the extension. At least one
        file must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>ipa_post_processor</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A tool that edits this target's archive after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the archive; the <code>*.appex</code> bundle for the
        extension will be the directory's only contents.</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra flags that the underlying
        <code>apple_binary</code> target created by this rule should pass to the
        linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>product_type</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string denoting a special type of extension, such as
        a Messages Extension in iOS 10 and higher. See
        <a href="#apple_product_type"><code>apple_product_type</code></a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the extension. This value is optional (and unused) for
        simulator builds but <strong>required for device builds.</strong></p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final extension bundle, unless a file's immediate containing
        directory is named <code>*.lproj</code>, in which case it will be placed
        under a directory with the same name in the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final extension.</p>
      </td>
    </tr>
  </tbody>
</table>

## ios_framework

```python
ios_framework(name, bundle_id, families, infoplists, ipa_post_processor,
linkopts, strings, deps)
```

Builds and bundles an iOS dynamic framework.

The named target produced by this macro is a ZIP file. This macro also creates a
target named `{name}.apple_binary` that represents the linked dynamic library
inside the framework bundle.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        framework.</p>
      </td>
    </tr>
    <tr>
      <td><code>families</code></td>
      <td>
        <p><code>List of strings; required</code></p>
        <p>A list of device families supported by this framework. Valid values
        are <code>iphone</code> and <code>ipad</code>; at least one must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the framework. At least one
        file must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>ipa_post_processor</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A tool that edits this target's archive after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the archive; the <code>*.framework</code> bundle for the
        extension will be the directory's only contents.</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra flags that the underlying
        <code>apple_binary</code> target created by this rule should pass to the
        linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final extension bundle, unless a file's immediate containing
        directory is named <code>*.lproj</code>, in which case it will be placed
        under a directory with the same name in the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final framework.</p>
      </td>
    </tr>
  </tbody>
</table>

## tvos_application

```python
tvos_application(name, app_icons, bundle_id, entitlements, extensions,
infoplists, ipa_post_processor, launch_images, launch_storyboard, linkopts,
provisioning_profile, settings_bundle, strings, deps)
```

Builds and bundles a tvOS application.

The named target produced by this macro is an IPA file. This macro also creates
a target named `{name}.apple_binary` that represents the linked executable
inside the application bundle.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>app_icons</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the app icons for the application. Each file
        must have a containing directory named<code>*.xcassets/*.appiconset</code> and
        there may be only one such <code>.appiconset</code> directory in the list.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        application.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the application.
        If absent, the default entitlements from the provisioning profile will
        be used.</p>
        <p>The following variables are substituted in the entitlements file:
        <code>$(CFBundleIdentifier)</code> with the bundle ID of the application
        and <code>$(AppIdentifierPrefix)</code> with the value of the
        <code>ApplicationIdentifierPrefix</code> key from the target's
        provisioning profile.</p>
      </td>
    </tr>
    <tr>
      <td><code>extensions</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of extensions (see <a href="#tvos_extension"><code>tvos_extension</code></a>)
        to include in the final application bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the application. At least one
        file must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>ipa_post_processor</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A tool that edits this target's IPA output after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the IPA (that is, the <code>Payload</code> directory will
        be present in this directory).</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>launch_images</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the launch images for the application. Each file
        must have a containing directory named<code>*.xcassets/*.launchimage</code> and
        there may be only one such <code>.launchimage</code> directory in the list.</p>
        <p>It is recommended that you use a <code>launch_storyboard</code> instead if
        you are targeting only iOS 8 and later.</p>
      </td>
    </tr>
    <tr>
      <td><code>launch_storyboard</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The <code>.storyboard</code> or <code>.xib</code> file that should
        be used as the launch screen for the application. The provided file will
        be compiled into the appropriate format (<code>.storyboardc</code> or
        <code>.nib</code>) and placed in the root of the final bundle. The
        generated file will also be registered in the bundle's <code>Info.plist</code>
        under the key <code>UILaunchStoryboardName</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra flags that the underlying
        <code>apple_binary</code> target created by this rule should pass to the
        linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the application. This value is optional (and unused) for
        simulator builds but <strong>required for device builds.</strong></p>
      </td>
    </tr>
    <tr>
      <td><code>settings_bundle</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>An <code>objc_bundle</code> target that contains the files that make up
        the application's settings bundle. These files will be copied into the
        root of the final application bundle in a directory named
        <code>Settings.bundle</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final application bundle, unless a file's immediate containing
        directory is named <code>*.lproj</code>, in which case it will be placed
        under a directory with the same name in the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final application.</p>
      </td>
    </tr>
  </tbody>
</table>

## tvos_extension

```python
tvos_extension(name, bundle_id, entitlements, infoplists, ipa_post_processor,
linkopts, strings, deps)
```

Builds and bundles a tvOS extension.

The named target produced by this macro is a ZIP file. This macro also creates a
target named `{name}.apple_binary` that represents the linked binary
executable inside the extension bundle.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        extension.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the extension.
        If absent, the default entitlements from the provisioning profile will
        be used.</p>
        <p>The following variables are substituted in the entitlements file:
        <code>$(CFBundleIdentifier)</code> with the bundle ID of the extension
        and <code>$(AppIdentifierPrefix)</code> with the value of the
        <code>ApplicationIdentifierPrefix</code> key from the target's
        provisioning profile.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the extension. At least one
        file must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>ipa_post_processor</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A tool that edits this target's archive after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the archive; the <code>*.appex</code> bundle for the
        extension will be the directory's only contents.</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra flags that the underlying
        <code>apple_binary</code> target created by this rule should pass to the
        linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the extension. This value is optional (and unused) for
        simulator builds but <strong>required for device builds.</strong></p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final extension bundle, unless a file's immediate containing
        directory is named <code>*.lproj</code>, in which case it will be placed
        under a directory with the same name in the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final extension.</p>
      </td>
    </tr>
  </tbody>
</table>

## watchos_application

```python
watchos_application(name, app_icons, bundle_id, entitlements, extension,
infoplists, ipa_post_processor, provisioning_profile, storyboards, strings,
deps)
```

Builds and bundles a watchOS application.

**This rule only supports watchOS 2.0 and higher.** Apple no longer supports
or accepts submissions of apps written for watchOS 1.x, so these bundling rules
do not support that version of the platform.

The named target produced by this macro is a ZIP file. The watch application is
not executable or installable by itself; the target must be added to a
companion `ios_application` using the `watch_application` attribute on that
rule.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>app_icons</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the app icons for the application. Each file
        must have a containing directory named<code>*.xcassets/*.appiconset</code> and
        there may be only one such <code>.appiconset</code> directory in the list.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        application.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the application.
        If absent, the default entitlements from the provisioning profile will
        be used.</p>
        <p>The following variables are substituted in the entitlements file:
        <code>$(CFBundleIdentifier)</code> with the bundle ID of the application
        and <code>$(AppIdentifierPrefix)</code> with the value of the
        <code>ApplicationIdentifierPrefix</code> key from the target's
        provisioning profile.</p>
      </td>
    </tr>
    <tr>
      <td><code>extension</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; required</code></p>
        <p>The <a href="#watchos_extension"><code>watchos_extension</code></a>
        that is bundled with the watch application.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the application. At least one
        file must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>ipa_post_processor</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A tool that edits this target's IPA output after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the IPA (that is, the <code>Payload</code> directory will
        be present in this directory).</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the application. This value is optional (and unused) for
        simulator builds but <strong>required for device builds.</strong></p>
      </td>
    </tr>
    <tr>
      <td><code>storyboards</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.storyboard</code> files, often localizable. These files
        are compiled and placed in the root of the final application bundle, unless
        a file's immediate containing directory is named <code>*.lproj</code>, in
        which case it will be placed under a directory with the same name in the
        bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final application bundle, unless a file's immediate containing
        directory is named <code>*.lproj</code>, in which case it will be placed
        under a directory with the same name in the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of targets whose resources will be included in the final
        application. Since a watchOS application does not contain any code of
        its own, any code in the dependent libraries will be ignored.</p>
      </td>
    </tr>
  </tbody>
</table>

## watchos_extension

```python
watchos_extension(name, app_icons, bundle_id, entitlements, infoplists,
ipa_post_processor, linkopts, provisioning_profile, strings, deps)
```

Builds and bundles a watchOS extension.

**This rule only supports watchOS 2.0 and higher.** Apple no longer supports
or accepts submissions of apps written for watchOS 1.x, so these bundling rules
do not support that version of the platform.

The named target produced by this macro is a ZIP file. This macro also creates a
target named `{name}.apple_binary` that represents the linked binary
executable inside the extension bundle.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>app_icons</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the app icons for the extension. Each file
        must have a containing directory named<code>*.xcassets/*.appiconset</code> and
        there may be only one such <code>.appiconset</code> directory in the list.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        extension.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the extension.
        If absent, the default entitlements from the provisioning profile will
        be used.</p>
        <p>The following variables are substituted in the entitlements file:
        <code>$(CFBundleIdentifier)</code> with the bundle ID of the extension
        and <code>$(AppIdentifierPrefix)</code> with the value of the
        <code>ApplicationIdentifierPrefix</code> key from the target's
        provisioning profile.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the extension. At least one
        file must be specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>ipa_post_processor</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A tool that edits this target's archive after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the archive; the <code>*.appex</code> bundle for the
        extension will be the directory's only contents.</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra flags that the underlying
        <code>apple_binary</code> target created by this rule should pass to the
        linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the extension. This value is optional (and unused) for
        simulator builds but <strong>required for device builds.</strong></p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final extension bundle, unless a file's immediate containing
        directory is named <code>*.lproj</code>, in which case it will be placed
        under a directory with the same name in the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final extension.</p>
      </td>
    </tr>
  </tbody>
</table>

## swift_library

```python
swift_library(name, srcs, deps, module_name, defines, copts)
```

Produces a static library from Swift sources. The output is a pair of .a and
.swiftmodule files.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#name">Name</a>, required</code></p>
        <p>A unique name for the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>Sources to compile into this library. Only <code>*.swift</code>
        is allowed.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of Swift or Objective-C libraries to link together.</p>
      </td>
    </tr>
    <tr>
      <td><code>module_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>Sets the Swift module name for this target. By default
        the module name is the target path with all special symbols replaced
        by <code>_</code>, e.g. <code>//foo/baz:bar</code> can be imported as
        <code>foo_baz_bar</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>defines</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>Values to be passed with <code>-D</code> flag to the compiler for
        this target and all swift_library dependents of this target.</p>
      </td>
    </tr>
    <tr>
      <td><code>copts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>Additional compiler flags. Passed to the compile actions of this
        target only.</p>
      </td>
    </tr>
  </tbody>
</table>

## apple_product_type

A `struct` containing product type identifiers used by special application and
extension types.

Some applications and extensions, such as Messages Extensions and
Sticker Packs in iOS 10, receive special treatment when building (for example,
some product types bundle a stub executable instead of a user-defined binary,
and some pass extra arguments to tools like the asset compiler). These
behaviors are captured in the product type identifier. The product types
currently supported are:

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Product types</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>messages_application</code></td>
      <td>
        <p>Applies to <code>ios_application</code> targets built for iOS 10 and
        above.</p>
        <p>A "stub" application used to distribute a standalone Messages
        Extension or Sticker Pack. This application <strong>must</strong>
        include an <code>ios_extension</code> whose product type is
        <code>messages_extension</code> or
        <code>messages_sticker_pack_extension</code> (or it can include both).
        </p>
        <p>This product type does not contain a user-provided binary; any code
        in its <code>deps</code> will be ignored.</p>
        <p>This stub application is not displayed on the home screen and its
        features are only accessible through the Messages user interface. If
        you are building a Messages Extension or Sticker Pack as part of a
        larger application that is launchable, do not use this product type;
        simply add those extensions to the existing application.</p>
      </td>
    </tr>
    <tr>
      <td><code>messages_extension</code></td>
      <td>
        <p>Applies to <code>ios_extension</code> targets built for iOS 10 and
        above.</p>
        <p>An extension that integrates custom behavior into the Apple Messages
        application. Such extensions can present a custom user interface in the
        keyboard area of the app and interact with users' conversations.</p>
      </td>
    </tr>
    <tr>
      <td><code>messages_sticker_pack_extension</code></td>
      <td>
        <p>Applies to <code>ios_extension</code> targets built for iOS 10 and
        above.</p>
        <p>An extension that defines custom sticker packs for the Apple
        Messages app. Stickers are provided by including an asset catalog
        named <code>*.xcstickers</code> in the extension's
        <code>asset_catalogs</code> attribute.</p>
        <p>This product type does not contain a user-provided binary; any
        code in its <code>deps</code> will be ignored.</p>
      </td>
    </tr>
  </tbody>
</table>

Example usage:

```python
load("@build_bazel_rules_apple//apple:ios.bzl",
     "apple_product_type", "ios_application", "ios_extension")

ios_application(
    name = "StickerPackApp",
    extensions = [":StickerPackExtension"],
    product_type = apple_product_type.messages_application,
    # other attributes...
)

ios_extension(
    name = "StickerPackExtension",
    product_type = apple_product_type.messages_sticker_pack_extension,
    # other attributes...
)
```
