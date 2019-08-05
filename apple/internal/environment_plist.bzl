load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:legacy_actions.bzl",
    "legacy_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _environment_plist(ctx):
    environment_plist = ctx.actions.declare_file(
        paths.join("{}-intermediates".format(ctx.label.name), "Environment-Info.plist"),
    )

    platform, sdk_version = platform_support.platform_and_sdk_version(ctx)
    platform_with_version = platform.name_in_plist.lower() + str(sdk_version)
    legacy_actions.run(
        ctx,
        outputs = [environment_plist],
        executable = ctx.executable._environment_plist,
        arguments = [
            "--platform",
            platform_with_version,
            "--output",
            environment_plist.path,
        ],
    )

    return [DefaultInfo(files = depset([environment_plist]))]

environment_plist = rule(
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        {
            "_environment_plist": attr.label(
                cfg = "host",
                executable = True,
                default = Label("@build_bazel_rules_apple//tools/environment_plist"),
            ),
            "platform_type": attr.string(default = str(apple_common.platform_type.ios)),
        },
    ),
    fragments = ["apple"],
    implementation = _environment_plist,
)
