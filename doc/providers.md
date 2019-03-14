# Providers

This page describes **providers** that are propagated by the rules in this
repository.

Most users will not need to use these providers to simply create and build Apple
targets, but if you want to write your own custom rules that interact with these
rules, then you will use these providers to communicate between them.

## Provider types

* [AppleBundleInfo](#AppleBundleInfo)
* [AppleBundleVersionInfo](#AppleBundleVersionInfo)
* [IosApplicationBundleInfo](#IosApplicationBundleInfo)
* [IosExtensionBundleInfo](#IosExtensionBundleInfo)
* [IosFrameworkBundleInfo](#IosFrameworkBundleInfo)
* [IosXcTestBundleInfo](#IosXcTestBundleInfo)
* [MacosApplicationBundleInfo](#MacosApplicationBundleInfo)
* [MacosExtensionBundleInfo](#MacosExtensionBundleInfo)
* [TvosApplicationBundleInfo](#TvosApplicationBundleInfo)
* [TvosExtensionBundleInfo](#TvosExtensionBundleInfo)
* [WatchosApplicationBundleInfo](#WatchosApplicationBundleInfo)
* [WatchosExtensionBundleInfo](#WatchosExtensionBundleInfo)

<a name="AppleBundleInfo"></a>
## AppleBundleInfo

This provider propagates general information about an Apple bundle that is not
specific to any particular bundle type. It is propagated by most bundling
rules&mdash;applications, extensions, frameworks, test bundles, and so forth.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Fields</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>archive</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code></p>
        <p>The archive that contains the built bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>archive_root</code></td>
      <td>
        <p><code>String</code></p>
        <p>The file system path (relative to the workspace root) where the
        signed bundle was constructed (before archiving). Other rules
        <strong>should not</strong> depend on this field; it is intended to
        support IDEs that want to read that path from the provider to avoid
        performance issues from unzipping the output archive.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_id</code></td>
      <td>
        <p><code>String</code></p>
        <p>The bundle identifier (i.e., <code>CFBundleIdentifier</code> in
        <code>Info.plist</code>) of the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String</code></p>
        <p>The name of the bundle, without the extension.</p>
      </td>
    </tr>
    <tr>
      <td><code>bundle_extension</code></td>
      <td>
        <p><code>String</code></p>
        <p>The bundle extension.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplist</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code></p>
        <p>The complete (binary format) <code>Info.plist</code> file build for
        the bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>minimum_os_version</code></td>
      <td>
        <p><code>String</code></p>
        <p>The minimum OS version (as a dotted version number like "9.0") that
        this bundle was built to support.</p>
      </td>
    </tr>
    <tr>
      <td><code>uses_swift</code></td>
      <td>
        <p>Boolean</p>
        <p>True if Swift is used by the target propagating this provider. This
        does not consider embedded bundles; for example, an Objective-C
        application containing a Swift extension would have this field set to
        true for the extension but false for the application.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="AppleBundleVersionInfo"></a>
## AppleBundleVersionInfo

Provides versioning information for an Apple bundle.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Fields</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>version_file</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code></p>
        <p>A <code>File</code> containing JSON-formatted text describing the
        version number information propagated by the target. It contains two
        keys:</p>
        <ul>
        <li><code>build_version</code>, which is a string that corresponds to
        <code>CFBundleVersion</code></li>
        <li><code>short_version_string</code>, which is a string that
        corresponds to <code>CFBundleShortVersionString</code>.
      </td>
    </tr>
  </tbody>
</table>

<a name="AppleResourceBundleInfo"></a>
## AppleResourceBundleInfo

Denotes that a target is an Apple resource bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an Apple resource bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an Apple resource bundle should use this provider to describe that
requirement.


<a name="IosApplicationBundleInfo"></a>
## IosApplicationBundleInfo

Denotes that a target is an iOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is an iOS application should use this provider to describe that
requirement.

<a name="IosExtensionBundleInfo"></a>
## IosExtensionBundleInfo

Denotes that a target is an iOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is an iOS application extension should use this
provider to describe that requirement.

<a name="IosFrameworkBundleInfo"></a>
## IosFrameworkBundleInfo

Denotes that a target is an iOS dynamic framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS dynamic framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS dynamic framework should use this provider to describe
that requirement.

<a name="IosStaticFrameworkBundleInfo"></a>
## IosStaticFrameworkBundleInfo

Denotes that a target is an iOS static framework.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS static framework
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS static framework should use this provider to describe
that requirement.

<a name="IosImessageApplicationBundleInfo"></a>
## IosImessageApplicationBundleInfo

Denotes that a target is an iOS iMessage application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage application should use this provider to describe
that requirement.

<a name="IosImessageExtensionBundleInfo"></a>
## IosImessageExtensionBundleInfo

Denotes that a target is an iOS iMessage extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS iMessage extension
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS iMessage extension should use this provider to describe
that requirement.

<a name="IosStickerPackExtensionBundleInfo"></a>
## IosStickerPackExtensionBundleInfo

Denotes that a target is an iOS Sticker Pack extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS Sticker Pack extension
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is an iOS Sticker Pack extension should use this provider to describe
that requirement.

<a name="IosXcTestBundleInfo"></a>
## IosXcTestBundleInfo

Denotes a target that is an iOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS .xctest bundle (and
not some other Apple bundle). Rule authors who wish to require that a dependency
is an iOS .xctest bundle should use this provider to describe that requirement.

<a name="MacosApplicationBundleInfo"></a>
## MacosApplicationBundleInfo

Denotes that a target is a macOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS application should use this provider to describe that
requirement.

<a name="MacosBundleBundleInfo"></a>
## MacosBundleBundleInfo

Denotes that a target is a macOS loadable bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS loadable bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS loadable bundle should use this provider to describe that
requirement.

<a name="MacosExtensionBundleInfo"></a>
## MacosExtensionBundleInfo

Denotes that a target is a macOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a macOS application extension should use this
provider to describe that requirement.

<a name="MacosKernelExtensionBundleInfo"></a>
## MacosKernelExtensionBundleInfo

Denotes that a target is a macOS kernel extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS kernel extension
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS kernel extension should use this provider to describe that
requirement.

<a name="MacosSpotlightImporterBundleInfo"></a>
## MacosSpotlightImporterBundleInfo

Denotes that a target is a macOS Spotlight Importer bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS Spotlight importer
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS Spotlight importer should use this provider to describe that
requirement.

<a name="MacosXPCServiceBundleInfo"></a>
## MacosXPCServiceBundleInfo

Denotes that a target is a macOS XPC Service bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS XPC service
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS XPC service should use this provider to describe that
requirement.

<a name="MacosXcTestBundleInfo"></a>
## MacosXcTestBundleInfo

Denotes a target that is a macOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS .xctest bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS .xctest bundle should use this provider to describe that
requirement.

<a name="TvosApplicationBundleInfo"></a>
## TvosApplicationBundleInfo

Denotes that a target is a tvOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a tvOS application should use this provider to describe that
requirement.

<a name="TvosExtensionBundleInfo"></a>
## TvosExtensionBundleInfo

Denotes that a target is a tvOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a tvOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a tvOS application extension should use this
provider to describe that requirement.

<a name="WatchosApplicationBundleInfo"></a>
## WatchosApplicationBundleInfo

Denotes that a target is a watchOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
bundle (and not some other Apple bundle). Rule authors who wish to require that
a dependency is a watchOS application should use this provider to describe that
requirement.

<a name="WatchosExtensionBundleInfo"></a>
## WatchosExtensionBundleInfo

Denotes that a target is a watchOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a watchOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a watchOS application extension should use this
provider to describe that requirement.
