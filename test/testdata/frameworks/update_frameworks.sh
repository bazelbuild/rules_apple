#!/bin/bash

# Copyright 2019 The Bazel Authors. All rights reserved.
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

# Run this script from a macOS machine to update the checked-in dynamic and
# static iOS test frameworks.

set -eu

SRCROOT="$(dirname "$0")"
INTERMEDIATES_DIR="$(mktemp -d /tmp/frameworks.XXXXXXXXXXXX)"

xcrun() {
    command xcrun -sdk iphonesimulator "$@"
}

libtool() {
    ZERO_AR_DATE=1 xcrun libtool "$@"
}

# Compile and link the SharedClass.m file into a static and dynamic binaries.
xcrun clang \
    -mios-simulator-version-min=11 \
    -arch x86_64 \
    -c "$SRCROOT/SharedClass.m" \
    -o "$INTERMEDIATES_DIR/SharedClass.o"

libtool \
    -static \
    -o "$INTERMEDIATES_DIR/iOSStaticFramework" \
    "$INTERMEDIATES_DIR/SharedClass.o"

xcrun clang \
    -dynamiclib \
    -arch x86_64 \
    -fobjc-link-runtime \
    -mios-simulator-version-min=11.0 \
    -install_name @rpath/DynamicFramework.framework/DynamicFramework \
    "$INTERMEDIATES_DIR/SharedClass.o" \
    -o "$INTERMEDIATES_DIR/iOSDynamicFramework"

# Update the SharedClass.h and binaries for the frameworks.
cp -f "$SRCROOT/SharedClass.h" \
    "$SRCROOT/iOSDynamicFramework.framework/Headers/SharedClass.h"
cp -f "$SRCROOT/SharedClass.h" \
    "$SRCROOT/iOSStaticFramework.framework/Headers/SharedClass.h"

cp -f "$INTERMEDIATES_DIR/iOSDynamicFramework" \
    "$SRCROOT/iOSDynamicFramework.framework/iOSDynamicFramework"
cp -f "$INTERMEDIATES_DIR/iOSStaticFramework" \
    "$SRCROOT/iOSStaticFramework.framework/iOSStaticFramework"

swiftc() {
    xcrun swiftc \
          -target x86_64-apple-ios11.0-simulator \
          -module-name iOSSwiftStaticFramework \
          "$@"
}

swiftc \
    -emit-objc-header-path \
    "$INTERMEDIATES_DIR/SharedClass.h" \
    -emit-module \
    -o "$INTERMEDIATES_DIR/iOSSwiftStaticFramework.swiftmodule" \
    "$SRCROOT/SharedClass.swift"

swiftc \
    -emit-object \
    -o "$INTERMEDIATES_DIR/SharedClass.o" \
    "$SRCROOT/SharedClass.swift"

libtool \
      -static \
      -o "$INTERMEDIATES_DIR/iOSSwiftStaticFramework" \
      "$INTERMEDIATES_DIR/SharedClass.o" \

# Update the headers, modules, and binary in iOSSwiftStaticFramework.
mkdir -p "$SRCROOT/iOSSwiftStaticFramework.framework/Headers"
cp -f "$INTERMEDIATES_DIR/SharedClass.h" \
   "$SRCROOT/iOSSwiftStaticFramework.framework/Headers/SharedClass.h"

mkdir -p "$SRCROOT/iOSSwiftStaticFramework.framework/Modules/iOSSwiftStaticFramework.swiftmodule"
cp -f "$INTERMEDIATES_DIR/iOSSwiftStaticFramework.swiftmodule" \
   "$SRCROOT/iOSSwiftStaticFramework.framework/Modules/iOSSwiftStaticFramework.swiftmodule/x86_64.swiftmodule"

cp -f "$INTERMEDIATES_DIR/iOSSwiftStaticFramework" \
   "$SRCROOT/iOSSwiftStaticFramework.framework"
