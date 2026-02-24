"""
An iOS test runner rule that uses xctestrun files to run unit test bundles on
simulators. This rule currently doesn't support UI tests or running on device.
"""

load(
    "@build_bazel_apple_support//xcode:providers.bzl",
    "XcodeVersionInfo",
    "XcodeVersionPropertiesInfo",
)
load(
    "//apple:providers.bzl",
    "AppleDeviceTestRunnerInfo",
    "apple_provider",
)

def _get_template_substitutions(
        *,
        attachment_lifetime,
        clean_up_simulator_action_binary,
        command_line_args,
        create_simulator_action_binary,
        create_xcresult_bundle,
        destination_timeout,
        device_type,
        os_version,
        post_action_binary,
        post_action_determines_exit_code,
        pre_action_binary,
        random,
        reuse_simulator,
        xcodebuild_args,
        xctestrun_template,
        xctrunner_entitlements_template):
    substitutions = {
        "attachment_lifetime": attachment_lifetime,
        "clean_up_simulator_action_binary": clean_up_simulator_action_binary,
        "command_line_args": command_line_args,
        "create_simulator_action_binary": create_simulator_action_binary,
        "create_xcresult_bundle": create_xcresult_bundle,
        "destination_timeout": destination_timeout,
        "device_type": device_type,
        "os_version": os_version,
        "post_action_binary": post_action_binary,
        "post_action_determines_exit_code": post_action_determines_exit_code,
        "pre_action_binary": pre_action_binary,
        "reuse_simulator": reuse_simulator,
        # "ordered" isn't a special string, but anything besides "random" for this field runs in order
        "test_order": "random" if random else "ordered",
        "xcodebuild_args": xcodebuild_args,
        "xctestrun_template": xctestrun_template,
        "xctrunner_entitlements_template": xctrunner_entitlements_template,
    }

    return {"%({})s".format(key): value for key, value in substitutions.items()}

def _get_execution_environment(ctx):
    xcode_version = str(ctx.attr._xcode_config[XcodeVersionInfo].xcode_version())
    if not xcode_version:
        fail("error: No xcode_version in _xcode_config")

    return {"XCODE_VERSION_OVERRIDE": xcode_version}

