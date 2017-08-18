# Providers

This page describes **providers** that are propagated by the rules in this
repository.

Most users will not need to use these providers to simply create and build Apple
targets, but if you want to write your own custom rules that interact with these
rules, then you will use these providers to communicate between them.

## Provider types

* [AppleBundleInfo](#AppleBundleInfo)
* [AppleBundlingSwiftInfo](#AppleBundlingSwiftInfo)
* [AppleBundleVersionInfo](#AppleBundleVersionInfo)
* [IosApplicationBundleInfo](#IosApplicationBundleInfo)
* [IosExtensionBundleInfo](#IosExtensionBundleInfo)
* [IosFrameworkBundleInfo](#IosFrameworkBundleInfo)
* [IosXcTestBundleInfo](#IosXcTestBundleInfo)
* [MacosApplicationBundleInfo](#MacosApplicationBundleInfo)
* [MacosExtensionBundleInfo](#MacosExtensionBundleInfo)
* [SwiftInfo](#SwiftInfo)
* [TvosApplicationBundleInfo](#TvosApplicationBundleInfo)
* [TvosExtensionBundleInfo](#TvosExtensionBundleInfo)
* [WatchosApplicationBundleInfo](#WatchosApplicationBundleInfo)
* [WatchosExtensionBundleInfo](#WatchosExtensionBundleInfo)

## Provider helper types

* [AppleResourceSet](#AppleResourceSet)

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
      <td><code>propagated_framework_files</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s</p>
        <p>Individual files that make up framework dependencies of the target
        but which are propagated to an embedding target instead of being bundled
        with the propagating target. For example, an <code>ios_extension</code>
        propagates its frameworks to be bundled with the embedding
        <code>ios_application</code> rather than bundling the frameworks with
        the extension itself. (This field mainly supports
        <code>objc_framework</code>, which propagates its contents as individual
        files instead of a zipped framework; see
        <code>propagated_framework_zips</code> as well.)</p>
      </td>
    </tr>
    <tr>
      <td><code>propagated_framework_zips</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s</p>
        <p>Files that are zipped framework/dylib dependencies of the target but
        which are propagated to an embedding target instead of being bundled
        with the propagating target. For example, an <code>ios_extension</code>
        propagates its frameworks to be bundled with the embedding
        <code>ios_application</code> rather than bundling the frameworks with
        the extension itself.</p>
      </td>
    </tr>
    <tr>
      <td><code>root_merge_zips</code></td>
      <td>
        <p><code>list</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s</p>
        <p>A list of any <code>.zip</code> files that should be merged into the
        root of the top-level archive (such as <code>ios_application</code> or
        <code>skylark_tvos_application</code>) that embeds the target propagating this
        provider.</p>
        <p>For example, a target that uses Swift must propagate a copy of the
        Swift dylibs that will be packaged in a <code>SwiftSupport</code>
        directory that is a sibling of the <code>Payload</code> directory in the
        IPA.</p>
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

<a name="AppleBundlingSwiftInfo"></a>
## AppleBundlingSwiftInfo

This provider is used to indicate whether Swift is required by any code in the
target (but not in any of its embedded bundles). In other words, this only
applies within the bundle's direct dependencies (`deps`); it does not pass
through application/extension boundaries. For example, if an extension uses
Swift but an application does not, then the application does not "use Swift" as
defined by this provider.

This provider is mainly an implementation detail of the bundling aspect and is
not intended to be used by other rules.

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
      <td><code>uses_swift</code></td>
      <td>
        <p>Boolean</p>
        <p>True if Swift is used by the target propagating this provider or
        any of its direct dependencies (its <code>deps</code> attribute).</p>
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

<a name="AppleResourceInfo"></a>
## AppleResourceInfo

This provider contains information about resources belonging to a target that
should be included in any bundle that depends on that target. Resources are
files such as asset catalogs, `.strings` files, storyboards and XIBs, or any
other data that should be included in the bundle.

To write a custom rule that includes resources in a bundle, have that rule
return an instance of `AppleResourceInfo` that contains the files you wish to
be bundled. Then create a target using that rule and include it in the `deps` of
the application, extension, or other kind of bundle where you want those
resources to be. (See
[the implementation of `swift_library`](https://github.com/bazelbuild/rules_apple/blob/master/apple/swift.bzl)
for an example.)

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
      <td><code>resource_sets</code></td>
      <td>
        <p><code>list</code> of <code><a href="#AppleResourceSet">AppleResourceSet</a></code>s</p>
        <p>A list of values returned by
        <code><a href="#AppleResourceSet">AppleResourceSet</a></code> that
        defines a logical grouping of resources to be included in the depending
        bundle.</p>
      </td>
    </tr>
  </tbody>
</table>

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

<a name="IosXcTestBundleInfo"></a>
## IosXcTestBundleInfo

Denotes a target that is an iOS .xctest bundle.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically an iOS .xctest bundle (and
not some other Apple bundle). Rule authors who with to require that a dependency
is an iOS .xctest bundle should use this provider to describe that requirement.

<a name="MacosApplicationBundleInfo"></a>
## MacosApplicationBundleInfo

Denotes that a target is a macOS application.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application bundle
(and not some other Apple bundle). Rule authors who wish to require that a
dependency is a macOS application should use this provider to describe that
requirement.

<a name="MacosExtensionBundleInfo"></a>
## MacosExtensionBundleInfo

Denotes that a target is a macOS application extension.

This provider does not contain any fields of its own at this time but is used as
a "marker" to indicate that a target is specifically a macOS application
extension bundle (and not some other Apple bundle). Rule authors who wish to
require that a dependency is a macOS application extension should use this
provider to describe that requirement.

<a name="SwiftInfo"></a>
## SwiftInfo

Provides information about the transitive dependencies of a Swift library.

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
      <td><code>transitive_defines</code></td>
      <td>
        <p><code>depset</code> of <code>string</code>s</p>
        <p>The set of conditional compilation flags defined by the propagating
        target and all of its transitive dependencies.</p>
      </td>
    </tr>
    <tr>
      <td><code>transitive_libs</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s</p>
        <p>The set of static library (<code>.a</code>) files output by the
        propagating target and all of its transitive dependencies.</p>
      </td>
    </tr>
    <tr>
      <td><code>transitive_modules</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s</p>
        <p>The set of <code>.swiftmodule</code> files output by the propagating
        target and all of its transitive dependencies.</p>
      </td>
    </tr>
  </tbody>
</table>

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

---

<a name="AppleResourceSet"></a>
## AppleResourceSet

This is a "constructor-like" function that returns a value describing a set of
resources and the metadata required to process and bundle them. The
[`AppleResourceInfo`](#AppleResourceInfo) provider propagates a list of these
values to describe the content that should be bundled for a target based on its
resources and the resources from its transitive dependencies.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Arguments</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>bundle_dir</code></td>
      <td>
        <p>String; optional (defaults to <code>None</code>)</p>
        <p>The path within the final bundle (relative to its resources root)
        where the resources in this set should be bundled. For example, a rule
        that creates <code>.bundle</code> directories could specify something of
        the form <code>"Foo.bundle"</code> here, whereas library rules that
        propagate resources to the depending application/extension itself should
        specify <code>None</code> (or omit it, since it is the default).</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s; optional (defaults to empty)</p>
        <p>Partial <code>.plist</code> files that sould be merged along with
        the target's other partial <code>.plist</code>s to produce the final
        <code>Info.plist</code> for the depending bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>objc_bundle_imports</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s; optional (defaults to empty)</p>
        <p>Resources that came from an <code>objc_bundle</code> target and need
        to have their paths stripped of any segments before the
        <code>*.bundle</code> portion of their name. (This is mainly for legacy
        support and will be removed once <code>objc_bundle</code> is rewritten.)
        </p>
      </td>
    </tr>
    <tr>
      <td><code>resources</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s; optional (defaults to empty)</p>
        <p>Files representing resources that should be processed (if they are a
        known type) or copied (if they are not recognized) and placed in the
        bundle at the location specified by <code>bundle_dir</code>.</p>
        <p>The relative paths to these files are ignored, with the exception
        that files contained in a directory named <code>*.lproj</code> will be
        placed in a directory of the same name in the final bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>structured_resources</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s; optional (defaults to empty)</p>
        <p>Files representing resources that should be copied into the bundle
        without any processing at the location specified by
        <code>bundle_dir</code>, except that any <code>*.strings</code> and
        <code>*.plist</code> files will still be converted to binary format.</p>
        <p>Unlike <code>resources</code>, the paths of these files relative to
        their owning target are preserved.</p>
      </td>
    </tr>
    <tr>
      <td><code>structured_resource_zips</code></td>
      <td>
        <p><code>depset</code> of <code><a href="https://bazel.build/versions/master/docs/skylark/lib/File.html">File</a></code>s; optional (defaults to empty)</p>
        <p>Files representing ZIP archives whose contents should be unzipped
        into the bundle without any processing at the location specified by
        <code>bundle_dir</code>.</p>
        <p>The directory structure within the archive is preserved.</p>
      </td>
    </tr>
    <tr>
      <td><code>structured_resources</code></td>
      <td>
        <p>String; optional (defaults to <code>None</code>)</p>
        <p>The name of the Swift module with which these resources are
        associated. Some resource types, such as Interface Builder files or
        Core Data models, require the Swift module to be specified during
        compilation so that the classes they reference can be found at runtime.
        If this value is <code>None</code>, then the resources are not
        associated with a Swift module (for example, resources attached to
        Objective-C rules) and the name of the main
        application/extension/framework will be passed to the resource
        processing tool instead.</p>
      </td>
    </tr>
  </tbody>
  <thead>
    <tr>
      <th colspan="2">Returns</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td colspan="2">A <code>struct</code> whose fields are equal to the
      arguments specified above.</td>
    </tr>
  </tbody>
</table>
