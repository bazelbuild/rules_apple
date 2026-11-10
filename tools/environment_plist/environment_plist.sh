#!/bin/bash
#
# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# environment_plist generates a plist file that contains some
# environment variables of the host machine (like DTPlatformBuild
# or BuildMachineOSBuild) given a target platform.
#
# This script only runs on darwin and you must have Xcode installed.
#
# --output    - the path to place the output plist file.
# --platform  - the target platform, e.g. 'iphoneos' or 'iphonesimulator8.3'
#

set -eu

# Resolve DEVELOPER_DIR via xcode-select if not already set.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
fi
# A DEVELOPER_DIR in external/ is found in the runfiles.
if [[ -n "${DEVELOPER_DIR:-}" && ! -d "${DEVELOPER_DIR}" ]]; then
  runfiles_dir="${RUNFILES_DIR:-${0}.runfiles}"
  runfiles_developer_dir="${runfiles_dir}/${DEVELOPER_DIR#external/}"
  if [[ -d "${runfiles_developer_dir}" ]]; then
    DEVELOPER_DIR="${runfiles_developer_dir}"
  fi
fi
# Prefer the toolchain's tools.
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
fi
# macOS's PlistBuddy, after any on PATH.
if [[ -d /usr/libexec ]]; then
  export PATH="$PATH:/usr/libexec"
fi

while [[ $# > 1 ]]
do
key="$1"

case $key in
  --platform)
    PLATFORM="$2"
    shift
    ;;
  --output)
    OUTPUT="$2"
    shift
    ;;
  *)
    # unknown option
    ;;
esac
shift
done

set +e
PLATFORM_DIR=$(xcrun --sdk "${PLATFORM}" --show-sdk-platform-path 2>/dev/null)
XCRUN_EXITCODE=$?
set -e
if [[ ${XCRUN_EXITCODE} -ne 0 ]] ; then
  echo "environment_plist: SDK not located. This may indicate that the xcode \
and SDK version pair is not available."
  # Since this already failed, assume this is going to fail again. With
  # set -e, this will produce the appropriate stderr and error code.
  xcrun --sdk "${PLATFORM}" --show-sdk-platform-path 2>&1
fi

PLATFORM_PLIST="${PLATFORM_DIR}"/Info.plist
SDK_DIR=$(xcrun --sdk "${PLATFORM}" --show-sdk-path 2>/dev/null)
TEMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/bazel_environment.XXXXXX")
PLIST="${TEMPDIR}/env.plist"
trap 'rm -rf "${TEMPDIR}"' ERR EXIT

os_build=$(sw_vers --buildVersion)
compiler=$(PlistBuddy -c "Print :DefaultProperties:DEFAULT_COMPILER" "${PLATFORM_PLIST}")

# Versions from the plists, so that xcodebuild isn't needed.
platform_version=$(PlistBuddy -c "Print :Version" "${PLATFORM_PLIST}" 2>/dev/null || echo "")
sdk_build=$(PlistBuddy -c "Print :ProductBuildVersion" "${SDK_DIR}/System/Library/CoreServices/SystemVersion.plist" 2>/dev/null || echo "")
platform_build="${sdk_build}"

XCODE_VERSION_PLIST="${DEVELOPER_DIR}/../version.plist"
xcode_build=$(PlistBuddy -c "Print :ProductBuildVersion" "${XCODE_VERSION_PLIST}" 2>/dev/null || echo "")
xcode_version_string=$(PlistBuddy -c "Print :CFBundleShortVersionString" "${XCODE_VERSION_PLIST}" 2>/dev/null || echo "")
# Converts '7.1' -> 0710, and '7.1.1' -> 0711.
xcode_version=$(printf '%02d%d%d\n' $(echo "${xcode_version_string//./ }"))

PlistBuddy \
    -c "Add :DTPlatformBuild string ${platform_build:-""}" \
    -c "Add :DTSDKBuild string ${sdk_build:-""}" \
    -c "Add :DTPlatformVersion string ${platform_version:-""}" \
    -c "Add :DTXcode string ${xcode_version:-""}" \
    -c "Add :DTXcodeBuild string ${xcode_build:-""}" \
    -c "Add :DTCompiler string ${compiler:-""}" \
    -c "Add :BuildMachineOSBuild string ${os_build:-""}" \
    "$PLIST" > /dev/null

plutil -convert binary1 -o "${OUTPUT}" -s  -- "${PLIST}"
