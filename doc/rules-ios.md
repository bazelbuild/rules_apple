# Build rules for iOS

<a name="ios_application"></a>
## ios_application

```python
ios_application(name, app_icons, bundle_id, bundle_name, entitlements,
entitlements_validation, extensions, families, frameworks, infoplists,
ipa_post_processor, launch_images, launch_storyboard, linkopts,
minimum_os_version, product_type, provisioning_profile, settings_bundle,
strings, version, watch_application, deps)
```

Builds and bundles an iOS application.

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
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the <code>.app</code>
        extension). If this attribute is not set, then the <code>name</code> of
        the target will be used instead.</p>
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
      <td><code>entitlements_validation</code></td>
      <td>
        <p><code>String; optional; default is
        entitlements_validation_mode.loose</code></p>
        <p>An
        <code><a href="types.md#entitlements-validation-mode">entitlements_validation_mode</a></code>
        to control the validation of the requested entitlements against the
        provisioning profile to ensure they are supported.</p>
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
        file must be specified. Please see <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
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
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>product_type</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string denoting a special type of application, such as
        a Messages Application in iOS 10 and higher. See
        <a href="types.md#apple_product_type"><code>apple_product_type</code></a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the application. This value is optional for simulator
        builds as the simulator doesn't fully enforce entitlements, but is
        <strong>required for device builds.</strong></p>
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
      <td><code>version</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>An <code>apple_bundle_version</code> target that represents the version
        for this target. See
        <a href="rules-general.md?cl=head#apple_bundle_version"><code>apple_bundle_version</code></a>.</p>
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

<a name="ios_extension"></a>
## ios_extension

```python
ios_extension(name, app_icons, bundle_id, bundle_name, entitlements,
entitlements_validation, families, frameworks, infoplists, ipa_post_processor,
linkopts, minimum_os_version, product_type, provisioning_profile, strings,
version, deps)
```

