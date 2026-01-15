#!/bin/bash

set -euo pipefail

readonly plist="/tmp/$SIMULATOR_UDID.simulator.defaults.plist"
trap 'rm -f "$plist"' EXIT

function set_or_add_to_simulator_app_defaults() {
  local -r _keypath="$1"
  local -r _type="$2"
  local -r _value="$3"
  IFS=':' read -r -a _parts <<< "$_keypath"

  local -r _last_index=$((${#_parts[@]} - 1))

  # Export the plist to a temporary file
  /usr/bin/defaults export com.apple.iphonesimulator "$plist"

  # Create intermediate dicts
  local _prefix=""
  for ((i = 0; i < ${#_parts[@]} - 1; i++)); do
    _prefix="$_prefix:${_parts[i]}"
    /usr/libexec/PlistBuddy -c "Print $_prefix" "$plist" \
      > /dev/null 2>&1 || /usr/libexec/PlistBuddy -c "Add $_prefix dict" "$plist"
  done

  # Set or add the final key
  local -r _full="$_prefix:${_parts[$_last_index]}"
  if
    ! /usr/libexec/PlistBuddy -c "Set $_full $_type $_value" "$plist" \
      2> /dev/null
  then
    /usr/libexec/PlistBuddy -c "Add $_full $_type $_value" "$plist"
  fi

  # Import the modified plist back to the simulator
  /usr/bin/defaults import com.apple.iphonesimulator "$plist"
}

# Disable hardware keyboard
set_or_add_to_simulator_app_defaults \
  "DevicePreferences:$SIMULATOR_UDID:ConnectHardwareKeyboard" "bool" "false"

# Disable slide typing prompt
/usr/bin/xcrun simctl spawn "$SIMULATOR_UDID" \
  defaults write com.apple.keyboard.preferences \
  DidShowContinuousPathIntroduction 1
