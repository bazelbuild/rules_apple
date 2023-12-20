"""
An iOS test runner rule that uses xctestrun files to run unit test bundles on
simulators. This rule currently doesn't support UI tests or running on device.
"""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "apple_provider",
)

def _get_template_substitutions(
        *,
        device_type,
        os_version,
        simulator_creator,
        reuse_simulator):
    substitutions = {
        "device_type": device_type,
        "os_version": os_version,
        "simulator_creator.py": simulator_creator,
        "reuse_simulator": reuse_simulator,
    }

    return {"%({})s".format(key): value for key, value in substitutions.items()}

def _get_execution_environment(ctx):
    xcode_version = str(ctx.attr._xcode_config[apple_common.XcodeVersionConfig].xcode_version())
    if not xcode_version:
        fail("error: No xcode_version in _xcode_config")

    return {"XCODE_VERSION_OVERRIDE": xcode_version}

def _impl(ctx):
    os_version = str(ctx.attr.os_version or ctx.fragments.objc.ios_simulator_version or
                     ctx.attr._xcode_config[apple_common.XcodeProperties].default_ios_sdk_version)

    # TODO: Ideally we would be smarter about picking a device, but we don't know what the current version of Xcode supports
    device_type = ctx.attr.device_type or ctx.fragments.objc.ios_simulator_device or "iPhone 12"

    if not os_version:
        fail("error: os_version must be set on ios_xctestrun_runner, or passed with --ios_simulator_version")
    if not device_type:
        fail("error: device_type must be set on ios_xctestrun_runner, or passed with --ios_simulator_device")

    ctx.actions.expand_template(
        template = ctx.file._test_template,
        output = ctx.outputs.test_runner_template,
        substitutions = _get_template_substitutions(
            device_type = device_type,
            os_version = os_version,
            simulator_creator = ctx.executable._simulator_creator.short_path,
            reuse_simulator = "true" if ctx.attr.reuse_simulator else "false",
        ),
    )

    return [
        apple_provider.make_apple_test_runner_info(
            execution_environment = _get_execution_environment(ctx),
            execution_requirements = {"requires-darwin": ""},
            test_runner_template = ctx.outputs.test_runner_template,
        ),
        DefaultInfo(
            runfiles = ctx.attr._simulator_creator[DefaultInfo].default_runfiles,
        ),
    ]

ios_googletest_runner = rule(
    _impl,
    attrs = {
        "device_type": attr.string(
            default = "",
            doc = """
The device type of the iOS simulator to run test. The supported types correspond
to the output of `xcrun simctl list devicetypes`. E.g., iPhone X, iPad Air.
By default, it reads from --ios_simulator_device or falls back to some device.
""",
        ),
        "os_version": attr.string(
            default = "",
            doc = """
The os version of the iOS simulator to run test. The supported os versions
correspond to the output of `xcrun simctl list runtimes`. E.g., 15.5.
By default, it reads --ios_simulator_version and then falls back to the latest
supported version.
""",
        ),
        "reuse_simulator": attr.bool(
            default = True,
            doc = """
Toggle simulator reuse. The default behavior is to reuse an existing device of the same type and OS version. When disabled, a new simulator is created before testing starts and shutdown when the runner completes.
""",
        ),
        "_simulator_creator": attr.label(
            default = Label(
                "@build_bazel_rules_apple//apple/testing/default_runner:simulator_creator",
            ),
            executable = True,
            cfg = "exec",
        ),
        "_test_template": attr.label(
            default = Label(
                "@build_bazel_rules_apple//apple/testing/default_runner:ios_googletest_runner.template.sh",
            ),
            allow_single_file = True,
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                name = "xcode_config_label",
                fragment = "apple",
            ),
        ),
    },
    outputs = {
        "test_runner_template": "%{name}.sh",
    },
    fragments = ["apple", "objc"],
)
