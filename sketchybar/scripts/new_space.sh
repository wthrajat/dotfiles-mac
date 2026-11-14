#!/bin/sh
# Create a space and focus it. Shared by the sketchybar "+" button and skhd.
# Native fullscreen spaces sit after user spaces, so pick the last user space.

yabai -m space --create || exit 1

new_space_index="$(yabai -m query --spaces --display |
  jq 'map(select(."is-native-fullscreen" == false))[-1].index')"

yabai -m space --focus "$new_space_index"
sketchybar --trigger space_change
