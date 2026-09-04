#!/bin/sh
# space.sh: per-space selected styling (runs on $SELECTED change + --update).
# Active space gets a solid mauve chip with a dark number;
# inactive spaces are plain gray numbers. The number is never covered,
# so it can't disappear like it did under the old sliding dot.
# Env from SketchyBar: $NAME (item), $SELECTED ("true"/"false").

if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" background.drawing=on \
                           background.color=0xFFc6a0f6 \
                           icon.color=0xFF181926
else
  sketchybar --set "$NAME" background.drawing=off \
                           icon.color=0xFF8087a2
fi
