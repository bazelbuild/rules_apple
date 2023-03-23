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
if [[ -n "$test_env" ]]; then
  test_env="$test_env,TEST_SRCDIR=$TEST_SRCDIR,TEST_UNDECLARED_OUTPUTS_DIR=$TEST_UNDECLARED_OUTPUTS_DIR"
else
  test_env="TEST_SRCDIR=$TEST_SRCDIR,TEST_UNDECLARED_OUTPUTS_DIR=$TEST_UNDECLARED_OUTPUTS_DIR"
fi

passthrough_env=()
xctestrun_env=""
saved_IFS=$IFS
IFS=","
for test_env_key_value in ${test_env}; do
  IFS="=" read -r key value <<< "$test_env_key_value"
  xctestrun_env+="<key>$(escape "$key")</key><string>$(escape "$value")</string>"
  passthrough_env+=("SIMCTL_CHILD_$key=$value")
done
IFS=$saved_IFS

xcrun_target_app_path=""
xcrun_is_xctrunner_hosted_bundle="false"
xcrun_is_ui_test_bundle="false"
test_type="%(test_type)s"
if [[ -n "$test_host_path" ]]; then
  xctestrun_test_host_path="__TESTROOT__/$test_host_name.app"
  xctestrun_test_host_based=true
  # If this is set in the case there is no test host, some tests hang indefinitely
  xctestrun_env+="<key>XCInjectBundleInto</key><string>$(escape "__TESTHOST__/$test_host_name.app/$test_host_name")</string>"

  if [[ "$test_type" = "XCUITEST" ]]; then
    xcrun_is_xctrunner_hosted_bundle="true"
    xcrun_is_ui_test_bundle="true"
    xcrun_target_app_path="$xctestrun_test_host_path"
    # If ui testing is enabled we need to copy out the XCTRunner app, update its info.plist accordingly and finally
    # copy over the needed frameworks to enable ui testing
    readonly runner_app_name="XCTRunner"
    readonly runner_app="$runner_app_name.app"
    readonly runner_app_destination="$test_tmp_dir/$runner_app"
    libraries_path="$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/Library"
    cp -R "$libraries_path/Xcode/Agents/XCTRunner.app" "$runner_app_destination"
    chmod -R 777 "$runner_app_destination"
    xctestrun_test_host_path="__TESTROOT__/$runner_app"

    /usr/bin/sed \
      -e "s@WRAPPEDPRODUCTNAME@$runner_app_name@g"\
      -e "s@WRAPPEDPRODUCTBUNDLEIDENTIFIER@com.apple.test.$runner_app_name@g"\
      -i "" \
      "$runner_app_destination/Info.plist"

    readonly runner_app_frameworks_destination="$runner_app_destination/Frameworks"
    mkdir -p "$runner_app_frameworks_destination"
    cp -R "$libraries_path/Frameworks/XCTest.framework" "$runner_app_frameworks_destination/XCTest.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCTestCore.framework" "$runner_app_frameworks_destination/XCTestCore.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCUIAutomation.framework" "$runner_app_frameworks_destination/XCUIAutomation.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCTAutomationSupport.framework" "$runner_app_frameworks_destination/XCTAutomationSupport.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCUnit.framework" "$runner_app_frameworks_destination/XCUnit.framework"
  fi
else
  xctestrun_test_host_path="__PLATFORMS__/iPhoneSimulator.platform/Developer/Library/Xcode/Agents/xctest"
  xctestrun_test_host_based=false
fi

sanitizer_dyld_env=""
readonly sanitizer_root="$test_tmp_dir/$test_bundle_name.xctest/Frameworks"
for sanitizer in "$sanitizer_root"/libclang_rt.*.dylib; do
  [[ -e "$sanitizer" ]] || continue

  if [[ -n "$sanitizer_dyld_env" ]]; then
    sanitizer_dyld_env="$sanitizer_dyld_env:"
  fi
  sanitizer_dyld_env="${sanitizer_dyld_env}${sanitizer}"
done

xctestrun_libraries="__PLATFORMS__/iPhoneSimulator.platform/Developer/usr/lib/libXCTestBundleInject.dylib"
if [[ -n "$sanitizer_dyld_env" ]]; then
  xctestrun_libraries="${xctestrun_libraries}:${sanitizer_dyld_env}"
fi

TEST_FILTER="%(test_filter)s"
xctestrun_skip_test_section=""
xctestrun_only_test_section=""

