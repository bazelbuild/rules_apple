"""Rule that gathers licenses from given dependencies and produces an output of
all the license text."""

load(
    "@rules_license//rules:gather_licenses_info.bzl",
    "gather_licenses_info",
    "write_licenses_info",
)
load(
    "@rules_license//rules:providers.bzl",
    "LicensesInfo",
)

def _license_text_impl(ctx):
    licenses_info_file = ctx.actions.declare_file(
        "_{}_licenses_info.json".format(ctx.label.name),
    )
    write_licenses_info(ctx, ctx.attr.deps, licenses_info_file)

    inputs = [licenses_info_file]
    for dep in ctx.attr.deps:
        if LicensesInfo in dep:
            for license in dep[LicensesInfo].licenses.to_list():
                inputs.append(license.license_text)

    output = ctx.actions.declare_file("{}_licenses.plist".format(ctx.label.name))
    outputs = [output]

    args = ctx.actions.args()
    args.add("--licenses_info", licenses_info_file)
    args.add("--out", output)

    ctx.actions.run(
        arguments = [args],
        executable = ctx.executable._write_license_text,
        inputs = inputs,
        mnemonic = "GenerateLicenseText",
        outputs = outputs,
        progress_message = "Generating licenses text for %s" % ctx.label,
    )

    return [DefaultInfo(files = depset(outputs))]

license_text = rule(
    implementation = _license_text_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [gather_licenses_info],
            allow_files = True,
            doc = """
A list of targets to get LicenseInfo for. The output is the union of the
result, not a list of information for each dependency.
""",
        ),
        "format": attr.string(
            default = "plist",
            doc = """
The format controls how to package the text. Currently only supports the plist
format, so this attribute is for the validation purpose only.
""",
            values = ["plist"],
        ),
        "_write_license_text": attr.label(
            allow_files = True,
            cfg = "exec",
            default = Label("//tools/write_license_text"),
            executable = True,
        ),
    },
)
