# Apple testing overview

## Test rules architecture

The test rules (`ios_unit_test`, `ios_ui_test`, etc.) have 3 main
responsibilities to fulfill:

1. Link the test code coming in from `deps` dependencies. This is provided
   through an `apple_binary` target.
1. Package the binary and required resources into an `.xctest` bundle. This is
   done through an internal target.
1. Provide a mechanism through which the different kinds of tests can be run.
   This is provided through platform-independent test rules (`apple_unit_test`
   and `apple_ui_test`).

Macros are used to encapsulate these various requirements and artifacts into a
single "rule" that you can call in your BUILD file. These macros are specific
to a particular platform and test-type pair (e.g., `ios_unit_test`). The most
common use case will be to use these rules and not the internal targets
specifically.

The mechanism through which the tests are run is specified through the `runner`
attribute as a target of a rule that provides an `AppleTestRunner` provider.
This provider must contain the following fields, which are in turn used by the
`apple_unit_test` and `apple_ui_test` rules to correctly configure the test
execution:

* `test_runner_template`: Template file that contains the specific mechanism
  with which the tests will be run. The `apple_ui_test` and `apple_unit_test`
  rules will substitute the following values:
  * `%(test_host_path)s`:   Path to the app being tested.
  * `%(test_bundle_path)s`: Path to the test bundle that contains the tests.
  * `%(test_type)s`:        The test type, whether it is unit or UI.
* `execution_requirements`: Dictionary to configure the machines in which to run
  the tests. Usually empty (i.e. `{}`).
* `test_environment`: Dictionary with the environment variables required for the
  test.

By default, these test rules use the
`@build_bazel_rules_apple//apple/testing/default_runner:ios_default_runner`
runner target, which in turn is a target based on the `ios_sample_test_runner`
rule. This test runner is very basic and will only be able to run logic based
tests, i.e. tests that do not rely on a test host. We are currently working on a
more complete test runner, but there is yet no timeline on when it may be
released.

When using the test rules with [Tulsi](https://github.com/bazelbuild/tulsi), the
tests are run with Xcode as the test runner. The Tulsi generated project will
make sure that the files are correctly generated and located so that Xcode can
run the tests either in a simulator or a device. The `runner` does not affect
how the Tulsi generated project runs the tests.

## Examples

Minimal example:

```python
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")

objc_library(
    name = "TestsLib",
    srcs = glob([
        "Tests/**/*.h",
        "Tests/**/*.m",
    ]),
)

# Links code from "deps" into an bundle binary that contains the tests.
ios_unit_test(
    name = "Tests",
    bundle_id = "com.example.app.tests",
    infoplists = [":Info.plist"],
    deps = [":TestsLib"],
)
```

See the [examples](https://github.com/bazelbuild/rules_apple/tree/master/examples)
directory for sample applications.