# Use the 'TESTBRIDGE_TEST_ONLY' environment variable set by Bazel's
# '--test_filter' flag to set the xctestrun's skip/only parameters.
#
# Any test prefixed with '-' will be passed to 'SkipTestIdentifiers'. Otherwise
# the tests is passed to 'OnlyTestIdentifiers',
if [[ -n "${TESTBRIDGE_TEST_ONLY:-}" || -n "${TEST_FILTER:-}" ]]; then
  if [[ -n "${TESTBRIDGE_TEST_ONLY:-}" && -n "${TEST_FILTER:-}" ]]; then
    ALL_TESTS="$TESTBRIDGE_TEST_ONLY,$TEST_FILTER"
  elif [[ -n "${TESTBRIDGE_TEST_ONLY:-}" ]]; then
    ALL_TESTS="$TESTBRIDGE_TEST_ONLY"
  else
    ALL_TESTS="$TEST_FILTER"
  fi

  saved_IFS=$IFS
  IFS=","; for TEST in $ALL_TESTS; do
    if [[ $TEST == -* ]]; then
      if [[ -n "${SKIP_TESTS:-}" ]]; then
        SKIP_TESTS+=",${TEST:1}"
      else
        SKIP_TESTS="${TEST:1}"
      fi
    else
      if [[ -n "${ONLY_TESTS:-}" ]]; then
          ONLY_TESTS+=",$TEST"
      else
          ONLY_TESTS="$TEST"
      fi
    fi
  done

  IFS=$saved_IFS

  if [[ -n "${SKIP_TESTS:-}" ]]; then
    xctestrun_skip_test_section="\n"
    for skip_test in ${SKIP_TESTS//,/ }; do
      xctestrun_skip_test_section+="      <string>$skip_test</string>\n"
    done
    xctestrun_skip_test_section="    <key>SkipTestIdentifiers</key>\n    <array>$xctestrun_skip_test_section    </array>"
  fi

  if [[ -n "${ONLY_TESTS:-}" ]]; then
    xctestrun_only_test_section="\n"
    for only_test in ${ONLY_TESTS//,/ }; do
      xctestrun_only_test_section+="      <string>$only_test</string>\n"
    done
    xctestrun_only_test_section="    <key>OnlyTestIdentifiers</key>\n    <array>$xctestrun_only_test_section    </array>"
  fi
fi

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

simulator_id="$("./%(simulator_creator.py)s" \
  "${simulator_creator_args[@]}"
)"

test_exit_code=0
readonly testlog=$test_tmp_dir/test.log

test_file=$(file "$test_tmp_dir/$test_bundle_name.xctest/$test_bundle_name")
intel_simulator_hack=false
if [[ $(arch) == arm64 && "$test_file" != *arm64* ]]; then
  intel_simulator_hack=true
fi

should_use_xcodebuild=false
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
if [[ -n "$xctestrun_skip_test_section" || -n "$xctestrun_only_test_section" ]]; then
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
    exit 1
  fi

  readonly xctestrun_file="$test_tmp_dir/tests.xctestrun"
  /usr/bin/sed \
    -e "s@BAZEL_INSERT_LIBRARIES@$xctestrun_libraries@g" \
    -e "s@BAZEL_TEST_BUNDLE_PATH@__TESTROOT__/$test_bundle_name.xctest@g" \
    -e "s@BAZEL_TEST_ENVIRONMENT@$xctestrun_env@g" \
    -e "s@BAZEL_TEST_HOST_BASED@$xctestrun_test_host_based@g" \
    -e "s@BAZEL_TEST_HOST_PATH@$xctestrun_test_host_path@g" \
    -e "s@BAZEL_TEST_PRODUCT_MODULE_NAME@${test_bundle_name//-/_}@g" \
    -e "s@BAZEL_IS_XCTRUNNER_HOSTED_BUNDLE@$xcrun_is_xctrunner_hosted_bundle@g" \
    -e "s@BAZEL_IS_UI_TEST_BUNDLE@$xcrun_is_ui_test_bundle@g" \
    -e "s@BAZEL_TARGET_APP_PATH@$xcrun_target_app_path@g" \
    -e "s@BAZEL_TEST_ORDER_STRING@%(test_order)s@g" \
    -e "s@BAZEL_COVERAGE_PROFRAW@$profraw@g" \
    -e "s@BAZEL_COVERAGE_OUTPUT_DIR@$test_tmp_dir@g" \
    -e "s@BAZEL_SKIP_TEST_SECTION@$xctestrun_skip_test_section@g" \
    -e "s@BAZEL_ONLY_TEST_SECTION@$xctestrun_only_test_section@g" \
    "%(xctestrun_template)s" > "$xctestrun_file"

  args=(
    -destination "id=$simulator_id" \
    -destination-timeout 15 \
    -xctestrun "$xctestrun_file" \
  )

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

if grep -q -e "Executed 0 tests, with 0 failures" "$testlog"; then
  echo "error: no tests were executed, is the test bundle empty?" >&2
  exit 1
fi

# When tests crash after they have reportedly completed, XCTest marks them as
# a success. These 2 cases are Swift fatalErrors, and C++ exceptions. There
# are likely other cases we can add to this in the future. FB7801959
if grep -q \
  -e "^Fatal error:" \
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

readonly profdata="$test_tmp_dir/coverage.profdata"
xcrun llvm-profdata merge "$profraw" --output "$profdata"

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
