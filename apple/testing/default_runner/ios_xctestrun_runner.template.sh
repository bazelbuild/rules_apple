#!/bin/bash
# This script replaces the variables in the templated xctestrun file with the
# the specific paths to the test bundle, and the optionally test host

set -euo pipefail

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  echo "error: Missing \$DEVELOPER_DIR" >&2
  exit 1
fi

# Retrieve the basename of a file or folder with an extension.
basename_without_extension() {
  local filename
  filename=$(basename "$1")
  echo "${filename%.*}"
}

test_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/test_tmp_dir.XXXXXX")"
if [[ -z "${NO_CLEAN:-}" ]]; then
  trap 'rm -rf "${test_tmp_dir}"' EXIT
else
  test_tmp_dir="${TMPDIR:-/tmp}/test_tmp_dir"
  rm -rf "$test_tmp_dir"
  mkdir -p "$test_tmp_dir"
  echo "note: keeping test dir around at: $test_tmp_dir"
fi

test_bundle_path="%(test_bundle_path)s"
test_bundle_name=$(basename_without_extension "$test_bundle_path")

if [[ "$test_bundle_path" == *.xctest ]]; then
  cp -cRL "$test_bundle_path" "$test_tmp_dir"
  # Need to modify permissions as Bazel will set all files to non-writable, and
  # Xcode's test runner requires the files to be writable.
  chmod -R 777 "$test_tmp_dir/$test_bundle_name.xctest"
else
  unzip -qq -d "${test_tmp_dir}" "${test_bundle_path}"
fi

