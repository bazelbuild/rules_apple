# Build rules for tvOS

<a name="tvos_application"></a>
## tvos_application

```python
tvos_application(name, app_icons, bundle_id, bundle_name, entitlements,
entitlements_validation, extensions, frameworks, infoplists, ipa_post_processor,
launch_images, linkopts, minimum_os_version, provisioning_profile,
settings_bundle, strings, version, deps)
```

Builds and bundles a tvOS application.

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
        <p>A list of extensions (see <a href="#tvos_extension"><code>tvos_extension</code></a>)
        to include in the final application bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>frameworks</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of framework targets (see <a href="#tvos_framework"><code>tvos_framework</code></a>)
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
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra flags that should be passed to
        the linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum tvOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--tvos_minimum_os</code> will be used instead.
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
        <p>A resource bundle target that contains the files that make up
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
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets to link into the binary. Any
        resources, such as asset catalogs, that are referenced by those targets
        will also be transitively included in the final application.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="tvos_extension"></a>
## tvos_extension

```python
tvos_extension(name, bundle_id, bundle_name, entitlements,
entitlements_validation, frameworks, infoplists, ipa_post_processor, linkopts,
minimum_os_version, strings, version, deps)
```

Builds and bundles a tvOS extension.

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
      <td><code>frameworks</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of framework targets (see <a href="#tvos_framework"><code>tvos_framework</code></a>)
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
        <p>A list of strings representing extra flags that should be passed to
        the linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum tvOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--tvos_minimum_os</code> will be used instead.
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
        <p>A list of dependencies targets to link into the binary. Any
        resources, such as asset catalogs, that are referenced by those targets
        will also be transitively included in the final extension.</p>
      </td>
    </tr>
  </tbody>
</table>

## tvos_framework

```python
tvos_framework(name, bundle_id, bundle_name, extension_safe, frameworks,
infoplists, ipa_post_processor, linkopts, minimum_os_version, strings, version,
deps)
```

Builds and bundles a tvOS dynamic framework. To use this framework for your app
and extensions, list it in the `frameworks` attributes of those
`tvos_application` and/or `tvos_extension` rules.

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
      <td><code>frameworks</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of framework targets (see <a href="#tvos_framework"><code>tvos_framework</code></a>)
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
        <p>A list of strings representing extra flags that should be passed to
        the linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum tvOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"9.0"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--tvos_minimum_os</code> will be used instead.
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
        <p>A list of dependencies targets to link into the binary. Any
        resources, such as asset catalogs, that are referenced by those targets
        will also be transitively included in the final framework.</p>
      </td>
    </tr>
  </tbody>
</table>