Builds and bundles an iOS application extension.

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
        <p>Files that comprise the app icons for the extension.</p>
        <p>For most extensions, each file must have a containing directory named
        <code>*.xcassets/*.appiconset</code> and there may be only one such
        <code>.appiconset</code> directory in the list.</p>
        <p>For Message StickerPack extensions (<code>product_type</code> of
        <code>apple_product_type.messages_sticker_pack_extension</code>), the
        collection of assets should be under a folder named
        <code>*.*.xcstickers</code>. The main icons go in a
        <code>*.stickersiconset</code> (instead of <code>*.appiconset</code>);
        and the files for the stickers should all be in Sticker Pack
        directories, so <code>*.stickerpack/*.sticker</code> or
        <code>*.stickerpack/*.stickersequence</code>.</p>
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
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the <code>.appex</code>
        extension). If this attribute is not set, then the <code>name</code> of
        the target will be used instead.</p>
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
      <td><code>entitlements_validation</code></td>
      <td>
        <p><code>String; optional; default is
        entitlements_validation_mode.loose</code></p>
        <p>An
        <code><a href="types.md#entitlements-validation-mode">entitlements_validation_mode</a></code>
        to control the validation of the requested entitlements against the
        provisioning profile to ensure they are supported.</p>
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
        file must be specified. Please see <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
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
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>product_type</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string denoting a special type of extension, such as
        a Messages Extension in iOS 10 and higher. See
        <a href="types.md#apple_product_type"><code>apple_product_type</code></a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the extension. This value is optional for simulator
        builds as the simulator doesn't fully enforce entitlements, but is
        <strong>required for device builds.</strong></p>
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
      <td><code>version</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>An <code>apple_bundle_version</code> target that represents the version
        for this target. See
        <a href="rules-general.md?cl=head#apple_bundle_version"><code>apple_bundle_version</code></a>.</p>
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

<a name="ios_framework"></a>
## ios_framework

```python
ios_framework(name, bundle_id, bundle_name, extension_safe, families,
infoplists, ipa_post_processor, linkopts, minimum_os_version, strings,
version, deps)
```

Builds and bundles an iOS dynamic framework. To use this framework for your
app and extensions, list it in the `frameworks` attributes of those
`ios_application` and/or `ios_extension` rules.

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
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the <code>.framework</code>
        extension). If this attribute is not set, then the <code>name</code> of
        the target will be used instead.</p>
      </td>
    </tr>
    <tr>
      <td><code>extension_safe</code></td>
      <td>
        <p><code>Boolean; optional</code></p>
        <p>If true, compiles and links this framework with <code>-application-extension</code>,
        restricting the binary to use only extension-safe APIs. False by default.
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
      <td><code>frameworks</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of framework targets (see <a href="#ios_framework"><code>ios_framework</code></a>)
        that this framework depends on.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the framework. At least one
        file must be specified. Please see <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
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
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
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
      <td><code>version</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>An <code>apple_bundle_version</code> target that represents the version
        for this target. See
        <a href="rules-general.md?cl=head#apple_bundle_version"><code>apple_bundle_version</code></a>.</p>
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

<a name="ios_static_framework"></a>
## ios_static_framework

```python
ios_static_framework(name, avoid_deps, hdrs, bundle_name, exclude_resources,
families, ipa_post_processor, linkopts, minimum_os_version, strings, version,
deps)
```

Builds and bundles an iOS static framework for third-party distribution.

A static framework is bundled like a dynamic framework except that the embedded
binary is a static library rather than a dynamic library. It is intended to
create distributable static SDKs or artifacts that can be easily imported into
other Xcode projects; it is specifically **not** intended to be used as a
dependency of other Bazel targets. For that use case, use the corresponding
`objc_library` targets directly.

Unlike other iOS bundles, the fat binary in an `ios_static_framework` may
simultaneously contain simulator and device architectures (that is, you can
build a single framework artifact that works for all architectures by specifying
`--ios_multi_cpus=i386,x86_64,armv7,arm64` when you build).

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
      <td><code>avoid_deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>objc_library</code> targets on which this framework
        depends in order to compile, but the transitive closure of which will
        <em>not</em> be compiled into the framework's binary.</p>
      </td>
    </tr>
    <tr>
      <td><code>hdrs</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.h</code> files that will be publicly exposed by this
        framework. These headers should have framework-relative imports, and if
        non-empty, an umbrella header named <code>%{bundle_name}.h</code> will
        also be generated that imports all of the headers listed here.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the <code>.framework</code>
        extension). If this attribute is not set, then the <code>name</code> of
        the target will be used instead.</p>
      </td>
    </tr>
    <tr>
      <td><code>exclude_resources</code></td>
      <td>
        <p><code>Boolean; optional; default is False</code></p>
        <p>Indicates whether resources should be excluded from the bundle. This
        can be used to avoid unnecessarily bundling resources if the static
        framework is being distributed in a different fashion, such as a
        Cocoapod.</p>
      </td>
    </tr>
    <tr>
      <td><code>families</code></td>
      <td>
        <p><code>List of strings; optional; default is ["iphone", "ipad"]</code></p>
        <p>A list of device families supported by this framework. Valid values
        are <code>iphone</code> and <code>ipad</code>. If omitted, both values
        listed previously will be used.</p>
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
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
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
      <td><code>version</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>An <code>apple_bundle_version</code> target that represents the version
        for this target. See
        <a href="rules-general.md?cl=head#apple_bundle_version"><code>apple_bundle_version</code></a>.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>The <code>objc_library</code> rules whose transitive closure should
        be linked into this framework. The libraries compiled into this
        framework will be all <code>objc_library</code> targets in the
        transitive closure of <code>deps</code>, minus those that are in the
        transitive closure of <code>avoid_deps</code>.</p>
        <p>Any resources, such as asset catalogs, that are referenced by those
        targets will also be transitively included in the final framework
        (unless <code>exclude_resources</code> is True).</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="ios_ui_test"></a>
## ios_ui_test

```python
ios_ui_test(name, bundle_id, infoplists, minimum_os_version, runner,
test_host, data, deps, [test specific attributes])
```

Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

The following is a list of the `ios_ui_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/versions/master/docs/be/common-definitions.html#common-attributes-tests).

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
        <p><code>String; optional</code></p>
        <p>The bundle ID (reverse-DNS path) of the test bundle. It cannot be the
        same bundle ID as the <code>test_host</code> bundle ID. If not
        specified, the <code>test_host</code>'s bundle ID will be used with a
        "Tests" suffix.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the test bundle. If not
        specified, a default one will be provided that only contains the
        <code>CFBundleName</code> and <code>CFBundleIdentifier</code> keys with
        placeholders that will be replaced when bundling.  Please see
        <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>runner</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A target that will specify how the tests are to be run. This target
        needs to be defined using a rule that provides the <code>AppleTestRunner</code>
        provider.</p>
      </td>
    </tr>
    <tr>
      <td><code>test_host</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; required</code></p>
        <p>An <code>ios_application</code> target that represents the app that
        will be tested using XCUITests. This is required as passing a default
        has no meaning in UI tests.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>The list of files needed by this rule at runtime.</p>
        <p>Targets named in the data attribute will appear in the `*.runfiles`
        area of this rule, if it has one. This may include data files needed by
        a binary or library, or other programs needed by it.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final test bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>[test specific attributes]</code></td>
      <td>
        <p>For a list of the attributes inherited by all test rules, please check the
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#common-attributes-tests">Bazel documentation</a>.
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="ios_ui_test_suite"></a>
## ios_ui_test_suite

```python
ios_ui_test_suite(name, bundle_id, infoplists, minimum_os_version, runners,
test_host, deps, [test specific attributes])
```

Builds an XCUITest test suite with the given runners.

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
        <p><code>String; optional</code></p>
        <p>The bundle ID (reverse-DNS path) of the test bundle. It cannot be the
        same bundle ID as the <code>test_host</code> bundle ID. If not
        specified, the <code>test_host</code>'s bundle ID will be used with a
        "Tests" suffix.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the test bundle. If not
        specified, a default one will be provided that only contains the
        <code>CFBundleName</code> and <code>CFBundleIdentifier</code> keys with
        placeholders that will be replaced when bundling.  Please see
        <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>runners</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Labels</a></code></p>
        <p>The list of runner targets that contain the logic of how the tests
        should be executed. This target needs to provide an
        <code>AppleTestRunner</code> provider. This attribute is required and
        must contain at least 2 runners.</p>
      </td>
    </tr>
    <tr>
      <td><code>test_host</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; required</code></p>
        <p>An <code>ios_application</code> target that represents the app that
        will be tested using XCUITests. This is required as passing a default
        has no meaning in UI tests.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>The list of files needed by this rule at runtime.</p>
        <p>Targets named in the data attribute will appear in the `*.runfiles`
        area of this rule, if it has one. This may include data files needed by
        a binary or library, or other programs needed by it.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final test bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>[test specific attributes]</code></td>
      <td>
        <p>For a list of the attributes inherited by all test rules, please check the
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#common-attributes-tests">Bazel documentation</a>.
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="ios_unit_test"></a>
## ios_unit_test

```python
ios_unit_test(name, bundle_id, infoplists, minimum_os_version, runner,
test_host, data, deps, [test specific attributes])
```

Builds and bundles an iOS Unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

`ios_unit_test` targets can work in two modes: as app or library
tests. If the `test_host` attribute is set to an `ios_application` target, the
tests will run within that application's context. If no `test_host` is provided,
the tests will run outside the context of an iOS application. Because of this,
certain functionalities might not be present (e.g. UI layout, NSUserDefaults).
You can find more information about app and library testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

The following is a list of the `ios_unit_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/versions/master/docs/be/common-definitions.html#common-attributes-tests).

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
        <p><code>String; optional</code></p>
        <p>The bundle ID (reverse-DNS path) of the test bundle. It cannot be the
        same bundle ID as the <code>test_host</code> bundle ID. If not
        specified, the <code>test_host</code>'s bundle ID will be used with a
        "Tests" suffix.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the test bundle. If not
        specified, a default one will be provided that only contains the
        <code>CFBundleName</code> and <code>CFBundleIdentifier</code> keys with
        placeholders that will be replaced when bundling. Please see
        <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>runner</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A target that will specify how the tests are to be run. This target
        needs to be defined using a rule that provides the <code>AppleTestRunner</code>
        provider. The default runner can only run logic-based tests (i.e. tests
        that do not rely on running a test host application). This is not the
        case when running the tests from a Tulsi generated project, and both
        logic and application based unit tests are supported in that scenario.</p>
      </td>
    </tr>
    <tr>
      <td><code>test_host</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>An <code>ios_application</code> target that represents the app that
        will host the tests. If not specified, the runner will assume it's a
        library-based test.</p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>The list of files needed by this rule at runtime.</p>
        <p>Targets named in the data attribute will appear in the `*.runfiles`
        area of this rule, if it has one. This may include data files needed by
        a binary or library, or other programs needed by it.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final test bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>[test specific attributes]</code></td>
      <td>
        <p>For a list of the attributes inherited by all test rules, please check the
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#common-attributes-tests">Bazel documentation</a>.
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="ios_unit_test_suite"></a>
## ios_unit_test_suite

```python
ios_unit_test_suite(name, bundle_id, infoplists, minimum_os_version, runners,
test_host, deps, [test specific attributes])
```

Builds an XCTest unit test suite with the given runners.

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
        <p><code>String; optional</code></p>
        <p>The bundle ID (reverse-DNS path) of the test bundle. It cannot be the
        same bundle ID as the <code>test_host</code> bundle ID. If not
        specified, the <code>test_host</code>'s bundle ID will be used with a
        "Tests" suffix.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the test bundle. If not
        specified, a default one will be provided that only contains the
        <code>CFBundleName</code> and <code>CFBundleIdentifier</code> keys with
        placeholders that will be replaced when bundling. Please see
        <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum iOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>runners</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Labels</a></code></p>
        <p>The list of runner targets that contain the logic of how the tests
        should be executed. This target needs to provide an
        <code>AppleTestRunner</code> provider. This attribute is required and
        must contain at least 2 runners.</p>
      </td>
    </tr>
    <tr>
      <td><code>test_host</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>An <code>ios_application</code> target that represents the app that
        will host the tests. If not specified, an empty shell app will be
        provided as the test host.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets that are passed into the
        <code>apple_binary</code> rule to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final test bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>[test specific attributes]</code></td>
      <td>
        <p>For a list of the attributes inherited by all test rules, please check the
        <a href="https://bazel.build/versions/master/docs/be/common-definitions.html#common-attributes-tests">Bazel documentation</a>.
        </p>
      </td>
    </tr>
  </tbody>
</table>
