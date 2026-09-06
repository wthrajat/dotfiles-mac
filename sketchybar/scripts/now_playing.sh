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
  # $1=label $2=icon $3=playing ("true" scrolls, anything else stays put).
  # Sticky last track: empty label means idle, never hide. Keep the previous
  # label/icon, only stop motion. No `drawing` change, so the wiring-time
  # placeholder stays until the first track.
  if [ -z "$1" ]; then
    sketchybar --set "$NAME" scroll_texts=off
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
  # $1=icon. Sticky: idle (empty $LABEL) refreshes the glyph to the paused
  # set but leaves `drawing` untouched, so the placeholder and controls
  # stay exactly as the wiring left them until the first track.
  if [ -z "${LABEL:-}" ]; then
    sketchybar --set "$NAME" icon="$1"
  else
    sketchybar --set "$NAME" icon="$1" drawing=on
  fi
}

set_sep() {
  # Sticky: idle leaves the separator exactly as-is (no `drawing` change).
  if [ -z "${LABEL:-}" ]; then
    :
  else
    sketchybar --set "$NAME" label="|" drawing=on
  fi
}

# Idle fallback text. Keep in sync with Track::PLACEHOLDER_TITLE (track.rs)
# and the wiring placeholder label: while the bar shows this (or nothing),
# no player exists.
PLACEHOLDER="Play Something"

# True when no player exists, so media commands must not fire: a stray
# toggle with no active client wakes Apple Music. Ground truth is the
# displayed main-item label; a query failure also blocks (a missed click
# is harmless, a stray launch is not).
is_idle() {
  # $1=base item (callers resolve control siblings to the main item).
  current="$(sketchybar --query "$1" 2>/dev/null | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"]["value"])' 2>/dev/null)" || return 0
  [ -z "$current" ] || [ "$current" = "$PLACEHOLDER" ]
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
      # $TOGGLE_ICON first avoids a subshell fork in the common case (the
      # daemon always sends it); `toggle_glyph` covers legacy payloads.
      set_control "${TOGGLE_ICON:-$(toggle_glyph)}"
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
  # left toggle / right skip. No optimistic scroll flip: `scroll_texts`
  # strictly follows the daemon's PLAYING ground truth via the change event
  # and the `sync` tick, so a click never starts motion on its own.
  if [ -z "$BIN" ]; then
    return
  fi
  # Dead clicks when idle: with no player loaded every media command is a
  # no-op at best and wakes Apple Music at worst. Controls resolve to the
  # main item, whose label carries the idle state.
  case "$NAME" in
    *.sep|*.prev|*.toggle|*.next) base="${NAME%.*}" ;;
    *) base="$NAME" ;;
  esac
  if is_idle "$base"; then
    return
  fi
  case "$NAME" in
    *.prev)
      run_bin prev >/dev/null 2>&1
      ;;
    *.toggle)
      run_bin toggle >/dev/null 2>&1
      ;;
    *.next)
      run_bin next >/dev/null 2>&1
      ;;
    *)
      if [ "${BUTTON:-left}" = "right" ]; then
        run_bin next >/dev/null 2>&1
      else
        run_bin toggle >/dev/null 2>&1
      fi
      ;;
  esac
}

case "$SENDER" in
  mouse.clicked)
    # Fire and forget; the daemon's change event converges the bar,
    # so no output parsing here.
    handle_click
    ;;
  routine)
    # Periodic tick only: skip the heavy `sync` (binary + perl adapter +
    # bar update) while the event daemon is alive and pushing changes.
    # Falls back to polling the moment the daemon is gone.
    if [ -n "$BIN" ] && ! pgrep -f "[s]ketchybar-now-playing daemon" >/dev/null 2>&1; then
      run_bin sync "$NAME" >/dev/null 2>&1
    fi
    ;;
  forced|"")
    # Post reload convergence (empty $SENDER is the initial run): always
    # pushes label, icon and scroll state in one call, showing the
    # placeholder on idle instead of hiding, so the shell parses no output.
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
