# Build rules for macOS

<a name="macos_application"></a>
## macos_application

```python
macos_application(name, additional_contents, app_icons, bundle_id, bundle_name,
entitlements, entitlements_validation, extensions, infoplists,
ipa_post_processor, linkopts, minimum_os_version, provisioning_profile, strings,
version, deps)
```

Builds and bundles a macOS application.

This rule creates an application that is a `.app` bundle. If you want to build a
simple command line tool as a standalone binary, use
[`macos_command_line_application`](#macos_command_line_application) instead.

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
      <td><code>additional_contents</code></td>
      <td>
        <p><code>Dictionary of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a> to strings; optional</code></p>
        <p>Files that should be copied into specific subdirectories of the
        <code>Contents</code> folder in the application. The keys of this
        dictionary are labels pointing to single files,
        <code>filegroup</code>s, or targets; the corresponding value is the
        name of the subdirectory of <code>Contents</code> where they should
        be placed.</p>
        <p>The relative directory structure of <code>filegroup</code>
        contents is preserved when they are copied into the desired
        <code>Contents</code> subdirectory.</p>
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
        <p>A list of extensions (see <a href="#macos_extension"><code>macos_extension</code></a>)
        to include in the final application bundle.</p>
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
        <p>A tool that edits this target's archive after it is assembled but
        before it is signed. The tool is invoked with a single command-line
        argument that denotes the path to a directory containing the unzipped
        contents of the archive; the <code>*.app</code> bundle for the
        application will be the directory's only contents.</p>
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
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.provisionprofile</code> file) to use
        when bundling the application.</p>
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
      <td><code>xpc_services</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of XPC Services (see <a href="#macos_xpc_service"><code>macos_xpc_service</code></a>)
        to include in the final application bundle.</p>
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

<a name="macos_bundle"></a>
## macos_bundle

```python
macos_bundle(name, additional_contents, app_icons, bundle_id, bundle_name,
entitlements, entitlements_validation, infoplists, ipa_post_processor, linkopts,
minimum_os_version, provisioning_profile, strings, version, deps)
```

