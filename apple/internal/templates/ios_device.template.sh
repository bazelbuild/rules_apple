#!/bin/bash
set -eu

%idevicedebugserverproxy% 3222 &
proxy_pid=$!

device_name=$(%ideviceinfo% -k DeviceName)
os_version=$(%ideviceinfo% -k ProductVersion | cut -c1-4)
platform_path=$(xcrun --sdk iphoneos --show-sdk-platform-path)
os_version_path=$(find ${platform_path}/DeviceSupport -type d -name ${os_version}\* -d 1 -print)
symbols_path=$(find "${HOME}/Library/Developer/Xcode/iOS DeviceSupport" -type d -name ${os_version}\* -d 1 -print)
image=${os_version_path}/DeveloperDiskImage.dmg
signature=${image}.signature

readonly WORK=$(mktemp -d "${TMPDIR:-/tmp}/bazel_temp.XXXXXX")
trap 'rm -rf "${WORK}"; kill -9 ${proxy_pid};' ERR EXIT

%ideviceprovision% install %provisioning_profile%

%ideviceimagemounter% "${image}" "${image}.signature" || true

%ideviceinstaller% -i %ipa_file%

container_path=$(%containerpathtool% %bundle_id%)

unzip -qq '%ipa_file%' -d "${WORK}/extract"

cat <<EOF > ${WORK}/launch.lldb
platform select remote-ios --sysroot '${symbols_path}'
target create '${WORK}/extract/Payload/%app_name%.app'
script lldb.target.modules[0].SetPlatformFileSpec(lldb.SBFileSpec('${container_path}'))
process connect connect://127.0.0.1:3222
process launch
EOF

cat ${WORK}/launch.lldb

lldb -s ${WORK}/launch.lldb
