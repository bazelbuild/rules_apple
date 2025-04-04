#!/bin/bash

set -euo pipefail

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# Only change this version after all testing has happened.
#
# If this version is changed then CI won't use the staging RBE pool, and the
# changes will impact all executors in the default pool.
#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
readonly non_staging_version=41

if [[ -z "${EXAMPLE_CI_STAGING_VERSION:-}" ]]; then
  readonly expected_version="$non_staging_version"
else
  readonly expected_version="staging-$EXAMPLE_CI_STAGING_VERSION"
fi

function check_need_shutdown() {
  local -r current_version="$1"

  if [[ -z "$current_version" ]]; then
    return 1
  fi

  if [[ -z "${EXAMPLE_CI_STAGING_VERSION:-}" ]]; then
    if [[ $current_version =~ ^[0-9]+$ ]]; then
      [[ "$current_version" -lt "$expected_version" ]]
    else
      return 0
    fi
  else
    [[ "$current_version" != "$expected_version" ]]
  fi
}

# While we are only allowing a single simulator on remote executors we need to
# more aggressively clean up unused simulators. If this is too large, then we
# have an extra 6GB memory usage sticking around. If this is too small, then we
# will constantly be deleting and creating simulators, adding at least 10
# seconds to test runtimes.
readonly delete_after_idle_secs=0
readonly delete_recently_used_after_idle_secs="${EXAMPLE_SIMULATOR_MANAGER_DELETE_RECENTLY_USED_AFTER_IDLE_SECS:-60}" # TODO: Tweak this more. Adjusted to 1 minute to help BuildBuddy with disk space issues.
readonly recently_used_capacity="${EXAMPLE_SIMULATOR_MANAGER_RECENTLY_USED_CAPACITY:-1}"

readonly mutex_timeout=60
readonly shutdown_timeout=45
readonly startup_timeout=10
readonly stale_mutex_seconds=120
readonly socket="/tmp/simulator_manager.sock"
readonly pid_path="/tmp/simulator_manager.pid"
readonly mutex_path="/tmp/simulator_manager_start.lock"
readonly scripts_path="/tmp/simulator_manager.scripts"

function exitMutex() {
  rmdir "$mutex_path" 2> /dev/null || true
  trap - EXIT
}

function enterMutex() {
  if [[ -d "$mutex_path" ]]; then
    local mtime
    mtime=$(stat -f %B "$mutex_path")
    local now
    now=$(date +%s)
    if (((now - mtime) > stale_mutex_seconds)); then
      echo >&2 "$(date '+[%H:%M:%S]') ⚠️ Deleting stale lock file. This" \
        "shouldn't happen."
      rm -rf "$mutex_path"
    fi
  fi

  for _ in $(seq 1 "$mutex_timeout"); do
    if mkdir "$mutex_path" 2> /dev/null; then
      trap 'exitMutex' EXIT
      return 0
    fi
    sleep 1
  done

  return 1
}

if ! enterMutex; then
  echo >&2 "$(date '+[%H:%M:%S]') ❌ Failed to acquire lock after" \
    "$mutex_timeout seconds; exiting"
  exit 1
fi

if
  { server_pid=$(< "$pid_path"); } 2> /dev/null \
    && ps -p "$server_pid" > /dev/null
then
  echo "$(date '+[%H:%M:%S]') Existing simulator manager found; checking" \
    "version"
  if version=$(
    curl \
      --silent \
      --fail-with-body \
      --unix-socket "$socket" \
      -XGET \
      'http:/-/version'
  ); then
    echo "$(date '+[%H:%M:%S]') Existing simulator manager version is $version"
  else
    echo >&2 "$(date '+[%H:%M:%S]') ❌ Failed to get simulator manager" \
      "version: $version"
    server_pid=""
    version=""
  fi
else
  echo "$(date '+[%H:%M:%S]') Existing simulator manager not found"
  server_pid=""
  version=""
fi

