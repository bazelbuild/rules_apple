# Build rules for referencing resources

<a name="apple_bundle_import"></a>
## apple_bundle_import

```python
apple_bundle_import(name, bundle_imports)
```

This rule encapsulates an already-built bundle. It is defined by a list of files
in exactly one `.bundle` directory. `apple_bundle_import` targets need to be
added to library targets through the `data` attribute, or to other resource
targets (i.e. `apple_resource_bundle` and `apple_resource_group`) through the
`resources` attribute.

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
      <td><code>bundle_imports</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>The list of files under a <code>.bundle</code> directory to be
        propagated to the top-level bundling target.</p>
      </td>
    </tr>
  </tbody>
</table>


<a name="apple_core_ml_library"></a>
## apple_core_ml_library

```python
apple_core_ml_library(name, mlmodel)
```

This rule supports the integration of CoreML `mlmodel` files into Apple rules.
`apple_core_ml_library` targets are added directly into `deps` for both
`objc_library` and `swift_library` targets.

For Swift, import the `apple_core_ml_library` the same way you'd import an
`objc_library` or `swift_library` target. For `objc_library` targets,
`apple_core_ml_library` creates a header file named after the target.

For example, if the `apple_core_ml_library` target's label is
`//my/package:MyModel`, then to import this module in Swift you need to use
`import my_package_MyModel`. From Objective-C sources, you'd import the header
as `#import my/package/MyModel.h`.

This rule will also compile the `mlmodel` into an `mlmodelc` and propagate it
upstream so that it is packaged as a resource inside the top level bundle.

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
      <td><code>mlmodel</code></td>
      <td>
        <p><code><a href="https://bazel.build/versions/master/docs/build-ref.html#labels">Label</a>; required</code></p>
        <p>Reference to the <code>.mlmodel</code> file to process.</p>
      </td>
    </tr>
  </tbody>
</table>


<a name="apple_resource_bundle"></a>
## apple_resource_bundle

```python
apple_resource_bundle(name, bundle_name, infoplists, resources,
structured_resources)
```

This rule encapsulates a target which is provided to dependers as a bundle. An
`apple_resource_bundle`'s resources are put in a resource bundle in the top
level Apple bundle dependent. apple_resource_bundle targets need to be added to
library targets through the `data` attribute.

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
      <td><code>bundle_name</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired name of the bundle (without the <code>.bundle</code>
        extension). If this attribute is not set, then the <code>name</code> of
        the target will be used instead.</p>
      </td>
    </tr>
    <tr>
      <td><code>infoplists</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>A list of <code>.plist</code> files that will be merged to form the
        <code>Info.plist</code> that represents the extension. At least one
        file must be specified. Please see <a href="common_info.md#infoplist-handling">Info.plist Handling</a>
        for what is supported.</p>
      </td>
    </tr>
    <tr>
      <td><code>resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files to include in the resource bundle. Files that are processable
        resources, like .xib, .storyboard, .strings, .png, and others, will be
        processed by the Apple bundling rules that have those files as
        dependencies. Other file types that are not processed will be copied
        verbatim. These files are placed in the root of the resource bundle
        (e.g. <code>Payload/foo.app/bar.bundle/...</code>) in most cases.
        However, if they appear to be localized (i.e. are contained in a
        directory called <code>*.lproj</code>), they will be placed in a
        directory of the same name in the app bundle.</p>
        <p>You can also add other <code>apple_resource_bundle</code> and
        <code>apple_bundle_import</code> targets into <code>resources</code>,
        and the resource bundle structures will be propagated into the final
        bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>structured_resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files to include in the final resource bundle. They are not processed
        or compiled in any way besides the processing done by the rules that
        actually generate them. These files are placed in the bundle root in the
        same structure passed to this argument, so <code>["res/foo.png"]</code>
        will end up in <code>res/foo.png</code> inside the bundle.</p>
      </td>
    </tr>
  </tbody>
</table>


<a name="apple_resource_group"></a>
## apple_resource_group

```python
apple_resource_group(name, resources, structured_resources)
```

This rule encapsulates a target which provides resources to dependents. An
`apple_resource_group`'s `resources` and `structured_resources` are put in the
top-level Apple bundle target. `apple_resource_group` targets need to be added
to library targets through the `data` attribute, or to other
`apple_resource_bundle` or `apple_resource_group` targets through the
`resources` attribute.

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
      <td><code>resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files to include in the final bundle that depends on this target.
        Files that are processable resources, like .xib, .storyboard, .strings,
        .png, and others, will be processed by the Apple bundling rules that
        have those files as dependencies. Other file types that are not
        processed will be copied verbatim. These files are placed in the root of
        the final bundle (e.g. <code>Payload/foo.app/...</code>) in most cases.
        However, if they appear to be localized (i.e. are contained in a
        directory called <code>*.lproj</code>), they will be placed in a
        directory of the same name in the app bundle.</p>
        <p>You can also add <code>apple_resource_bundle</code> and
        <code>apple_bundle_import</code> targets into <code>resources</code>,
        and the resource bundle structures will be propagated into the final
        bundle.</p>
      </td>
    </tr>
    <tr>
      <td><code>structured_resources</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; optional</code></p>
        <p>Files to include in the final application bundle. They are not
        processed or compiled in any way besides the processing done by the
        rules that actually generate them. These files are placed in the bundle
        root in the same structure passed to this argument, so
        <code>["res/foo.png"]</code> will end up in <code>res/foo.png</code>
        inside the bundle.</p>
      </td>
    </tr>
  </tbody>
</table>
