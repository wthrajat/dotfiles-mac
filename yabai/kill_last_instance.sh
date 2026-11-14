#!/bin/sh
# Close the focused window, or quit its app when it is the app's last window.

focused_app_info="$(yabai -m query --windows | jq -r '
  (map(select(."has-focus"))[0].pid) as $pid
  | select($pid != null)
  | "\($pid) \(map(select(.pid == $pid)) | length)"')"

[ -n "$focused_app_info" ] || exit 0

app_pid="${focused_app_info% *}"
app_window_count="${focused_app_info#* }"

if [ "$app_window_count" -gt 1 ]; then
  yabai -m window --close
else
  kill "$app_pid"
fi
