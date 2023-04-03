#!/bin/bash

xcrun simctl list -v
ls /Applications/

ps aux | grep "CoreSimulatorService"

killall -9 com.apple.CoreSimulator.CoreSimulatorService
