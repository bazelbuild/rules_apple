# Build rules for Swift

<a name="swift_library"></a>
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
