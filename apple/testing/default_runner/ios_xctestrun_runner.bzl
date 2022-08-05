"""
An iOS test runner rule that uses xctestrun files to run unit test bundles on
simulators. This rule currently doesn't support UI tests or running on device.
"""

load("@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl", "AppleTestRunnerInfo")

def _get_template_substitutions(
        *,
        device_type,
        os_version,
        simulator_creator,
        random,
        xctestrun_template):
    substitutions = {
        "device_type": device_type,
        "os_version": os_version,
        "simulator_creator.py": simulator_creator,
        # "ordered" isn't a special string, but anything besides "random" for this field runs in order
        "test_order": "random" if random else "ordered",
        "xctestrun_template": xctestrun_template,
    }

    return {"%({})s".format(key): value for key, value in substitutions.items()}

def _get_execution_environment(ctx):
    xcode_version = str(ctx.attr._xcode_config[apple_common.XcodeVersionConfig].xcode_version())
    if not xcode_version:
        fail("error: No xcode_version in _xcode_config")

    return {"XCODE_VERSION_OVERRIDE": xcode_version}

def _ios_xctestrun_runner_impl(ctx):
    os_version = str(ctx.attr.os_version or ctx.fragments.objc.ios_simulator_version or
                     ctx.attr._xcode_config[apple_common.XcodeProperties].default_ios_sdk_version)

    # TODO: Ideally we would be smarter about picking a device, but we don't know what the versoin of Xcode supports
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
            random = ctx.attr.random,
            xctestrun_template = ctx.file._xctestrun_template.short_path,
        ),
    )

    return [
        AppleTestRunnerInfo(
            execution_environment = _get_execution_environment(ctx),
            execution_requirements = {"requires-darwin": ""},
            test_runner_template = ctx.outputs.test_runner_template,
        ),
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = [ctx.file._xctestrun_template],
            ).merge(ctx.attr._simulator_creator[DefaultInfo].default_runfiles),
        ),
    ]

ios_xctestrun_runner = rule(
    _ios_xctestrun_runner_impl,
    attrs = {
        "device_type": attr.string(
            default = "",
            doc = """
The device type of the iOS simulator to run test. The supported types correspond
to the output of `xcrun simctl list devicetypes`. E.g., iPhone X, iPad Air.
By default, it reads from --ios_simulator_device or falls back to some device.
""",
        ),
        "random": attr.bool(
            default = False,
            doc = """
Whether to run the tests in random order to identify unintended state
dependencies.
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
        "_simulator_creator": attr.label(
            default = Label(
                "@build_bazel_rules_apple//apple/testing/default_runner:simulator_creator",
            ),
            executable = True,
            cfg = "exec",
        ),
        "_test_template": attr.label(
            default = Label(
                "@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_runner.template.sh",
            ),
            allow_single_file = True,
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                name = "xcode_config_label",
                fragment = "apple",
            ),
        ),
        "_xctestrun_template": attr.label(
            default = Label(
                "@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_runner.template.xctestrun",
            ),
            allow_single_file = True,
        ),
    },
    outputs = {
        "test_runner_template": "%{name}.sh",
    },
    fragments = ["apple", "objc"],
    doc = """
This rule creates a test runner for iOS tests that uses xctestrun files to run
hosted tests, and uses xctest directly to run logic tests.

You can use this rule directly if you need to override 'device_type' or
'os_version', otherwise you can use the predefined runners:

```
"@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_ordered_runner"
```

or:

```
"@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_random_runner"
```

Depending on if you want random test ordering or not. Set these as the `runner`
attribute on your `ios_unit_test` target:

```bzl
ios_unit_test(
    name = "Tests",
    minimum_os_version = "15.5",
    runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_random_runner",
    deps = [":TestsLib"],
)
```

If you would like this test runner to generate xcresult bundles for your tests,
pass `--test_env=CREATE_XCRESULT_BUNDLE=1`

This rule automatically handles running x86_64 tests on arm64 hosts. The only
exception is that if you want to generate xcresult bundles, the test must have
a test host. This is because of a limitation in Xcode.
""",
)
