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

simulator_name=""
while [[ $# -gt 0 ]]; do
  arg="$1"
  case $arg in
    --simulator_name=*)
      simulator_name="${arg##*=}"
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
saved_IFS=$IFS
IFS=","
for test_env_key_value in ${test_env}; do
  IFS="=" read -r key value <<< "$test_env_key_value"
  passthrough_env+=("SIMCTL_CHILD_$key=$value")
done
IFS=$saved_IFS

simulator_creator_args=(
  "%(os_version)s" \
  "%(device_type)s" \
  --name "$simulator_name"
)

reuse_simulator="%(reuse_simulator)s"
if [[ "$reuse_simulator" == true ]]; then
  simulator_creator_args+=(--reuse-simulator)
else
  simulator_creator_args+=(--no-reuse-simulator)
fi

simulator_id="$("./%(simulator_creator.py)s" "${simulator_creator_args[@]}")"

test_exit_code=0
readonly testlog=$test_tmp_dir/test.log

platform_developer_dir="$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer"
SIMCTL_CHILD_DYLD_LIBRARY_PATH="$platform_developer_dir/usr/lib" \
  SIMCTL_CHILD_DYLD_FALLBACK_FRAMEWORK_PATH="$platform_developer_dir/Library/Frameworks" \
  xcrun simctl \
  spawn \
  "$simulator_id" \
  "$test_tmp_dir/$test_bundle_name.xctest/$test_bundle_name" \
  2>&1 | tee -i "$testlog" | (grep -v "One of the two will be used" || true) \
  || test_exit_code=$?

if [[ "$reuse_simulator" == false ]]; then
  # Delete will shutdown down the simulator if it's still currently running.
  xcrun simctl delete "$simulator_id"
fi

if [[ "$test_exit_code" -ne 0 ]]; then
  echo "error: tests exited with '$test_exit_code'" >&2
  exit "$test_exit_code"
fi
