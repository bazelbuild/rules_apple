#!/bin/bash
codesign -dvvv "$@" || exit 0
