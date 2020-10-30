"""Variable substitution rule"""

def _substitution_impl(ctx):
    return [
        platform_common.TemplateVariableInfo({
            ctx.attr.var_name: ctx.file.src.path,
        }),
    ]

substitution = rule(
    implementation = _substitution_impl,
    attrs = {
        "var_name": attr.string(),
        "src": attr.label(
            allow_single_file = True,
        ),
    },
)