if check_need_shutdown "$version"; then
  echo "$(date '+[%H:%M:%S]') Shutting down existing simulator manager to" \
    "upgrade to version $expected_version"
  if response=$(
    curl \
      --silent \
      --fail-with-body \
      --unix-socket "$socket" \
      -XPOST \
      'http:/-/shutdown'
  ); then
    echo "$(date '+[%H:%M:%S]') Sent graceful shutdown request to simulator" \
      "manager"

    for _ in $(seq 1 "$shutdown_timeout"); do
      if ! ps -p "$server_pid" > /dev/null; then
        echo "$(date '+[%H:%M:%S]') Simulator manager shut down successfully"
        break
      fi
      sleep 1
    done
    if ps -p "$server_pid" > /dev/null; then
      echo >&2 "$(date '+[%H:%M:%S]') 🛑 Simulator manager did not shutdown" \
        "in $shutdown_timeout seconds; killing it"
      kill -9 "$server_pid"
    fi
  else
    echo >&2 "$(date '+[%H:%M:%S]') 🛑 Failed to gracefully shut down" \
      "simulator manager ($response); killing it"
    kill -9 "$server_pid"
  fi

  # Kill all straggler processes, in case they started under a different pid
  killall simulator_manager_opt 2> /dev/null || true

  server_pid=""
  version=""
fi

if [[ -z "$version" ]]; then
  rm -f "$pid_path" || true

  echo "$(date '+[%H:%M:%S]') Starting simulator manager"

  # --- begin runfiles.bash initialization v3 ---
  # Copy-pasted from the Bazel Bash runfiles library v3.
  set +e
  f=bazel_tools/tools/bash/runfiles/runfiles.bash
  # shellcheck disable=SC1090
  source "${RUNFILES_DIR:-/dev/null}/$f" 2> /dev/null \
    || source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2> /dev/null \
    || source "$0.runfiles/$f" 2> /dev/null \
    || source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2> /dev/null \
    || source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2> /dev/null \
    || {
      echo >&2 "ERROR: cannot find $f"
      exit 1
    }
  f=
  set -e
  # --- end runfiles.bash initialization v3 ---

  simulator_manager="$(
    rlocation _main/tools/snoozel/simulator_manager/simulator_manager_opt
  )"
  bazel_prepare_simulator="$(
    rlocation _main/tools/snoozel/simulator_manager/prepare_simulator
  )"

  # We need to copy the prepare_simulator script to a location that will stick
  # around after the test runner exits. On RBE the workspace is deleted after
  # an action runs, and if the simulator manager tries to run this script then
  # it will fail with an error like:
  #
  #   shell-init: error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
  #   chdir: error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
  readonly prepare_simulator="$scripts_path/prepare_simulator.sh"
  mkdir -p "$scripts_path"
  cp "$bazel_prepare_simulator" "$prepare_simulator"

  # Run server in background, in a new process group
  # Adjust `PATH` since it's limited when the simulator manager is started in a
  # test runner (in particular it doesn't have `/usr/sbin:/sbin` in `PATH`)
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    perl -e 'use POSIX setsid; setsid or die "setsid: $!"; exec @ARGV' \
    "$simulator_manager" \
    --version \
    "$expected_version" \
    --pid-path \
    "$pid_path" \
    --unix-socket-path \
    "$socket" \
    --delete-recently-used-idle-after \
    "$delete_recently_used_after_idle_secs" \
    --delete-idle-after \
    "$delete_after_idle_secs" \
    --recently-used-capacity \
    "$recently_used_capacity" \
    "--post-boot" \
    "$prepare_simulator" \
    > /dev/null 2>&1 \
    &

  for _ in $(seq 1 "$startup_timeout"); do
    if [[ -f "$pid_path" ]]; then
      break
    fi
    sleep 1
  done
  if [[ ! -f "$pid_path" ]]; then
    echo >&2 "$(date '+[%H:%M:%S]') error: ❌ Failed to start simulator" \
      "manager in 10 seconds; exiting"
    exit 1
  fi

  server_pid=$(< "$pid_path")

  echo "$(date '+[%H:%M:%S]') ✅ Started simulator manager with pid $server_pid"
else
  echo "$(date '+[%H:%M:%S]') ✅ Simulator manager with version $version" \
    "already running with pid $server_pid"
fi

exitMutex
