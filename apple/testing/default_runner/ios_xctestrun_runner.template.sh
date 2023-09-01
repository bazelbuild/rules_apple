#!/bin/bash
# This script replaces the variables in the templated xctestrun file with the
# the specific paths to the test bundle, and the optionally test host

set -euo pipefail

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  echo "error: Missing \$DEVELOPER_DIR" >&2
  exit 1
fi

if [[ -n "${DEBUG_XCTESTRUNNER:-}" ]]; then
  set -x
fi

create_xcresult_bundle="%(create_xcresult_bundle)s"
if [[ -n "${CREATE_XCRESULT_BUNDLE:-}" ]]; then
  create_xcresult_bundle=true
fi

custom_xcodebuild_args=(%(xcodebuild_args)s)
simulator_name=""
device_id=""
command_line_args=(%(command_line_args)s)
while [[ $# -gt 0 ]]; do
  arg="$1"
  case $arg in
    --simulator_name=*)
      simulator_name="${arg##*=}"
      ;;
    --xcodebuild_args=*)
      xcodebuild_arg="${arg#--xcodebuild_args=}" # Strip "--xcodebuild_args=" prefix
      custom_xcodebuild_args+=("$xcodebuild_arg")
      ;;
    --destination=platform=iOS,id=*)
      device_id="${arg##*=}"
      ;;
    --command_line_args=*)
      command_line_args+=("${arg##*=}")
      ;;
    *)
      echo "error: Unsupported argument '${arg}'" >&2
      exit 1
      ;;
  esac
  shift
done

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

build_for_device=false
test_execution_platform="iPhoneSimulator.platform"
if [[ -n "$device_id" ]]; then
  test_execution_platform="iPhoneOS.platform"
  build_for_device=true
fi

# In case there is no test host, test_host_path will be empty
test_host_path="%(test_host_path)s"
test_host_name=""
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
    # When extracting an ipa file we don't know the name of the app bundle
    test_tmp_dir_test_host_path=$(find "$test_tmp_dir" -name "*.app" -type d -maxdepth 1 -mindepth 1 -print -quit)
    test_host_name=$(basename_without_extension "$test_tmp_dir_test_host_path")
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
if [[ -n "$test_env" ]]; then
  test_env="$test_env,TEST_SRCDIR=$TEST_SRCDIR,TEST_UNDECLARED_OUTPUTS_DIR=$TEST_UNDECLARED_OUTPUTS_DIR"
else
  test_env="TEST_SRCDIR=$TEST_SRCDIR,TEST_UNDECLARED_OUTPUTS_DIR=$TEST_UNDECLARED_OUTPUTS_DIR"
fi

test_type="%(test_type)s"

readonly profraw="$test_tmp_dir/coverage.profraw"

simulator_creator_args=(
  "%(os_version)s" \
  "%(device_type)s" \
  --name "$simulator_name"
)

reuse_simulator=%(reuse_simulator)s
if [[ "$reuse_simulator" == true ]]; then
  simulator_creator_args+=(--reuse-simulator)
else
  simulator_creator_args+=(--no-reuse-simulator)
fi

simulator_id="unused"
if [[ "$build_for_device" == false ]]; then
  simulator_id="$("./%(simulator_creator.py)s" \
    "${simulator_creator_args[@]}"
  )"
fi

test_exit_code=0
readonly testlog=$test_tmp_dir/test.log

test_file=$(file "$test_tmp_dir/$test_bundle_name.xctest/$test_bundle_name")
intel_simulator_hack=false
if [[ $(arch) == arm64 && "$test_file" != *arm64* ]]; then
  intel_simulator_hack=true
fi

should_use_xcodebuild=false
if [[ "$build_for_device" == true  ]]; then
  echo "note: Using 'xcodebuild' because build for device was requested"
  should_use_xcodebuild=true
fi
if [[ -n "$test_host_path" ]]; then
  echo "note: Using 'xcodebuild' because test host was provided"
  should_use_xcodebuild=true
