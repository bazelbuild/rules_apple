#!/bin/bash
# This script replaces the variables in the templated xctestrun file with the
# the specific paths to the test bundle, and the optionally test host

set -euo pipefail

if [[ -n "${DEBUG_XCTESTRUN_CREATOR:-}" ]]; then
  set -x
fi

xctrunner_entitlements_template="%(xctrunner_entitlements_template)s"
test_order="%(test_order)s"
xctestrun_template="%(xctestrun_template)s"

readonly test_bundle_path="$1"
readonly test_bundle_name="$2"
readonly test_host_path="$3"
readonly test_host_name="$4"
readonly test_type="$5"
readonly build_for_device="$6"
readonly test_execution_platform="$7"
readonly xctestrun_file="$8"
readonly test_tmp_dir="$9"

# Basic XML character escaping for environment variable substitution.
function escape() {
  local escaped=${1//&/&amp;}
  escaped=${escaped//</&lt;}
  escaped=${escaped//>/&gt;}
  escaped=${escaped//'"'/&quot;}
  echo "$escaped"
}

# Gather command line arguments for `CommandLineArguments` in the xctestrun file
xctestrun_cmd_line_args_section=""
if [[ -n "${command_line_args:-}" ]]; then
  xctestrun_cmd_line_args_section="\n"
  saved_IFS=$IFS
  IFS=","
  for cmd_line_arg in ${command_line_args[@]}; do
    xctestrun_cmd_line_args_section+="      <string>$cmd_line_arg</string>\n"
  done
  IFS=$saved_IFS
  xctestrun_cmd_line_args_section="    <key>CommandLineArguments</key>\n    <array>$xctestrun_cmd_line_args_section    </array>"
fi

xctestrun_env=""
saved_IFS=$IFS
IFS=","
for test_env_key_value in ${test_env}; do
  IFS="=" read -r key value <<< "$test_env_key_value"
  xctestrun_env+="<key>$(escape "$key")</key><string>$(escape "$value")</string>"
done
IFS=$saved_IFS

xcrun_target_app_path=""
xcrun_test_host_bundle_identifier=""
xcrun_test_bundle_path="__TESTROOT__/$test_bundle_name.xctest"
xcrun_is_xctrunner_hosted_bundle="false"
xcrun_is_ui_test_bundle="false"
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
    readonly runner_app_name="$test_bundle_name-Runner"
    readonly runner_app="$runner_app_name.app"
    readonly runner_app_destination="$test_tmp_dir/$runner_app"
    developer_path="$(xcode-select -p)/Platforms/$test_execution_platform/Developer"
    libraries_path="$developer_path/Library"
    cp -R "$libraries_path/Xcode/Agents/XCTRunner.app" "$runner_app_destination"
    chmod -R 777 "$runner_app_destination"
    xctestrun_test_host_path="__TESTROOT__/$runner_app"
    xcrun_test_host_bundle_identifier="com.apple.test.$runner_app_name"
    plugins_path="$test_tmp_dir/$runner_app/PlugIns"
    mkdir -p "$plugins_path"
    mv "$test_tmp_dir/$test_bundle_name.xctest" "$plugins_path"
    mkdir -p "$plugins_path/$test_bundle_name.xctest/Frameworks"
    # We need this dylib for 14.x OSes. This intentionally doesn't use `test_execution_platform`
    # since this file isn't present in the `iPhoneSimulator.platform`.
    # No longer necessary starting in Xcode 15 - hence the `-f` file existence check
    libswift_concurrency_path="$(xcode-select -p)/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/usr/lib/swift/libswift_Concurrency.dylib"
    if [[ -f "$libswift_concurrency_path" ]]; then
      cp "$libswift_concurrency_path" "$plugins_path/$test_bundle_name.xctest/Frameworks/libswift_Concurrency.dylib"
    fi
    xcrun_test_bundle_path="__TESTHOST__/PlugIns/$test_bundle_name.xctest"

    /usr/bin/sed \
      -e "s@WRAPPEDPRODUCTNAME@XCTRunner@g"\
      -e "s@WRAPPEDPRODUCTBUNDLEIDENTIFIER@$xcrun_test_host_bundle_identifier@g"\
      -i "" \
      "$runner_app_destination/Info.plist"

    readonly runner_app_frameworks_destination="$runner_app_destination/Frameworks"
    mkdir -p "$runner_app_frameworks_destination"
    cp -R "$libraries_path/Frameworks/XCTest.framework" "$runner_app_frameworks_destination/XCTest.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCTestCore.framework" "$runner_app_frameworks_destination/XCTestCore.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCUIAutomation.framework" "$runner_app_frameworks_destination/XCUIAutomation.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCTAutomationSupport.framework" "$runner_app_frameworks_destination/XCTAutomationSupport.framework"
    cp -R "$libraries_path/PrivateFrameworks/XCUnit.framework" "$runner_app_frameworks_destination/XCUnit.framework"
    cp "$developer_path/usr/lib/libXCTestSwiftSupport.dylib" "$runner_app_frameworks_destination/libXCTestSwiftSupport.dylib"
    cp "$developer_path/usr/lib/libXCTestBundleInject.dylib" "$runner_app_frameworks_destination/libXCTestBundleInject.dylib"
    # Added in Xcode 14.3
    xctestsupport_framework_path="$libraries_path/PrivateFrameworks/XCTestSupport.framework"
    if [[ -d "$xctestsupport_framework_path" ]]; then
      cp -R "$xctestsupport_framework_path" "$runner_app_frameworks_destination/XCTestSupport.framework"
    fi
    if [[ "$build_for_device" == true ]]; then
      # XCTRunner is multi-archs. When launching XCTRunner on arm64e device, it
      # will be launched as arm64e process by default. If the test bundle is arm64
      # bundle, the XCTRunner which hosts the test bundle will fail to be
      # launched. So removing the arm64e arch from XCTRunner can resolve this
      # case.
      /usr/bin/lipo "$test_tmp_dir/$runner_app/XCTRunner" -remove arm64e -output "$test_tmp_dir/$runner_app/XCTRunner"
    fi
    test_host_mobileprovision_path="$test_tmp_dir/$test_host_name.app/embedded.mobileprovision"
    # Only engage signing workflow if the test host is signed
    if [[ -f "$test_host_mobileprovision_path" ]]; then
      cp "$test_host_mobileprovision_path" "$test_tmp_dir/$runner_app/embedded.mobileprovision"
      xctrunner_entitlements="$test_tmp_dir/$runner_app/RunnerEntitlements.plist"
      test_host_binary_path="$test_tmp_dir/$test_host_name.app/$test_host_name"
      codesigning_team_identifier=$(codesign -dvv "$test_host_binary_path"  2>&1 >/dev/null | /usr/bin/sed -n  -E 's/TeamIdentifier=(.*)/\1/p')
      codesigning_authority=$(codesign -dvv "$test_host_binary_path"  2>&1 >/dev/null | /usr/bin/sed -n  -E 's/^Authority=(.*)/\1/p'| head -n 1)
      /usr/bin/sed \
        -e "s@BAZEL_CODESIGNING_TEAM_IDENTIFIER@$codesigning_team_identifier@g" \
        -e "s@BAZEL_TEST_HOST_BUNDLE_IDENTIFIER@$xcrun_test_host_bundle_identifier@g" \
        "$xctrunner_entitlements_template" > "$xctrunner_entitlements"
      codesign -f \
        --entitlements "$xctrunner_entitlements" \
        --timestamp=none -s "$codesigning_authority" \
        "$plugins_path/$test_bundle_name.xctest"
      find "$test_tmp_dir/$runner_app/Frameworks" \
        -type d \
        -name "*.framework" \
        -exec codesign -f --timestamp=none -s "$codesigning_authority" --entitlements "$xctrunner_entitlements" {} \;
      find "$test_tmp_dir/$runner_app/Frameworks" \
        -type f \
        -name "*.dylib" \
        -exec codesign -f --timestamp=none -s "$codesigning_authority" --entitlements "$xctrunner_entitlements" {} \;
      codesign -f \
        --entitlements "$xctrunner_entitlements" \
        --timestamp=none \
        -s "$codesigning_authority" \
        "$test_tmp_dir/$runner_app"
    fi
  fi
else
  xctestrun_test_host_path="__PLATFORMS__/$test_execution_platform/Developer/Library/Xcode/Agents/xctest"
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

xctestrun_libraries="__PLATFORMS__/$test_execution_platform/Developer/usr/lib/libXCTestBundleInject.dylib"
if [[ -n "$sanitizer_dyld_env" ]]; then
  xctestrun_libraries="${xctestrun_libraries}:${sanitizer_dyld_env}"
fi

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

test_file=$(file "$test_tmp_dir/$test_bundle_name.xctest/$test_bundle_name")
architecture="arm64"
if [[ $(arch) == arm64 && "$test_file" != *arm64* ]]; then
  architecture="x86_64"
fi

/usr/bin/sed \
  -e "s@BAZEL_INSERT_LIBRARIES@$xctestrun_libraries@g" \
  -e "s@BAZEL_TEST_BUNDLE_PATH@$xcrun_test_bundle_path@g" \
  -e "s@BAZEL_TEST_ENVIRONMENT@$xctestrun_env@g" \
  -e "s@BAZEL_TEST_HOST_BASED@$xctestrun_test_host_based@g" \
  -e "s@BAZEL_TEST_HOST_PATH@$xctestrun_test_host_path@g" \
  -e "s@BAZEL_TEST_HOST_BUNDLE_IDENTIFIER@$xcrun_test_host_bundle_identifier@g" \
  -e "s@BAZEL_TEST_PRODUCT_MODULE_NAME@${test_bundle_name//-/_}@g" \
  -e "s@BAZEL_IS_XCTRUNNER_HOSTED_BUNDLE@$xcrun_is_xctrunner_hosted_bundle@g" \
  -e "s@BAZEL_IS_UI_TEST_BUNDLE@$xcrun_is_ui_test_bundle@g" \
  -e "s@BAZEL_TARGET_APP_PATH@$xcrun_target_app_path@g" \
  -e "s@BAZEL_TEST_ORDER_STRING@$test_order@g" \
  -e "s@BAZEL_DYLD_LIBRARY_PATH@__PLATFORMS__/$test_execution_platform/Developer/usr/lib@g" \
  -e "s@BAZEL_COVERAGE_OUTPUT_DIR@$test_tmp_dir@g" \
  -e "s@BAZEL_COMMAND_LINE_ARGS_SECTION@$xctestrun_cmd_line_args_section@g" \
  -e "s@BAZEL_SKIP_TEST_SECTION@$xctestrun_skip_test_section@g" \
  -e "s@BAZEL_ONLY_TEST_SECTION@$xctestrun_only_test_section@g" \
  -e "s@BAZEL_ARCHITECTURE@$architecture@g" \
  -e "s@BAZEL_TEST_BUNDLE_NAME@$test_bundle_name.xctest@g" \
  -e "s@BAZEL_PRODUCT_PATH@$xcrun_test_bundle_path@g" \
  "$xctestrun_template" > "$xctestrun_file"
