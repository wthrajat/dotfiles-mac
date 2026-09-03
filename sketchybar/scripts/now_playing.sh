#!/bin/sh
# now_playing.sh: SketchyBar item script (POSIX sh, no bashisms).
# Serves the main track item plus the optional control siblings
# (<base>.sep / .prev / .toggle / .next); $NAME tells them apart.
# Env from SketchyBar: $NAME (item), $SENDER (event), plus trigger payload:
#   $TITLE $ARTIST $ALBUM $BUNDLE $PLAYING $LABEL $ICON
#   $PREV_ICON $TOGGLE_ICON $NEXT_ICON (control glyphs)
# Also handles `routine` ticks and mouse clicks.
#
# Optional env:
#   NOW_PLAYING_BIN     explicit binary path (auto resolved when unset)
#   NOW_PLAYING_CONFIG  config file forwarded to every invocation
#
# Dispatch is O(1) on $SENDER, then on the $NAME suffix; every branch is
# a single action.

# SketchyBar.app runs with a minimal PATH, so resolve the binary once:
# explicit env wins, then PATH, then the common install prefixes.
BIN="${NOW_PLAYING_BIN:-}"
if [ -z "$BIN" ]; then
  if command -v sketchybar-now-playing >/dev/null 2>&1; then
    BIN="sketchybar-now-playing"
  else
    for dir in "$HOME/.cargo/bin" "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin; do
      if [ -x "$dir/sketchybar-now-playing" ]; then
        BIN="$dir/sketchybar-now-playing"
        break
      fi
    done
  fi
fi

# Thin wrapper so --config is honored without repeating the conditional.
run_bin() {
  if [ -n "$NOW_PLAYING_CONFIG" ]; then
    "$BIN" --config "$NOW_PLAYING_CONFIG" "$@"
  else
    "$BIN" "$@"
  fi
}

set_label() {
  # $1=label $2=icon $3=playing ("true" scrolls, anything else stays put)
  if [ -z "$1" ]; then
    sketchybar --set "$NAME" drawing=off
  elif [ "$3" = "true" ]; then
    sketchybar --set "$NAME" label="$1" icon="$2" scroll_texts=on drawing=on
  else
    sketchybar --set "$NAME" label="$1" icon="$2" scroll_texts=off drawing=on
  fi
}

# Fallback control glyphs when the daemon predates the *_ICON payload.
# Keep in sync with icons.rs (Nerd Font / Font Awesome transport set).
ICON_PREV=""
ICON_PLAY=""
ICON_PAUSE=""
ICON_NEXT=""

set_control() {
  # $1=icon. Controls hide with the track: no player, no buttons.
  if [ -z "${LABEL:-}" ]; then
    sketchybar --set "$NAME" drawing=off
  else
    sketchybar --set "$NAME" icon="$1" drawing=on
  fi
}

set_sep() {
  if [ -z "${LABEL:-}" ]; then
    sketchybar --set "$NAME" drawing=off
  else
    sketchybar --set "$NAME" label="|" drawing=on
  fi
}

toggle_glyph() {
  # Daemon payload wins; otherwise derive from playback state so a
  # paused player shows play and a playing one shows pause.
  if [ -n "${TOGGLE_ICON:-}" ]; then
    printf '%s' "$TOGGLE_ICON"
  elif [ "${PLAYING:-}" = "true" ]; then
    printf '%s' "$ICON_PAUSE"
  else
    printf '%s' "$ICON_PLAY"
  fi
}

handle_event() {
  case "$NAME" in
    *.prev)
      set_control "${PREV_ICON:-$ICON_PREV}"
      ;;
    *.toggle)
      set_control "$(toggle_glyph)"
      ;;
    *.next)
      set_control "${NEXT_ICON:-$ICON_NEXT}"
      ;;
    *.sep)
      set_sep
      ;;
    *)
      set_label "$LABEL" "$ICON" "$PLAYING"
      ;;
  esac
}

handle_click() {
  # Control siblings always fire their own action; the main item keeps
  # left toggle / right skip.
  if [ -z "$BIN" ]; then
    return
  fi
  case "$NAME" in
    *.prev)
      run_bin prev >/dev/null 2>&1
      ;;
    *.toggle)
      if run_bin toggle >/dev/null 2>&1; then
        flip_scroll "$NAME"
      fi
      ;;
    *.next)
      run_bin next >/dev/null 2>&1
      ;;
    *)
      if [ "${BUTTON:-left}" = "right" ]; then
        run_bin next >/dev/null 2>&1
      elif run_bin toggle >/dev/null 2>&1; then
        flip_scroll "$NAME"
      fi
      ;;
  esac
}

flip_scroll() {
  # $1=item. Optimistic scroll flip for toggle clicks: the system event
  # confirming the new state can lag seconds behind (browsers especially),
  # while the user's intent is known right now. The daemon's next event
  # and the `sync` tick both carry ground truth, so a wrong guess (e.g.
  # the player ignored the command) self corrects within seconds.
  # The toggle glyph itself is left to the event: only motion disturbs.
  if sketchybar --query "$1" 2>/dev/null | grep -q '"scroll_texts": *"on"'; then
    sketchybar --set "$1" scroll_texts=off
  else
    sketchybar --set "$1" scroll_texts=on
  fi
}

case "$SENDER" in
  mouse.clicked)
    # Fire and forget; the daemon's change event converges the bar,
    # so no output parsing here.
    handle_click
    ;;
  routine|forced|"")
    # Fallback and post reload convergence (empty $SENDER is the initial
    # run): pushes label, icon and visibility in one call, so the shell
    # parses no output.
    # Generic over $NAME: `sync` already knows the control suffixes.
    if [ -n "$BIN" ]; then
      run_bin sync "$NAME" >/dev/null 2>&1
    fi
    ;;
  *)
    # The subscribed change event, default `now_playing_change` or a
    # custom $NOW_PLAYING_EVENT. Matched by exclusion so custom names
    # work without extra configuration.
    handle_event
    ;;
esac
