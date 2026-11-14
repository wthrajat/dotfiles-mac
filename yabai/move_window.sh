#!/bin/sh
# i3-style move: move the focused window toward <north|south|east|west>.
# When nothing is in that direction because the split runs the other way
# (side by side for up/down, stacked for left/right), flip the split first.
#
# Uses --swap, not --warp: warp re-inserts as the second child
# (window_placement), so warping a bottom window north lands it at the bottom.

direction="$1"

yabai -m window --swap "$direction" 2>/dev/null && exit 0

case "$direction" in
  north|south) flippable_split="vertical" ;;
  east|west)   flippable_split="horizontal" ;;
  *)           exit 1 ;;
esac

current_split="$(yabai -m query --windows --window | jq -r '."split-type"')"
[ "$current_split" = "$flippable_split" ] || exit 0

yabai -m window --toggle split
yabai -m window --swap "$direction" 2>/dev/null
exit 0
