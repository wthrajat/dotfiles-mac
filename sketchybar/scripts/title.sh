TITLE=$(yabai -m query --windows --window)
if [ "$TITLE" = "" ]; then
    sketchybar --set title y_offset=70 && sketchybar --set title label=""
else
    LABEL="$(echo $TITLE | jq -r '.title')"
    if [ "$(sketchybar --query title | jq -r '.label.value')" != "$LABEL" ]; then
        sketchybar --set title y_offset=70            \
                    --set title y_offset=7            \
                 --set title y_offset=0 && sketchybar --set title label="$LABEL"
    fi
fi