def _ios_xctestrun_runner_impl(ctx):
    # TODO: Remove this getattr when we drop Bazel 8
    xcode_properties_attr = getattr(apple_common, "XcodeProperties", None) or XcodeVersionPropertiesInfo
    os_version = str(ctx.attr.os_version or ctx.fragments.objc.ios_simulator_version or
                     ctx.attr._xcode_config[xcode_properties_attr].default_ios_sdk_version)

    # TODO: Ideally we would be smarter about picking a device, but we don't know what the current version of Xcode supports
    device_type = ctx.attr.device_type or ctx.fragments.objc.ios_simulator_device or "iPhone 15"

    if not os_version:
        fail("error: os_version must be set on ios_xctestrun_runner, or passed with --ios_simulator_version")
    if not device_type:
        fail("error: device_type must be set on ios_xctestrun_runner, or passed with --ios_simulator_device")

    runfiles = ctx.runfiles(files = [
        ctx.file._xctestrun_template,
        ctx.file._xctrunner_entitlements_template,
    ])
    runfiles = runfiles.merge(ctx.attr.create_simulator_action[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.clean_up_simulator_action[DefaultInfo].default_runfiles)

    default_action_binary = "/usr/bin/true"

    pre_action_binary = default_action_binary
    post_action_binary = default_action_binary

    if ctx.executable.pre_action:
        pre_action_binary = ctx.executable.pre_action.short_path
        runfiles = runfiles.merge(ctx.attr.pre_action[DefaultInfo].default_runfiles)

    post_action_determines_exit_code = False
    if ctx.executable.post_action:
        post_action_binary = ctx.executable.post_action.short_path
        post_action_determines_exit_code = ctx.attr.post_action_determines_exit_code
        runfiles = runfiles.merge(ctx.attr.post_action[DefaultInfo].default_runfiles)

    ctx.actions.expand_template(
        template = ctx.file._test_template,
        output = ctx.outputs.test_runner_template,
        substitutions = _get_template_substitutions(
            attachment_lifetime = ctx.attr.attachment_lifetime,
            clean_up_simulator_action_binary = ctx.executable.clean_up_simulator_action.short_path,
            command_line_args = " ".join(ctx.attr.command_line_args) if ctx.attr.command_line_args else "",
            create_simulator_action_binary = ctx.executable.create_simulator_action.short_path,
            create_xcresult_bundle = "true" if ctx.attr.create_xcresult_bundle else "false",
            destination_timeout = "" if ctx.attr.destination_timeout == 0 else str(ctx.attr.destination_timeout),
            device_type = device_type,
            os_version = os_version,
            post_action_binary = post_action_binary,
            post_action_determines_exit_code = "true" if post_action_determines_exit_code else "false",
            pre_action_binary = pre_action_binary,
            random = ctx.attr.random,
            reuse_simulator = "true" if ctx.attr.reuse_simulator else "false",
            xcodebuild_args = " ".join(ctx.attr.xcodebuild_args) if ctx.attr.xcodebuild_args else "",
            xctestrun_template = ctx.file._xctestrun_template.short_path,
            xctrunner_entitlements_template = ctx.file._xctrunner_entitlements_template.short_path,
        ),
    )

    return [
        apple_provider.make_apple_test_runner_info(
            execution_environment = _get_execution_environment(ctx),
            execution_requirements = {"requires-darwin": ""},
            test_runner_template = ctx.outputs.test_runner_template,
        ),
        AppleDeviceTestRunnerInfo(
            device_type = device_type,
            os_version = os_version,
        ),
        DefaultInfo(runfiles = runfiles),
    ]

ios_xctestrun_runner = rule(
    _ios_xctestrun_runner_impl,
    attrs = {
        "attachment_lifetime": attr.string(
            default = "keepNever",
            doc = """
Attachment lifetime to set in the xctestrun file when running the test bundle - `"keepNever"` (default), `"keepAlways"`
or `"deleteOnSuccess"`. This affects presence of attachments in the XCResult output. This does not force using
`xcodebuild` or an XCTestRun file but the value will be used in that case.
""",
        ),
        "clean_up_simulator_action": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//apple/testing/default_runner:simulator_cleanup"),
            doc = """
A binary that cleans up any simulators created by the `create_simulator_action`. Runs after the `post_action`, regardless of test success or failure.

When executed, the binary will have the following environment variables available to it:

<ul>
<li>`SIMULATOR_UDID`: The UDID of the simulator to clean up. This will be the same UDID produced by the `create_simulator_action` and used to run the tests.</li>
<li>`SIMULATOR_REUSE_SIMULATOR`: Whether to an existing simulator was reused or if a new one was created. The value will be set to "1" if the `reuse_simulator` attribute is true, and unset otherwise. Whether or not this variable is respected should be treated as an implementation detail of the simulator cleanup tool.</li>
</ul>
""",
        ),
        "command_line_args": attr.string_list(
            doc = """
CommandLineArguments to pass to xctestrun file when running the test bundle. This means it
will always use `xcodebuild test-without-building` to run the test bundle.
""",
        ),
        "create_simulator_action": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//apple/testing/default_runner:simulator_creator"),
            doc = """
A binary that produces a UDID for a simulator that matches the given device type and OS version. Runs before the `pre_action`. The UDID will be used to run the tests on the correct simulator. The binary must print only the UDID to stdout.

When executed, the binary will have the following environment variables available to it:

<ul>
<li>`SIMULATOR_DEVICE_TYPE`: The device type of the simulator to create. The supported types correspond to the output of `xcrun simctl list devicetypes`. E.g., iPhone 6, iPad Air. The value will either be the value of the `device_type` attribute, or the `--ios_simulator_device` command-line flag.</li>
<li>`SIMULATOR_OS_VERSION`: The os version of the simulator to create. The supported os versions correspond to the output of `xcrun simctl list runtimes`. ' 'E.g., 11.2, 9.3. The value will either be the value of the `os_version` attribute, or the `--ios_simulator_version` command-line flag.</li>
<li>`SIMULATOR_REUSE_SIMULATOR`: Whether to reuse an existing simulator or create a new one. The value will be set to "1" if the `reuse_simulator` attribute is true, and unset otherwise. Whether or not this variable is respected should be treated as an implementation detail of the simulator creator tool.</li>
</ul>
""",
        ),
        "create_xcresult_bundle": attr.bool(
            default = False,
            doc = """
Force the test runner to always create an XCResult bundle. This means it will
always use `xcodebuild test-without-building` to run the test bundle.
""",
        ),
        "destination_timeout": attr.int(
            doc = "Use the specified timeout when searching for a destination device. The default is 30 seconds.",
        ),
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
        "post_action": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A binary to run following test execution. Runs after testing but before test result handling and coverage processing. Sets the `$TEST_EXIT_CODE`, `$TEST_LOG_FILE`, and `$SIMULATOR_UDID` environment variables, the `$TEST_XCRESULT_BUNDLE_PATH` environment variable if the test run produces an XCResult bundle, and any other variables available to the test runner.
""",
        ),
        "post_action_determines_exit_code": attr.bool(
            default = False,
            doc = """
When true, the exit code of the test run will be set to the exit code of the `post_action`. This is useful for tests that need to fail the test run based on their own criteria.
""",
        ),
        "pre_action": attr.label(
            cfg = "exec",
            executable = True,
            doc = """
A binary to run prior to test execution. Runs after simulator creation. Sets the `$SIMULATOR_UDID` environment variable, in addition to any other variables available to the test runner.
""",
        ),
        "random": attr.bool(
            default = False,
            doc = """
Whether to run the tests in random order to identify unintended state
dependencies.
""",
        ),
        "reuse_simulator": attr.bool(
            default = True,
            doc = """
Toggle simulator reuse. The default behavior is to reuse an existing device of the same type and OS version. When disabled, a new simulator is created before testing starts and shutdown when the runner completes.
""",
        ),
        "xcodebuild_args": attr.string_list(
            doc = """
Arguments to pass to `xcodebuild` when running the test bundle. This means it
will always use `xcodebuild test-without-building` to run the test bundle.
""",
        ),
        "_test_template": attr.label(
            default = Label(
                "//apple/testing/default_runner:ios_xctestrun_runner.template.sh",
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
                "//apple/testing/default_runner:ios_xctestrun_runner.template.xctestrun",
            ),
            allow_single_file = True,
        ),
        "_xctrunner_entitlements_template": attr.label(
            default = Label(
                "//apple/testing/default_runner:xctrunner_entitlements.template.plist",
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
pass `--test_env=CREATE_XCRESULT_BUNDLE=1`. It is preferable to use the
`create_xcresult_bundle` on the test runner itself instead of this parameter.

This rule automatically handles running x86_64 tests on arm64 hosts. The only
exception is that if you want to generate xcresult bundles or run tests in
random order, the test must have a test host. This is because of a limitation
in Xcode.
""",
)