fi
# shellcheck disable=SC2050
if [[ "%(test_order)s" == random ]]; then
  echo "note: Using 'xcodebuild' because random test order was requested"
  should_use_xcodebuild=true
fi
if [[ "$create_xcresult_bundle" == true ]]; then
  echo "note: Using 'xcodebuild' because XCResult bundle was requested"
  should_use_xcodebuild=true
fi
if [[ -n "${command_line_args:-}" ]]; then
  echo "note: Using 'xcodebuild' because '--command_line_args' was provided"
  should_use_xcodebuild=true
fi
TEST_FILTER="%(test_filter)s"
if [[ -n "${TESTBRIDGE_TEST_ONLY:-}" || -n "${TEST_FILTER:-}" ]]; then
  echo "note: Using 'xcodebuild' because test filter was provided"
  should_use_xcodebuild=true
fi
if (( ${#custom_xcodebuild_args[@]} )); then
  echo "note: Using 'xcodebuild' because '--xcodebuild_args' was provided"
  should_use_xcodebuild=true
fi

if [[ "$should_use_xcodebuild" == true ]]; then
  if [[ -z "$test_host_path" && "$intel_simulator_hack" == true ]]; then
    echo "error: running x86_64 tests on arm64 macs using 'xcodebuild' requires a test host" >&2
    echo "error: '$test_file'" >&2
    exit 1
  fi

  xctestrun_command_line_args=""
  if [[ -n "${command_line_args:-}" ]]; then
    xctestrun_command_line_args="${command_line_args[@]}"
  fi

  readonly xctestrun_file="$test_tmp_dir/tests.xctestrun"
  test_env="$test_env" \
    TEST_FILTER="$TEST_FILTER" \
    command_line_args="$xctestrun_command_line_args" \
    ./%(xctestrun_creator.sh)s \
    "%(test_bundle_path)s" \
    "$test_bundle_name" \
    "$test_host_path" \
    "$test_host_name" \
    "$test_type" \
    "$build_for_device" \
    "$test_execution_platform" \
    "$xctestrun_file" \
    "$test_tmp_dir"

  args=(
    -destination-timeout 15 \
    -xctestrun "$xctestrun_file" \
  )

  if [[ "$build_for_device" == true ]]; then
    args+=(-destination "platform=iOS,id=$device_id")
  else
    args+=(-destination "id=$simulator_id")
  fi

  readonly result_bundle_path="$TEST_UNDECLARED_OUTPUTS_DIR/tests.xcresult"
  # TEST_UNDECLARED_OUTPUTS_DIR isn't cleaned up with multiple retries of flaky tests
  rm -rf "$result_bundle_path"
  if [[ "$create_xcresult_bundle" == true ]]; then
    args+=(-resultBundlePath "$result_bundle_path")
  fi

  if (( ${#custom_xcodebuild_args[@]} )); then
    args+=("${custom_xcodebuild_args[@]}")
  fi

  xcodebuild test-without-building "${args[@]}" \
    2>&1 | tee -i "$testlog" | (grep -v "One of the two will be used" || true) \
    || test_exit_code=$?
else
  platform_developer_dir="$(xcode-select -p)/Platforms/$test_execution_platform/Developer"
  xctest_binary="$platform_developer_dir/Library/Xcode/Agents/xctest"
  test_file=$(file "$test_tmp_dir/$test_bundle_name.xctest/$test_bundle_name")
  if [[ "$intel_simulator_hack" == true ]]; then
    sliced_xctest_binary="$test_tmp_dir/xctest_intel_bin"
    lipo -thin x86_64 -output "$sliced_xctest_binary" "$xctest_binary"
    xctest_binary=$sliced_xctest_binary
  fi

  passthrough_env=()
  saved_IFS=$IFS
  IFS=","
  for test_env_key_value in ${test_env}; do
    IFS="=" read -r key value <<< "$test_env_key_value"
    passthrough_env+=("SIMCTL_CHILD_$key=$value")
  done
  IFS=$saved_IFS

  sanitizer_dyld_env=""
  readonly sanitizer_root="$test_tmp_dir/$test_bundle_name.xctest/Frameworks"
  for sanitizer in "$sanitizer_root"/libclang_rt.*.dylib; do
    [[ -e "$sanitizer" ]] || continue

    if [[ -n "$sanitizer_dyld_env" ]]; then
      sanitizer_dyld_env="$sanitizer_dyld_env:"
    fi
    sanitizer_dyld_env="${sanitizer_dyld_env}${sanitizer}"
  done

  SIMCTL_CHILD_DYLD_LIBRARY_PATH="$platform_developer_dir/usr/lib" \
    SIMCTL_CHILD_DYLD_FALLBACK_FRAMEWORK_PATH="$platform_developer_dir/Library/Frameworks" \
    SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$sanitizer_dyld_env" \
    SIMCTL_CHILD_LLVM_PROFILE_FILE="$profraw" \
    env "${passthrough_env[@]}" \
    xcrun simctl \
    spawn \
    "$simulator_id" \
    "$xctest_binary" \
    -XCTest All \
    "$test_tmp_dir/$test_bundle_name.xctest" \
    2>&1 | tee -i "$testlog" | (grep -v "One of the two will be used" || true) \
    || test_exit_code=$?
fi

if [[ "$reuse_simulator" == false ]]; then
  xcrun simctl shutdown "$simulator_id"
  xcrun simctl delete "$simulator_id"
fi

if [[ "$test_exit_code" -ne 0 ]]; then
  echo "error: tests exited with '$test_exit_code'" >&2
  exit "$test_exit_code"
fi

# Assume the final 'Executed N tests' or 'Executed 1 test' is the
# total execution count for the test bundle.
test_target_execution_count=$(grep -e "Executed [[:digit:]]\{1,\} tests*," "$testlog" | tail -n1)
if echo "$test_target_execution_count" | grep -q -e "Executed 0 tests, with 0 failures"; then
  echo "error: no tests were executed, is the test bundle empty?" >&2
  exit 1
fi

# When tests crash after they have reportedly completed, XCTest marks them as
# a success. These 2 cases are Swift fatalErrors, and C++ exceptions. There
# are likely other cases we can add to this in the future. FB7801959
if grep -q \
  -e "^Fatal error:" \
  -e "^.*:[0-9]\+:\sFatal error:" \
  -e "^libc++abi.dylib: terminating with uncaught exception" \
  "$testlog"
then
  echo "error: log contained test false negative" >&2
  exit 1
fi

if [[ "${COVERAGE:-}" -ne 1 ]]; then
  # Normal tests run without coverage
  exit 0
fi

profdata="$test_tmp_dir/$simulator_id/Coverage.profdata"
if [[ "$should_use_xcodebuild" == false ]]; then
  profdata="$test_tmp_dir/coverage.profdata"
  xcrun llvm-profdata merge "$profraw" --output "$profdata"
fi

lcov_args=(
  -instr-profile "$profdata"
  -ignore-filename-regex='.*external/.+'
  -path-equivalence=".,$PWD"
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

llvm_coverage_manifest="$COVERAGE_MANIFEST"
readonly provided_coverage_manifest="%(test_coverage_manifest)s"
if [[ -s "${provided_coverage_manifest:-}" ]]; then
  llvm_coverage_manifest="$provided_coverage_manifest"
fi

readonly error_file="$test_tmp_dir/llvm-cov-error.txt"
llvm_cov_status=0
xcrun llvm-cov \
  export \
  -format lcov \
  "${lcov_args[@]}" \
  @"$llvm_coverage_manifest" \
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
    @"$llvm_coverage_manifest" \
    > "$TEST_UNDECLARED_OUTPUTS_DIR/coverage.json" \
    2> "$error_file" \
    || llvm_cov_json_export_status=$?
  if [[ -s "$error_file" || "$llvm_cov_json_export_status" -ne 0 ]]; then
    echo "error: while exporting json coverage report" >&2
    cat "$error_file" >&2
    exit 1
  fi
fi
