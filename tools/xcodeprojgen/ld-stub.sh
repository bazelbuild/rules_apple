#!/bin/bash
set -eu

while :; do
    test $# -eq 0 && exit 0
    case $1 in
        *.dat)
            # provides the header for an empty .dat file
            echo -n -e '\x00lld\0' > $1
            ;;
        *)
            ;;
    esac

    shift
done