# General Apple build rules

<a name="apple_bundle_version"></a>
## apple_bundle_version

```python
apple_bundle_version(name, build_label_pattern, build_version, capture_groups,
short_version_string)
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
# label. For example, the following command
#
#    bazel build //myapp:myapp --embed_label=MyApp_1.2_build_345
#
# would yield the Info.plist values:
#
#    CFBundleVersion = "1.2.345"
#    CFBundleShortVersionString = "1.2"
#
apple_bundle_version(
    name = "build_label_version",
    build_label_pattern = "MyApp_{version}_build_{build}",
    build_version = "{version}.{build}",
    capture_group = {
        "version": "\d+\.\d+",
        "build": "\d+",
    },
    short_version_string = "{version}",
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


<a name="apple_genrule"></a>
## apple_genrule

Variation of `genrule` that provides an Apple-specific environment and `make`
variables. This rule will only run on macOS.

This rule takes the same attributes as Bazel's native `genrule`; please refer to
its
[documentation](https://bazel.build/versions/master/docs/be/general.html#genrule)
for a full description of those attributes.

Example of use:

```python
load("@build_bazel_rules_apple//apple:apple_genrule.bzl", "apple_genrule")

apple_genrule(
    name = "world",
    outs = ["hi"],
    cmd = "touch $(@)",
)
```

This rule also does location expansion, much like the native `genrule`. For
example, `$(location hi)` may be used to refer to the output in the above
example.

The set of `make` variables that are supported for this rule:

* `$OUTS`: The `outs` list. If you have only one output file, you can also use
  `$@`.
* `$SRCS`: The `srcs` list (or more precisely, the path names of the files
    corresponding to labels in the `srcs` list). If you have only one source
    file, you can also use `$<`.
* `$<`: `srcs`, if it's a single file.
* `$@`: `outs`, if it's a single file.

The following environment variables are added to the rule action:

* `$DEVELOPER_DIR`: The base developer directory as defined on Apple
  architectures, most commonly used in invoking Apple tools such as `xcrun`.
