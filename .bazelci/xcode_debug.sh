#!/bin/bash

xcrun simctl list -v
ls /Applications/

buildkite-agent artifact upload ~/Library/Logs/CoreSimulator/CoreSimulator.log

ps aux | grep "CoreSimulatorService"

pkill -9 com.apple.CoreSimulator.CoreSimulatorService
