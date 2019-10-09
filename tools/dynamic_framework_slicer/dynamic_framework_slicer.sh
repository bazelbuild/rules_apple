#!/bin/bash 
set -eu

readonly WORK_DIR="$1"

# Strip out any unnecessary slices from embedded dynamic frameworks to save space
temp_basename=$(basename $0)
temp_file=$(mktemp -q /tmp/${temp_basename}.XXXXXX)
if [ $? -ne 0 ]; then
       echo "error: Can't create temp file, exiting..." >&2
       exit 1
fi
for app in "$WORK_DIR"/Payload/*.app; do
    # Lets figure out what slices the app has
    app_name=$(basename "$app" .app)
    app_slices=$(xcrun lipo -info "$app/$app_name" | cut -d: -f3)

    # Now lets make sure any included frameworks match
    for framework in "$app"/Frameworks/*.framework; do
        # We need to check we have overlapping architectures
        framework_name=$(basename "$framework" .framework)
        framework_slices=$(xcrun lipo -info "$framework"/"$framework_name" | cut -d: -f3)
        
        # The normal case should be that the framework and app have exactly the same slices.
        # Lets check that and skip processing if that is the case.
        if [ "$app_slices" == "$framework_slices" ]; then
            continue;
        fi

        lipo_args=""
        # Now make the framework match the slices the app has
        for slice in $app_slices ; do
            lipo_args="$lipo_args -extract $slice"
        done
        xcrun lipo "$framework"/"$framework_name" $lipo_args -output "$temp_file"
        if [ $? -ne 0 ]; then
            echo "error: lipo of $framework_name failed" >&2
            exit 1
        fi
        mv $temp_file "$framework"/"$framework_name"
    done
done
