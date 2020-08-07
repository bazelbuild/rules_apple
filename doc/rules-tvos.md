# Build rules for tvOS

<a name="tvos_application"></a>
## tvos_application

```python
tvos_application(name, app_icons, bundle_id, bundle_name, entitlements,
entitlements_validation, extensions, frameworks, infoplists, ipa_post_processor,
launch_images, linkopts, minimum_os_version, provisioning_profile,
resources, settings_bundle, strings, version, deps)
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
        that this application depends on. <b>NOTE:</b> Adding a
        <code>provisioning_profile</code> to any frameworks listed will make the
        signing/caching more efficient.</p>
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
        <p><code>String; required</code></p>
        <p>A required string indicating the minimum tvOS version supported by
        the target, represented as a dotted version number (for example,
        <code>"10.0"</code>).
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
      <td><code>resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of associated resource bundles or files that will be bundled into the final bundle.
        </p>
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
minimum_os_version, resources, strings, version, deps)
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
        <p><code>String; required</code></p>
        <p>A required string indicating the minimum tvOS version supported by
        the target, represented as a dotted version number (for example,
        <code>"10.0"</code>).
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
      <td><code>resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of associated resource bundles or files that will be bundled into the final bundle.
        </p>
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
tvos_framework(name, bundle_id, bundle_name, exported_symbols_lists,
extension_safe, frameworks, infoplists, ipa_post_processor, linkopts,
minimum_os_version, provisioning_profile, resources, strings, version, deps)
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
      <td><code>exported_symbols_lists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of targets containing exported symbols lists files for the
        linker to control symbol resolution. Each file is expected to have a
        list of global symbol names that will remain as global symbols in the
        compiled binary owned by this framework.  All other global symbols will
        be treated as if they were marked as __private_extern__ (aka
        visibility=hidden) and will not be global in the output file. See the
        man page documentation for ld(1) on macOS for more details.</p>
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
        <p><code>String; required</code></p>
        <p>A required string indicating the minimum tvOS version supported by
        the target, represented as a dotted version number (for example,
        <code>"10.0"</code>).
      </td>
    </tr>
    <tr>
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the framework bundle. This value is optional and is
        expected to match the <code>provisioning_profile</code> of the
        <code>tvos_application</code>, but it will make signing/caching more
        efficient. <strong>NOTE</strong>: This will codesign the framework when
        it is built standalone.</p>
      </td>
    </tr>
    <tr>
      <td><code>resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of associated resource bundles or files that will be bundled into the final application.
        </p>
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

<a name="tvos_static_framework"></a>
## tvos_static_framework

```python
tvos_static_framework(name, avoid_deps, hdrs, bundle_name, exclude_resources,
families, ipa_post_processor, linkopts, minimum_os_version, strings, version,
deps)
```

Builds and bundles an tvOS static framework for third-party distribution.

A static framework is bundled like a dynamic framework except that the embedded
binary is a static library rather than a dynamic library. It is intended to
create distributable static SDKs or artifacts that can be easily imported into
other Xcode projects; it is specifically **not** intended to be used as a
dependency of other Bazel targets. For that use case, use the corresponding
`objc_library` targets directly.

Unlike other tvOS bundles, the fat binary in an `tvos_static_framework` may
simultaneously contain simulator and device architectures (that is, you can
build a single framework artifact that works for all architectures by specifying
`--tvos_cpus=x86_64,arm64` when you build).

`tvos_static_framework` supports Swift, but there are some constraints:

* `tvos_static_framework` with Swift only works with Xcode 11 and above, since
  the required Swift functionality for module compatibility is available in
  Swift 5.1.
* `tvos_static_framework` only supports a single direct `swift_library` target
  that does not depend transitively on any other `swift_library` targets. The
  Swift compiler expects a framework to contain a single Swift module, and each
  `swift_library` target is its own module by definition.
* `tvos_static_framework` does not support mixed Objective-C and Swift public
  interfaces. This means that the `umbrella_header` and `hdrs` attributes are
  unavailable when using `swift_library` dependencies. You are allowed to depend
  on `objc_library` from the main `swift_library` dependency, but note that only
  the `swift_library`'s public interface will be available to users of the
  static framework.

When using Swift, the `tvos_static_framework` bundles `swiftinterface` and
`swiftdocs` file for each of the required architectures. It also bundles an
umbrella header which is the header generated by the single `swift_library`
target. Finally, it also bundles a `module.modulemap` file pointing to the
umbrella header for Objetive-C module compatibility. This umbrella header and
modulemap can be skipped by disabling the `swift.no_generated_header` feature (
i.e. `--features=-swift.no_generated_header`).

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
        <p>Note that none of these headers should have the name of the bundle,
        otherwise conflicts will occur during the generation process. There is
        one exception that, if this list contains only one header, and it has
        the name of the bundle, then that header will be bundled into the
        framework and no umbrella header will be generated.</p>
      </td>
    </tr>
    <tr>
      <td><code>umbrella_header</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>An optional single <code>.h</code> file to use as the umbrella
        header for this framework. Usually, this header will have the same name as this
        target, so that clients can load the header using the <code>#import
        &lt;MyFramework/MyFramework.h&gt;</code> format. If this attribute is not specified
        (the common use case), an umbrella header will be generated under the same name
        as this target.</p>
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
        <p>A list of strings representing extra flags that should be passed to
        the linker.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>A required string indicating the minimum tvOS version supported by
        the target, represented as a dotted version number (for example,
        <code>"9.0"</code>).
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

## tvos_ui_test

```python
tvos_ui_test(name, bundle_id, infoplists, minimum_os_version, resources, runner,
test_host, data, deps, provisioning_profile, [test specific attributes])
```

Builds and bundles a tvOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

Note: tvOS UI tests are not currently supported in the default test runner.

The following is a list of the `tvos_ui_test` specific attributes; for a list of
the attributes inherited by all test rules, please check the
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
        <p><code>String; required</code></p>
        <p>A required string indicating the minimum tvOS version supported by
        the target, represented as a dotted version number (for example,
        <code>"10.0"</code>).
      </td>
    </tr>
    <tr>
      <td><code>resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of associated resource bundles or files that will be bundled into the final bundle.
        </p>
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
        <p>A <code>tvos_application</code> target that represents the app that
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
        a binary or library, or other programs needed by it.
        <strong>NOTE</strong>: Files will be made available to the test runner,
        but will not be bundled into the resulting <code>.xctest</code>
        bundle.</p>
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
      <td><code>provisioning_profile</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>The provisioning profile (<code>.mobileprovision</code> file) to use
        when bundling the test bundle. This value is optional for simulator
        builds as the simulator doesn't fully enforce entitlements, but is
        <strong>required for device builds.</strong></p>
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

## tvos_unit_test

```python
tvos_unit_test(name, bundle_id, infoplists, minimum_os_version, resources, runner,
test_host, data, deps, [test specific attributes])
```

Builds and bundles a tvOS Unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

Note: tvOS unit tests are not currently supported in the default test runner.

`tvos_unit_test` targets can work in two modes: as app or library tests. If the
`test_host` attribute is set to an `tvos_application` target, the tests will run
within that application's context. If no `test_host` is provided, the tests will
run outside the context of a tvOS application. Because of this, certain
functionalities might not be present (e.g. UI layout, NSUserDefaults). You can
find more information about app and library testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

The following is a list of the `tvos_unit_test` specific attributes; for a list
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
        <p><code>String; required</code></p>
        <p>A required string indicating the minimum tvOS version supported by
        the target, represented as a dotted version number (for example,
        <code>"10.0"</code>).
      </td>
    </tr>
    <tr>
      <td><code>resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of associated resource bundles or files that will be bundled into the final bundle.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>runner</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A target that will specify how the tests are to be run. This target
        needs to be defined using a rule that provides the <code>AppleTestRunnerInfo</code>
        provider.</p>
      </td>
    </tr>
    <tr>
      <td><code>test_host</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; optional</code></p>
        <p>A <code>tvos_application</code> target that represents the app that
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
        a binary or library, or other programs needed by it.
        <strong>NOTE</strong>: Files will be made available to the test runner,
        but will not be bundled into the resulting <code>.xctest</code>
        bundle.</p>
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

<a name="tvos_build_test"></a>
## tvos_build_test

```python
tvos_build_test(name, minimum_os_version, targets, [test specific attributes])
```

Test rule to check that the given library targets (Swift, Objective-C, C++)
build for tvOS.

Typical usage:

```starlark
tvos_build_test(
    name = "my_build_test",
    minimum_os_version = "12.0",
    targets = [
        "//some/package:my_library",
    ],
)
```

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
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>A required string indicating the minimum OS version that will be used
        as the deployment target when building the targets, represented as a
        dotted version number (for example, <code>"9.0"</code>).</p>
      </td>
    </tr>
      <td><code>targets</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>The targets to check for successful build.</p>
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
