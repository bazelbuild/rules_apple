#!/bin/bash

xcrun simctl list -v
ls /Applications/

buildkite-agent artifact upload ~/Library/Logs/CoreSimulator/CoreSimulator.log

pkill -9 com.apple.CoreSimulator.CoreSimulatorService
