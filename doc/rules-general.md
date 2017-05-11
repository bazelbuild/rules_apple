# General Apple build rules

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