Builds and bundles a macOS loadable bundle.

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
      <td><code>additional_contents</code></td>
      <td>
        <p><code>Dictionary of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a> to strings; optional</code></p>
        <p>Files that should be copied into specific subdirectories of the
        <code>Contents</code> folder in the bundle. The keys of this
        dictionary are labels pointing to single files,
        <code>filegroup</code>s, or targets; the corresponding value is the
        name of the subdirectory of <code>Contents</code> where they should
        be placed.</p>
        <p>The relative directory structure of <code>filegroup</code>
        contents is preserved when they are copied into the desired
        <code>Contents</code> subdirectory.</p>
      </td>
    </tr>
    <tr>
      <td><code>app_icons</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files that comprise the app icons for the bundle. Each file
        must have a containing directory named<code>*.xcassets/*.appiconset</code> and
        there may be only one such <code>.appiconset</code> directory in the list.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_loader</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A label to a <code>macos_application</code> or
        <code>macos_command_line_application</code> target. The macOS bundle
        binary generated by this rule will then assume that it will be loaded by
        that application's binary at runtime. If this attribute is set, this
        <code>macos_bundle</code> target _cannot_ be a dependency for that
        <code>macos_application</code> target.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the extension). If this
        attribute is not set, then the <code>name</code> of the target will be
        used instead.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the bundle.
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
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the bundle. At least one
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
        contents of the archive; the bundle directory will be that directory's
        only contents.</p>
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
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.provisionprofile</code> file) to use
        when bundling the bundle.</p>
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
        will also be transitively included in the final bundle.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="macos_command_line_application"></a>
## macos_command_line_application

```python
macos_command_line_application(name, bundle_id, infoplists, linkopts,
minimum_os_version, version, deps)
```

Builds a macOS command line application.

A command line application is a standalone binary file, rather than a `.app`
bundle like those produced by [`macos_application`](#macos_application). Unlike
a plain `apple_binary` target, however, this rule supports versioning and
embedding an `Info.plist` into the binary and allows the binary to be
code-signed.

Targets created with `macos_command_line_application` can be executed using
`bazel run`.

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
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        application.</p>
        <p>If present, this value will be embedded in an <code>Info.plist</code>
        in the application binary.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the application and is embedded
        into the binary. Please see <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
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
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
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
        <p>A list of dependencies, such as libraries, that are linked into the
        final binary. Any resources found in those dependencies are ignored.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="macos_dylib"></a>
## macos_dylib

```python
macos_dylib(name, bundle_id, infoplists, linkopts, minimum_os_version, version,
deps)
```

Builds a macOS dylib.

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
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        target.</p>
        <p>If present, this value will be embedded in an <code>Info.plist</code>
        in the binary.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the target and is embedded
        into the binary. Please see <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
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
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
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
        <p>A list of dependencies, such as libraries, that are linked into the
        final binary. Any resources found in those dependencies are ignored.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="macos_extension"></a>
## macos_extension

```python
macos_extension(name, additional_contents, bundle_id, bundle_name,
entitlements, entitlements_validation, infoplists, ipa_post_processor,
linkopts, minimum_os_version, provisioning_profile, strings, version, deps)
```

Builds and bundles a macOS extension.

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
      <td><code>additional_contents</code></td>
      <td>
        <p><code>Dictionary of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a> to strings; optional</code></p>
        <p>Files that should be copied into specific subdirectories of the
        <code>Contents</code> folder in the application. The keys of this
        dictionary are labels pointing to single files,
        <code>filegroup</code>s, or targets; the corresponding value is the
        name of the subdirectory of <code>Contents</code> where they should
        be placed.</p>
        <p>The relative directory structure of <code>filegroup</code>
        contents is preserved when they are copied into the desired
        <code>Contents</code> subdirectory.</p>
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
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.provisionprofile</code> file) to use
        when bundling the extension.</p>
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

<a name="macos_kernel_extension"></a>
## macos_kernel_extension

```python
macos_bundle(name, additional_contents, bundle_id, bundle_name, entitlements,
entitlements_validation, infoplists, ipa_post_processor, linkopts,
minimum_os_version, provisioning_profile, strings, version, deps)
```

Builds and bundles a macOS Kernel Extension.

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
      <td><code>additional_contents</code></td>
      <td>
        <p><code>Dictionary of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a> to strings; optional</code></p>
        <p>Files that should be copied into specific subdirectories of the
        <code>Contents</code> folder in the bundle. The keys of this
        dictionary are labels pointing to single files,
        <code>filegroup</code>s, or targets; the corresponding value is the
        name of the subdirectory of <code>Contents</code> where they should
        be placed.</p>
        <p>The relative directory structure of <code>filegroup</code>
        contents is preserved when they are copied into the desired
        <code>Contents</code> subdirectory.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        target.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the extension). If this
        attribute is not set, then the <code>name</code> of the target will be
        used instead.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the target.
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
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the target. At least one
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
        contents of the archive; the bundle directory will be that directory's
        only contents.</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra linker flags</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.provisionprofile</code> file) to use
        when bundling the target.</p>
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
        <p>A list of dependencies targets to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final bundle.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="macos_spotlight_importer"></a>
## macos_spotlight_importer

```python
macos_spotlight_importer(name, additional_contents, bundle_id, bundle_name,
entitlements, entitlements_validation, infoplists, ipa_post_processor, linkopts,
minimum_os_version, provisioning_profile, strings, version, deps)
```

Builds and bundles a macOS Spotlight Importer.

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
      <td><code>additional_contents</code></td>
      <td>
        <p><code>Dictionary of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a> to strings; optional</code></p>
        <p>Files that should be copied into specific subdirectories of the
        <code>Contents</code> folder in the bundle. The keys of this
        dictionary are labels pointing to single files,
        <code>filegroup</code>s, or targets; the corresponding value is the
        name of the subdirectory of <code>Contents</code> where they should
        be placed.</p>
        <p>The relative directory structure of <code>filegroup</code>
        contents is preserved when they are copied into the desired
        <code>Contents</code> subdirectory.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        target.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the extension). If this
        attribute is not set, then the <code>name</code> of the target will be
        used instead.</p>
      </td>
    </tr>
    <tr>
      <td><code>entitlements</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The entitlements file required for device builds of the target.
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
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the target. At least one
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
        contents of the archive; the bundle directory will be that directory's
        only contents.</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra linker flags</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.provisionprofile</code> file) to use
        when bundling the target.</p>
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
        <p>A list of dependencies targets to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final bundle.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="macos_unit_test"></a>
## macos_unit_test

```python
macos_unit_test(name, bundle_id, infoplists, minimum_os_version, runner,
test_host, data, deps)
```

Builds and bundles a macOS unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

`macos_unit_test` targets can work in two modes: as app or library tests. If the
`test_host` attribute is set to an `macos_application` target, the tests will
run within that application's context. If no `test_host` is provided, the tests
will run outside the context of an macOS application. Because of this, certain
functionalities might not be present (e.g. UI layout, NSUserDefaults). You can
find more information about testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

The following is a list of the `macos_unit_test` specific attributes; for a list
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
      <td><code>env</code></td>
      <td>
        <p><code>Dictionary of strings; optional</code></p>
        <p>Dictionary of environment variables that should be set during the
        test execution.</p>
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
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.10"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>runner</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A target that will specify how the tests are to be run. This target
        needs to be defined using a rule that provides the <code>AppleTestRunnerInfo</code>
        provider. The default runner can run logic and application-based tests.
        Support for this rule in Tulsi is not yet available.</p>
      </td>
    </tr>
    <tr>
      <td><code>test_host</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>An <code>macos_application</code> target that represents the app that
        will host the tests. If not specified, the runner will assume it's a
        library-based test.</p>
      </td>
    </tr>
    <tr>
      <td><code>data</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>The list of files needed by this rule at runtime.</p>
        <p>Targets named in the data attribute will appear in the <code>*.runfiles</code>
        area of this rule, if it has one. This may include data files needed by
        a binary or library, or other programs needed by it.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of dependencies targets to link into the binary. Any
        resources, such as asset catalogs, that are referenced by those targets
        will also be transitively included in the final test bundle.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="macos_ui_test"></a>
## macos_ui_test

```python
macos_ui_test(name, bundle_id, infoplists, minimum_os_version, runner,
test_host, data, deps, [test specific attributes])
```

Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

The following is a list of the `macos_ui_test` specific attributes; for a list
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
      <td><code>env</code></td>
      <td>
        <p><code>Dictionary of strings; optional</code></p>
        <p>Dictionary of environment variables that should be set during the
        test execution.</p>
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
        <code>"10.12"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--ios_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>runner</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A target that will specify how the tests are to be run. This target
        needs to be defined using a rule that provides the
        <code>AppleTestRunnerInfo</code> provider.</p>
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
        <p>A list of dependencies targets to link into the binary. Any
        resources, such as asset catalogs, that are referenced by those targets
        will also be transitively included in the final test bundle.</p>
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

<a name="macos_xpc_service"></a>
## macos_xpc_service

```python
macos_xpc_service(name, additional_contents, bundle_id, bundle_name,
entitlements, entitlements_validation, infoplists, ipa_post_processor, linkopts,
minimum_os_version, provisioning_profile, strings, version, deps)
```

Builds and bundles a macOS XPC Service.

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
      <td><code>additional_contents</code></td>
      <td>
        <p><code>Dictionary of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a> to strings; optional</code></p>
        <p>Files that should be copied into specific subdirectories of the
        <code>Contents</code> folder in the application. The keys of this
        dictionary are labels pointing to single files,
        <code>filegroup</code>s, or targets; the corresponding value is the
        name of the subdirectory of <code>Contents</code> where they should
        be placed.</p>
        <p>The relative directory structure of <code>filegroup</code>
        contents is preserved when they are copied into the desired
        <code>Contents</code> subdirectory.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>The bundle ID (reverse-DNS path followed by app name) of the
        target.</p>
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
        <p>The entitlements file required for device builds of the target.
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
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the target. At least one
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
        contents of the archive; the <code>*.app</code> bundle for the
        application will be the directory's only contents.</p>
        <p>Any changes made by the tool must be made in this directory, and
        the tool's execution must be hermetic given these inputs to ensure that
        the result can be safely cached.</p>
      </td>
    </tr>
    <tr>
      <td><code>linkopts</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>A list of strings representing extra linker flags</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional string indicating the minimum macOS version supported by the
        target, represented as a dotted version number (for example,
        <code>"10.11"</code>). If this attribute is omitted, then the value specified
        by the flag <code>--macos_minimum_os</code> will be used instead.
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.provisionprofile</code> file) to use
        when bundling the target.</p>
      </td>
    </tr>
    <tr>
      <td><code>strings</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.strings</code> files, often localizable. These files
        are converted to binary plists (if they are not already) and placed in the
        root of the final target bundle, unless a file's immediate containing
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
        <p>A list of dependencies targets to be linked. Any resources, such as
        asset catalogs, that are referenced by those targets will also be
        transitively included in the final application.</p>
      </td>
    </tr>
  </tbody>
</table>