# In case there is no test host, test_host_path will be empty
test_host_path="%(test_host_path)s"
if [[ -n "$test_host_path" ]]; then
  test_host_name=$(basename_without_extension "$test_host_path")

  if [[ "$test_host_path" == *.app ]]; then
    cp -cRL "$test_host_path" "$test_tmp_dir"
    # Need to modify permissions as Bazel will set all files to non-writable,
    # and Xcode's test runner requires the files to be writable.
    chmod -R 777 "$test_tmp_dir/$test_host_name.app"
  else
    unzip -qq -d "${test_tmp_dir}" "${test_host_path}"
    mv "$test_tmp_dir"/Payload/*.app "$test_tmp_dir"
  fi
fi

# Basic XML character escaping for environment variable substitution.
function escape() {
  local escaped=${1//&/&amp;}
  escaped=${escaped//</&lt;}
  escaped=${escaped//>/&gt;}
  escaped=${escaped//'"'/&quot;}
  echo "$escaped"
}

# Add the test environment variables into the xctestrun file to propagate them
# to the test runner
test_env="%(test_env)s"
xctestrun_env=""
for single_test_env in ${test_env//,/ }; do
  IFS="=" read -r key value <<< "$single_test_env"
  xctestrun_env+="<key>$(escape "$key")</key><string>$(escape "$value")</string>"
done

if [[ -n "$test_host_path" ]]; then
  xctestrun_test_host_path="__TESTROOT__/$test_host_name.app"
  xctestrun_test_host_based=true
  # If this is set in the case there is no test host, some tests hang indefinitely
  xctestrun_env+="<key>XCInjectBundleInto</key><string>$(escape "__TESTHOST__/$test_host_name.app/$test_host_name")</string>"
else
  xctestrun_test_host_path="__PLATFORMS__/iPhoneSimulator.platform/Developer/Library/Xcode/Agents/xctest"
  xctestrun_test_host_based=false
fi

sanitizer_dyld_env=""
readonly sanitizer_root="$test_tmp_dir/$test_bundle_name.xctest/Frameworks"
for sanitizer in "$sanitizer_root"/libclang_rt.*.dylib; do
  if [[ -n "$sanitizer_dyld_env" ]]; then
    sanitizer_dyld_env="$sanitizer_dyld_env:"
  fi
  sanitizer_dyld_env="${sanitizer_dyld_env}${sanitizer}"
done

xctestrun_libraries="__PLATFORMS__/iPhoneSimulator.platform/Developer/usr/lib/libXCTestBundleInject.dylib"
if [[ -n "$sanitizer_dyld_env" ]]; then
  xctestrun_libraries="${xctestrun_libraries}:${sanitizer_dyld_env}"
fi

readonly profraw="$test_tmp_dir/coverage.profraw"
readonly xctestrun_file="$test_tmp_dir/tests.xctestrun"
/usr/bin/sed \
  -e "s@BAZEL_INSERT_LIBRARIES@$xctestrun_libraries@g" \
  -e "s@BAZEL_TEST_BUNDLE_PATH@__TESTROOT__/$test_bundle_name.xctest@g" \
  -e "s@BAZEL_TEST_ENVIRONMENT@$xctestrun_env@g" \
  -e "s@BAZEL_TEST_HOST_BASED@$xctestrun_test_host_based@g" \
  -e "s@BAZEL_TEST_HOST_PATH@$xctestrun_test_host_path@g" \
  -e "s@BAZEL_TEST_ORDER_STRING@%(test_order)s@g" \
  -e "s@BAZEL_COVERAGE_PROFRAW@$profraw@g" \
  -e "s@BAZEL_COVERAGE_OUTPUT_DIR@$test_tmp_dir@g" \
  "%(xctestrun_template)s" > "$xctestrun_file"

id="$("./%(simulator_creator.py)s" "%(os_version)s" "%(device_type)s")"
test_exit_code=0
testlog=$(mktemp)

test_file=$(file "$test_tmp_dir/$test_bundle_name.xctest/$test_bundle_name")
intel_simulator_hack=false
if [[ $(arch) == arm64 && "$test_file" != *arm64* ]]; then
  intel_simulator_hack=true
fi

# shellcheck disable=SC2050
if [[ -n "$test_host_path" || -n "${CREATE_XCRESULT_BUNDLE:-}" || "%(test_order)s" == random ]]; then
  if [[ -z "$test_host_path" && "$intel_simulator_hack" == true ]]; then
    echo "error: running x86_64 tests on arm64 macs with CREATE_XCRESULT_BUNDLE or random ordering requires a test host" >&2
    exit 1
  fi

  args=(
    -destination "id=$id" \
    -destination-timeout 15 \
    -xctestrun "$xctestrun_file" \
  )

  readonly result_bundle_path="$TEST_UNDECLARED_OUTPUTS_DIR/tests.xcresult"
  # TEST_UNDECLARED_OUTPUTS_DIR isn't cleaned up with multiple retries of flaky tests
  rm -rf "$result_bundle_path"
  if [[ -n "${CREATE_XCRESULT_BUNDLE:-}" ]]; then
    args+=(-resultBundlePath "$result_bundle_path")
  fi

  xcodebuild test-without-building "${args[@]}" \
    2>&1 | tee -i "$testlog" | (grep -v "One of the two will be used" || true) \
    || test_exit_code=$?
else
  platform_developer_dir="$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer"
  xctest_binary="$platform_developer_dir/Library/Xcode/Agents/xctest"
  test_file=$(file "$test_tmp_dir/$test_bundle_name.xctest/$test_bundle_name")
  if [[ "$intel_simulator_hack" == true ]]; then
    sliced_xctest_binary="$test_tmp_dir/xctest_intel_bin"
    lipo -thin x86_64 -output "$sliced_xctest_binary" "$xctest_binary"
    xctest_binary=$sliced_xctest_binary
  fi

  SIMCTL_CHILD_DYLD_LIBRARY_PATH="$platform_developer_dir/usr/lib" \
    SIMCTL_CHILD_DYLD_FALLBACK_FRAMEWORK_PATH="$platform_developer_dir/Library/Frameworks" \
    SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$sanitizer_dyld_env" \
    SIMCTL_CHILD_LLVM_PROFILE_FILE="$profraw" \
    xcrun simctl \
    spawn \
    "$id" \
    "$xctest_binary" \
    -XCTest All \
    "$test_tmp_dir/$test_bundle_name.xctest" \
    2>&1 | tee -i "$testlog" | (grep -v "One of the two will be used" || true) \
    || test_exit_code=$?
fi

if [[ "$test_exit_code" -ne 0 ]]; then
  echo "error: tests exited with '$test_exit_code'" >&2
  exit "$test_exit_code"
fi

# When tests crash after they have reportedly completed, XCTest marks them as
# a success. These 2 cases are Swift fatalErrors, and C++ exceptions. There
# are likely other cases we can add to this in the future. FB7801959
if grep -q \
  -e "^Fatal error:" \
  -e "^libc++abi.dylib: terminating with uncaught exception" \
  -e "Executed 0 tests, with 0 failures" \
  "$testlog"
then
  echo "error: log contained test false negative" >&2
  exit 1
fi
if [[ "${COVERAGE:-}" -ne 1 ]]; then
  # Normal tests run without coverage
  exit 0
fi

readonly profdata="$test_tmp_dir/coverage.profdata"
xcrun llvm-profdata merge "$profraw" --output "$profdata"

lcov_args=(
  -instr-profile "$profdata"
  -ignore-filename-regex='.*external/.+'
  -path-equivalence="$ROOT,."
)
has_binary=false
IFS=";"
arch=$(uname -m)
for binary in $TEST_BINARIES_FOR_LLVM_COV; do
  if [[ "$has_binary" == false ]]; then
    lcov_args+=("${binary}")
    has_binary=true
    if ! file "$binary" | grep -q "$arch"; then
      arch=x86_64
    fi
  else
    lcov_args+=(-object "${binary}")
  fi

  lcov_args+=("-arch=$arch")
done

readonly error_file="$test_tmp_dir/llvm-cov-error.txt"
llvm_cov_status=0
xcrun llvm-cov \
  export \
  -format lcov \
  "${lcov_args[@]}" \
  @"$COVERAGE_MANIFEST" \
  > "$COVERAGE_OUTPUT_FILE" \
  2> "$error_file" \
  || llvm_cov_status=$?

# Error ourselves if lcov outputs warnings, such as if we misconfigure
# something and the file path of one of the covered files doesn't exist
if [[ -s "$error_file" || "$llvm_cov_status" -ne 0 ]]; then
  echo "error: while exporting coverage report" >&2
  cat "$error_file" >&2
  exit 1
fi

if [[ -n "${COVERAGE_PRODUCE_JSON:-}" ]]; then
  llvm_cov_json_export_status=0
  xcrun llvm-cov \
    export \
    -format text \
    "${lcov_args[@]}" \
    @"$COVERAGE_MANIFEST" \
    > "$TEST_UNDECLARED_OUTPUTS_DIR/coverage.json" \
    2> "$error_file" \
    || llvm_cov_json_export_status=$?
  if [[ -s "$error_file" || "$llvm_cov_json_export_status" -ne 0 ]]; then
    echo "error: while exporting json coverage report" >&2
    cat "$error_file" >&2
    exit 1
  fi
fi
