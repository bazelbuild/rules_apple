# Test XML Generator

This directory contains tools for generating proper JUnit XML output from iOS and macOS test runs.

## Overview

When running iOS/macOS unit tests with Bazel, the default test output may not always produce proper JUnit XML format that CI systems expect. This tool provides a post-action script that:

1. Parses the test log output from xcodebuild
2. Extracts test results (passes, failures, timing)
3. Generates proper JUnit XML format
4. Writes the XML to the location Bazel expects (`$XML_OUTPUT_FILE`)

## Components

- **`generate_test_xml.py`**: Python script that parses test logs and generates JUnit XML
- **`test_runners.bzl`**: Pre-configured test runners with XML generation enabled
- **`BUILD`**: Bazel build definitions

## Usage

### Option 1: Use Pre-configured Test Runners

The easiest way to use this tool is to use one of the pre-configured test runners:

```python
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")

ios_unit_test(
    name = "MyAppTests",
    minimum_os_version = "15.0",
    deps = [":MyAppTestsLib"],
    runner = "//tools/test_xml_generator:ios_xctestrun_runner_with_xml",
)
```

Available runners:
- `//tools/test_xml_generator:ios_xctestrun_runner_with_xml` - For iOS tests using xcodebuild
- `//tools/test_xml_generator:ios_test_runner_with_xml` - For iOS tests using custom runner
- `//tools/test_xml_generator:macos_test_runner_with_xml` - For macOS tests

### Option 2: Create Your Own Custom Runner

You can create your own test runner with custom configuration:

```python
# In your BUILD file
load(
    "@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_runner.bzl",
    "ios_xctestrun_runner",
)

ios_xctestrun_runner(
    name = "my_custom_ios_runner",
    post_action = "//tools/test_xml_generator:generate_test_xml",
    post_action_determines_exit_code = False,  # Don't fail build if XML generation fails
    # Add other custom configuration here
    device_type = "iPhone 14",
    os_version = "16.0",
)

# Use in your test
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")

ios_unit_test(
    name = "MyAppTests",
    minimum_os_version = "15.0",
    deps = [":MyAppTestsLib"],
    runner = ":my_custom_ios_runner",
)
```

### Option 3: Add Post-Action to Existing Runner

If you already have a custom runner, you can add the post-action:

```python
ios_xctestrun_runner(
    name = "my_existing_runner",
    post_action = "//tools/test_xml_generator:generate_test_xml",
    post_action_determines_exit_code = False,
    # ... your existing configuration ...
)
```

## How It Works

1. **Test Execution**: The test runner executes your tests normally
2. **Log Capture**: Test output is captured to `$TEST_LOG_FILE` (typically in `/tmp`)
3. **Post-Action**: After tests complete, the `generate_test_xml.py` script runs with these environment variables:
   - `TEST_LOG_FILE`: Path to the test log
   - `XML_OUTPUT_FILE`: Path where Bazel expects the XML output
   - `TEST_EXIT_CODE`: Exit code from the test run
   - `TEST_XCRESULT_BUNDLE_PATH`: Path to XCResult bundle (if available)
   - `SIMULATOR_UDID`: Simulator ID (for iOS tests)
4. **XML Generation**: The script parses the log and generates JUnit XML
5. **Output**: XML is written to the correct location for Bazel and CI systems

## Supported Test Formats

The parser supports multiple test output formats:

- **XCTest (Objective-C/Swift)**: Standard XCTest output format
  ```
  Test Case '-[MyTests testExample]' started.
  Test Case '-[MyTests testExample]' passed (0.001 seconds).
  ```

- **Swift Testing (Xcode 16+)**: New Swift Testing framework
  ```
  Test MyTests/testExample started.
  Test MyTests/testExample passed after 0.001 seconds.
  ```

## Output Format

The generated XML follows the JUnit XML format:

```xml
<?xml version="1.0" ?>
<testsuites name="iOS/macOS Tests" tests="10" failures="1" errors="0" time="2.5" timestamp="2024-01-01T12:00:00Z">
  <testsuite name="MyAppTests" tests="10" failures="1" errors="0" time="2.5">
    <testcase classname="MyAppTests" name="testExample" time="0.001"/>
    <testcase classname="MyAppTests" name="testFailure" time="0.002">
      <failure message="XCTAssertEqual failed" type="XCTestFailure">
        MyAppTests.swift:42: XCTAssertEqual failed: ("expected") is not equal to ("actual")
      </failure>
      <system-err>
        Test output and error messages...
      </system-err>
    </testcase>
  </testsuite>
</testsuites>
```

## Troubleshooting

### No test cases found in log output

If you see this warning, it means the parser couldn't find test results in the log. This could be because:

1. Tests didn't run at all (build failure, configuration issue)
2. Test output format is different than expected
3. The log file is empty or corrupted

Check the test log manually to see what format the output is in.

### XML file not created

Make sure:
1. The runner has the post-action configured correctly
2. The `//tools/test_xml_generator:generate_test_xml` target is accessible
3. Check the test output for any error messages from the post-action script

### Tests fail but XML shows all passed

The post-action runs after tests complete but doesn't change the test exit code (unless `post_action_determines_exit_code = True`). The XML should reflect the actual test results from the log.

## Development

To test the XML generator locally:

```bash
# Run tests and generate XML
bazel test //path/to:test --test_output=all

# Check the generated XML
cat bazel-testlogs/path/to/test/test.xml

# Debug with verbose output
TEST_LOG_FILE=/path/to/test.log \
XML_OUTPUT_FILE=/tmp/test.xml \
TEST_EXIT_CODE=0 \
python3 tools/test_xml_generator/generate_test_xml.py
```

## Configuration Options

### post_action_determines_exit_code

By default, this is set to `False`, meaning XML generation failures won't fail your test. This is recommended because you still want to know if your tests failed even if XML generation has issues.

Set to `True` if you want XML generation failures to fail the build:

```python
ios_xctestrun_runner(
    name = "strict_runner",
    post_action = "//tools/test_xml_generator:generate_test_xml",
    post_action_determines_exit_code = True,  # Fail build if XML generation fails
)
```

## CI Integration

The generated XML files work with popular CI systems:

- **Jenkins**: Automatically picks up JUnit XML from test results
- **GitHub Actions**: Use with test reporting actions
- **CircleCI**: Store as test results artifact
- **GitLab CI**: Use with junit report artifacts

Example for GitHub Actions:

```yaml
- name: Run iOS Tests
  run: bazel test //path/to:test --runner=//tools/test_xml_generator:ios_xctestrun_runner_with_xml

- name: Publish Test Results
  uses: EnricoMi/publish-unit-test-result-action@v2
  if: always()
  with:
    files: bazel-testlogs/**/test.xml
```

## Contributing

To extend the parser for additional test formats:

1. Add regex patterns to `TestLogParser` class
2. Update `parse()` method to handle new patterns
3. Test with sample log output
4. Update this documentation

## License

Copyright 2024 The Bazel Authors. Licensed under Apache 2.0.

