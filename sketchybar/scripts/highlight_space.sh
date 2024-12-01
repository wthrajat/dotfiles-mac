SID=$(echo $INFO | jq .[\"display-1\"])
if [ "$SID" = "" ]; then
    SID=$(yabai -m query --spaces --space | jq '.index')
fi
LENGTH=$($(echo yabai -m query --spaces) | jq length)
sketchybar --set highlight_space background.padding_left=$((-(LENGTH - (SID - 2)) * 30 + 7))