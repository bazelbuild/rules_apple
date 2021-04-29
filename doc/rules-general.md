# General Apple build rules

<a name="apple_bundle_version"></a>
**MOVED** to [doc/versioning.md](/doc/versioning.md#apple_bundle_version)


<a name="apple_dynamic_framework_import"></a>
**MOVED** to [doc/apple.md](/doc/apple.md#apple_dynamic_framework_import)


<a name="apple_static_framework_import"></a>
**MOVED** to [doc/apple.md](/doc/apple.md#apple_static_framework_import)


<a name="dtrace_compile"></a>
## dtrace_compile

```python
dtrace_compile(name, srcs)
```

Compiles
[dtrace files with probes](https://www.ibm.com/developerworks/aix/library/au-dtraceprobes.html)
to generate header files to use those probes in C languages. The header files
generated will have the same name as the source files but with a `.h`
extension. Headers will be generated in a label scoped workspace relative file
structure. For example with a directory structure of

```
  Workspace
  foo/
    bar.d
```
and a target named `dtrace_gen` the header path would be
`<GENFILES>/dtrace_gen/foo/bar.h`.

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
        <p>dtrace source files to be compiled.</p>
      </td>
    </tr>
   </tbody>
</table>
