#!/bin/bash
set -eu

# stub out implementation of clang to make it a no-op
while :; do
    case $1 in
        -MF)
            shift
            touch $1
            ;;
        *.o)
            break
            ;;
    esac

    shift
done