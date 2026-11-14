#!/bin/sh
# i3-style: focus space N, creating spaces up to N first when it doesn't exist yet.

target="$1"

yabai -m space --focus "$target" 2>/dev/null && exit 0

space_count="$(yabai -m query --spaces --display |
  jq 'map(select(."is-native-fullscreen" == false)) | length')"

[ "$space_count" -lt "$target" ] || exit 0

while [ "$space_count" -lt "$target" ]; do
  yabai -m space --create || exit 1
  space_count=$((space_count + 1))
done

yabai -m space --focus "$target"
sketchybar --trigger space_change
