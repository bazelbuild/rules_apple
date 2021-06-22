#!/bin/bash
set -eu

# Xcode's stdout logging shows `swiftc -v` being called to determine its
# version. Passthrough those invocation to `swiftc`.
if [[ $# -eq 1 && $1 == "-v" ]]; then
    exec swiftc -v
fi

# Xcode expects a lot of files to be created from a swiftc invocation,
# namely all files present in the `output-file-map` JSON file.
# So, we encountering the parameter, call the outputfilemap to touch
# all files in the JSON.

write_output_files() {
    cat $1 | python $(dirname "$0")/outputfilemap | xargs touch
}

while :; do
    test $# -eq 0 && exit 0
    case $1 in
        -output-file-map)
            shift
            write_output_files $1
            ;;
        -emit-module-path)
            shift
            touch $1
            touch ${1%.swiftmodule}.swiftdoc
            touch ${1%.swiftmodule}.swiftsourceinfo
            ;;
        *)
            ;;
    esac

    shift
done