#!/bin/bash

# Taken from https://github.com/MobileNativeFoundation/index-import

# ex: /private/var/tmp/_bazel_<username>/<hash>/execroot/<workspacename>
bazel_root="^/private/var/tmp/_bazel_.+?/.+?/execroot/[^/]+"
# ex: bazel-out/ios-x86_64-min11.0-applebin_ios-ios_x86_64-dbg/bin
bazel_bin="^(?:$bazel_root/)?bazel-out/.+?/bin"

# ex: $bazel_bin/<package>/<target>_objs/<source>.swift.o
bazel_swift_object="$bazel_bin/.*/(.+?)_objs/.*/(.+?)\\.swift\\.o$"
# ex: Build/Intermediates.noindex/<project>.build/Debug-iphonesimulator/<target>.build/Objects-normal/x86_64/<source>.o
xcode_object="$CONFIGURATION_TEMP_DIR/\$1.build/Objects-normal/$ARCHS/\$2.o"

# ex: $bazel_bin/<package>/<module>.swiftmodule
bazel_module="$bazel_bin/.*/(.+?)\\.swiftmodule$"
# ex: Build/Products/Debug-iphonesimulator/<module>.swiftmodule/x86_64.swiftmodule
xcode_module="$BUILT_PRODUCTS_DIR/\$1.swiftmodule/$ARCHS.swiftmodule"

echo $BUILD_DIR

index-import \
    -remap "$bazel_module=$xcode_module" \
    -remap "$bazel_swift_object=$xcode_object" \
    -remap "$bazel_root=$SRCROOT" \
    "$SRCROOT/bazel-out/<config>/bin/<package>/<module>.indexstore" \
    "$BUILD_DIR"/../../Index/DataStore