# General Apple build rules

<a name="apple_bundle_version"></a>
## apple_bundle_version

```python
apple_bundle_version(name, build_label_pattern, build_version, capture_groups,
fallback_build_label, short_version_string)
```

Produces a target that contains versioning information for an Apple bundle.

This rule allows version numbers to be hard-coded into the BUILD file or
extracted from the build label passed into Bazel using the `--embed_label`
command line flag.

Targets created by this rule do not generate outputs themselves, but instead
should be used in the `version` attribute of an Apple application or extension
bundle target to set the version keys in that bundle's Info.plist file.

### Examples

```python
# A version scheme that uses hard-coded versions checked into your
# BUILD files.
apple_bundle_version(
    name = "simple",
    build_version = "1.0.134",
    short_version_string = "1.0",
)

ios_application(
    name = "foo_app",
    ...,
    version = ":simple",
)

# A version scheme that parses version information out of the build
# label and uses a fallback for developers' builds. For example, the
# following command
#
#    bazel build //myapp:myapp --embed_label=MyApp_1.2_build_345
#
# would yield the Info.plist values:
#
#    CFBundleVersion = "1.2.345"
#    CFBundleShortVersionString = "1.2"
#
# and the development builds using the command:
#
#    bazel build //myapp:myapp
#
# would yield the values:
#
#    CFBundleVersion = "99.99.99"
#    CFBundleShortVersionString = "99.99"
#
apple_bundle_version(
    name = "build_label_version",
    build_label_pattern = "MyApp_{version}_build_{build}",
    build_version = "{version}.{build}",
    capture_groups = {
        "version": "\d+\.\d+",
        "build": "\d+",
    },
    short_version_string = "{version}",
    fallback_build_label = "MyApp_99.99_build_99",
)

ios_application(
    name = "bar_app",
    ...,
    version = ":build_label_version",
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
      <td><code>build_label_pattern</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>A pattern that should contain placeholders inside curly braces
        (e.g., <code>"foo_{version}_bar"</code>) that is used to parse the
        build label passed into Bazel using the <code>--embed_label</code>
        command line flag. Each of the placeholders is expected to match one
        of the keys in the <code>capture_groups</code> attribute.</p>
        <p>NOTE: When using <code>build_label_pattern</code>, if a build
        is done <i>without</i> a <code>--embed_label=...</code> argument
        and there is no <code>fallback_build_label</code>,  then no
        version info will be set.</p>
      </td>
    </tr>
    <tr>
      <td><code>build_version</code></td>
      <td>
        <p><code>String; required</code></p>
        <p>A string that will be used as the value for the
        <code>CFBundleVersion</code> key in a depending bundle's Info.plist.
        If this string contains placeholders, then they will be replaced by
        strings captured out of <code>build_label_pattern</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>capture_groups</code></td>
      <td>
        <p><code>Dictionary of strings to strings; optional</code></p>
        <p>A dictionary where each key is the name of a placeholder found
        in <code>build_label_pattern</code> and the corresponding value is
        the regular expression that should match that placeholder. If this
        attribute is provided, then <code>build_label_pattern</code> must
        also be provided.</p>
      </td>
    </tr>
    <tr>
      <td><code>fallback_build_label</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>A string that will be used as the value for the <i>build label</i>
        if the build was done without <code>--embed_label</code>. This is only
        needed when also using <code>build_label_pattern</code>. This allows
        a version label to be used for version extraction during development
        when a label isn't normally provided. Some teams use the convention
        of having a version like <i>99.99.99</i> so it is clear it isn't
        being released to customers.</p>
        <p>NOTE: This is a <i>build label</i> and not a raw version number. It
        must match <code>build_label_pattern</code> so the values can be
        extracted and then have the <code>build_version</code> and
        <code>short_version_string</code> templates applied.</p>
      </td>
    </tr>
    <tr>
      <td><code>short_version_string</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>A string that will be used as the value for the
        <code>CFBundleShortVersionString</code> key in a depending bundle's
        Info.plist. If this string contains placeholders, then they will be
        replaced by strings captured out of <code>build_label_pattern</code>.
        This attribute is optional; if it is omitted, then the value of
        <code>build_version</code> will be used for this key as well.</p>
      </td>
    </tr>
  </tbody>
</table>


<a name="apple_dynamic_framework_import"></a>
## apple_dynamic_framework_import

```python
apple_dynamic_framework_import(name, framework_imports, deps)
```

This rule encapsulates an already-built dynamic framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_dynamic_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_dynamic_framework_import(
    name = "my_dynamic_framework",
    framework_imports = glob(["my_dynamic_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_dynamic_framework",
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
      <td><code>framework_imports</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>The list of files under a <code>.framework</code> directory which are
        provided to Apple based targets that depend on this target.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of labels; optional</code></p>
        <p>A list of targets that are dependencies of the target being built,
        which will be linked into that target.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="apple_static_framework_import"></a>
## apple_static_framework_import

```python
apple_static_framework_import(name, framework_imports, alwayslink, sdk_dylibs,
sdk_frameworks, weak_sdk_frameworks, deps)
```

This rule encapsulates an already-built static framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_static_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_static_framework_import(
    name = "my_static_framework",
    framework_imports = glob(["my_static_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_static_framework",
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
      <td><code>framework_imports</code></td>
      <td>
        <p><code>List of <a href="https://bazel.build/versions/master/docs/build-ref.html#labels">labels</a>; required</code></p>
        <p>The list of files under a <code>.framework</code> directory which are
        provided to Apple based targets that depend on this target.</p>
      </td>
    </tr>
    <tr>
      <td><code>alwayslink</code></td>
      <td>
        <p><code>Bool; optional</code></p>
        <p>If true, any binary that depends (directly or indirectly) on this framework
        will link in all the object files for the framework file, even if some
        contain no symbols referenced by the binary. This is useful if your code isn't
        explicitly called by code in the binary; for example, if you rely on runtime
        checks for protocol conformances added in extensions in the library but do not
        directly reference any other symbols in the object file that adds that
        conformance.</p>
      </td>
    </tr>
    <tr>
      <td><code>sdk_dylibs</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>Names of SDK <code>.dylib</code> libraries to link with. For
        instance, <code>libz</code> or <code>libarchive</code>.
        <code>libc++</code> is included automatically if the binary has any
        C++ or Objective-C++ sources in its dependency tree. When linking a
        binary, all libraries named in that binary's transitive dependency graph
        are used.</p>
      </td>
    </tr>
    <tr>
      <td><code>sdk_frameworks</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>Names of SDK frameworks to link with (e.g.
        <code>AddressBook</code>, <code>QuartzCore</code>).
        <code>UIKit</code> and <code>Foundation</code> are always included
        when building for the iOS, tvOS and watchOS platforms. For macOS, only
        <code>Foundation</code> is always included. When linking a top level
        binary, all SDK frameworks listed in that binary's transitive dependency
        graph are linked.</p>
      </td>
    </tr>
    <tr>
      <td><code>weak_sdk_frameworks</code></td>
      <td>
        <p><code>List of strings; optional</code></p>
        <p>Names of SDK frameworks to weakly link with. For instance,
        <code>MediaAccessibility</code>. In difference to regularly linked SDK
        frameworks, symbols from weakly linked frameworks do not cause an error
        if they are not present at runtime.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p><code>List of labels; optional</code></p>
        <p>A list of targets that are dependencies of the target being built,
        which will be linked into that target.</p>
      </td>
    </tr>
  </tbody>
</table>


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
