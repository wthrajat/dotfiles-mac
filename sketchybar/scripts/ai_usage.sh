#!/bin/sh
# Claude Code and codex-work usage limits: percent used in the 5-hour and
# 7-day windows.
#
# Claude: the OAuth usage endpoint Claude Code itself uses. It is undocumented,
#   so it may change. The token comes from Claude Code's Keychain item, reaches
#   curl over stdin (never argv) and is never stored. Claude Code renews it;
#   this script never refreshes it.
# Codex: `account/rateLimits/read` on Codex's own app-server, run once against
#   the codex-work home. Codex handles its own auth; no credentials pass here.
#
# Each provider is fetched at most every 5 minutes. On failure the last good
# numbers stay on the bar, dimmed, and the popup says why.

umask 077

TEXT=0xFFcad3f5
DIM=0xFF6e738d
PEACH=0xFFf5a97f
RED=0xFFed8796

NOW="$(date +%s)"
CACHE_DIR="$HOME/Library/Caches/sketchybar"
CLAUDE_USAGE_URL="https://api.anthropic.com/api/oauth/usage"
CODEX_WORK_HOME="$HOME/.codex-work"
CODEX_TIMEOUT_TENTHS=100

# Seconds until the next request, by outcome.
OK_WAIT=300
ERROR_WAIT=60
AUTH_WAIT=300
RATE_LIMIT_WAIT=900

# ── fetchers ──
# Each prints {five_hour, seven_day, model?} with {used, resets} windows, or
# {error, wait} on failure.

fetch_error() {
  jq -n --arg error "$1" --argjson wait "$2" '{error: $error, wait: $wait}'
}

claude_token() {
  /usr/bin/security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null |
    jq -r --argjson now "$NOW" '.claudeAiOauth
      | select((.expiresAt // 0) / 1000 > $now) | .accessToken // empty' 2>/dev/null
}

fetch_claude() {
  token="$(claude_token)"
  if [ -z "$token" ]; then
    fetch_error "sign-in expired, open Claude Code" "$AUTH_WAIT"
    return
  fi

  response="$(printf 'Authorization: Bearer %s\nanthropic-beta: oauth-2025-04-20\nAccept: application/json\n' "$token" |
    curl -s --max-time 15 -H @- -w '\n%{http_code}' "$CLAUDE_USAGE_URL")"
  status="$(printf '%s' "$response" | tail -n 1)"

  case "$status" in
    200) printf '%s' "$response" | sed '$d' | jq '
      def epoch: try (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) catch null;
      def window: if . == null then null
        else {used: (.utilization | round), resets: (.resets_at | epoch)} end;
      {
        five_hour: (.five_hour | window),
        seven_day: (.seven_day | window),
        model: ([.limits[]? | select(.kind == "weekly_scoped")] | max_by(.percent)
          | if . == null then null else {
              name: (.scope.model.display_name // "model"),
              used: (.percent | round),
              resets: (.resets_at | epoch)
            } end)
      }' 2>/dev/null || fetch_error "unexpected response" "$ERROR_WAIT" ;;
    401 | 403) fetch_error "sign-in expired, open Claude Code" "$AUTH_WAIT" ;;
    429) fetch_error "rate limited, retrying later" "$RATE_LIMIT_WAIT" ;;
    *) fetch_error "offline or service error" "$ERROR_WAIT" ;;
  esac
}

# Sends the three JSON-RPC messages, then holds stdin open until the answer
# arrives (closing it early makes the server quit before replying).
codex_rate_limits_response() {
  reply="$(mktemp)"
  {
    printf '%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"sketchybar","version":"1"}}}' \
      '{"jsonrpc":"2.0","method":"initialized"}' \
      '{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read"}'
    tenths=0
    while [ "$tenths" -lt "$CODEX_TIMEOUT_TENTHS" ] && ! grep -q '"id":2[,}]' "$reply"; do
      sleep 0.1
      tenths=$((tenths + 1))
    done
  } | CODEX_HOME="$CODEX_WORK_HOME" codex app-server 2>/dev/null >"$reply"
  grep '"id":2[,}]' "$reply"
  rm -f "$reply"
}

fetch_codex() {
  command -v codex >/dev/null || { fetch_error "codex not installed" "$AUTH_WAIT"; return; }

  codex_rate_limits_response | jq -e '
    if .result.rateLimits == null then error("no limits") else .result.rateLimits end
    | [.primary, .secondary] as $windows
    | def window($minutes): $windows
        | map(select(.windowDurationMins? == $minutes))[0]
        | if . == null then null else {used: (.usedPercent | round), resets: .resetsAt} end;
    {five_hour: window(300), seven_day: window(10080)}' 2>/dev/null ||
    fetch_error "no reply, check codex-work sign-in" "$ERROR_WAIT"
}

# ── cache ──

is_due() {
  retry_at="$(jq -r '.retry_at // 0' "$1" 2>/dev/null)"
  [ "${retry_at:-0}" -le "$NOW" ]
}

# Writes fresh numbers, or keeps the old ones and records the error.
save_result() {
  cache="$1" result="$2"
  previous="$(cat "$cache" 2>/dev/null)"
  [ -n "$previous" ] || previous='{}'
  jq -n --argjson previous "$previous" --argjson result "$result" \
    --argjson now "$NOW" --argjson ok_wait "$OK_WAIT" '
    if $result.error then
      $previous + {error: $result.error, retry_at: ($now + $result.wait)}
    else
      $result + {error: null, retry_at: ($now + $ok_wait)}
    end' >"$cache.tmp" && mv "$cache.tmp" "$cache"
}

refresh() {
  cache="$1" fetcher="$2"
  is_due "$cache" || return
  result="$($fetcher)"
  [ -n "$result" ] || result="$(fetch_error "fetch failed" "$ERROR_WAIT")"
  save_result "$cache" "$result"
}

# ── rendering ──

format_time() {
  if [ "$(date -r "$1" +%F)" = "$(date +%F)" ]; then
    date -r "$1" '+%I:%M %p'
  else
    date -r "$1" '+%a %d %b, %I:%M %p'
  fi
}

usage_color() {
  if [ "$1" -ge 90 ]; then echo "$RED"
  elif [ "$1" -ge 75 ]; then echo "$PEACH"
  else echo "$TEXT"; fi
}

# Once a window's reset time passes, its usage is back to zero.
current_usage() {
  used="$1" resets="$2"
  if [ -n "$resets" ] && [ "$resets" -le "$NOW" ]; then echo 0; else echo "$used"; fi
}

# Dimmed when the last fetch failed, so stale numbers don't look current.
label_color() {
  used="$1" error="$2"
  if [ -n "$error" ]; then echo "$DIM"
  elif [ -n "$used" ]; then usage_color "$used"
  else echo "$TEXT"; fi
}

window_label() {
  if [ -n "$1" ]; then printf '%s%%' "$1"; else printf -- '--'; fi
}

# An untouched window has no real reset time: the API keeps sliding it forward.
set_popup_row() {
  row="$1" name="$2" used="$3" resets="$4"
  if [ -z "$used" ]; then
    sketchybar --set "$row" drawing=off
  elif [ "$used" -eq 0 ]; then
    sketchybar --set "$row" drawing=on icon="$name" label="0%  not started" \
      label.color="$TEXT"
  else
    sketchybar --set "$row" drawing=on icon="$name" \
      label="$used%  resets $(format_time "$resets")" \
      label.color="$(usage_color "$used")"
  fi
}

set_note_row() {
  row="$1" text="$2"
  if [ -n "$text" ]; then
    sketchybar --set "$row" drawing=on label="$text"
  else
    sketchybar --set "$row" drawing=off
  fi
}

# Splits the cache into shell fields separated by "|", which keeps empty
# fields (tabs would collapse them).
read_usage() {
  jq -r '[
    .five_hour.used, .five_hour.resets, .seven_day.used, .seven_day.resets,
    .model.name, .model.used, .model.resets, .error
  ] | map(. // "" | tostring) | join("|")' "$1" 2>/dev/null
}

render() {
  item="$1" cache="$2"
  [ -f "$cache" ] || { set_note_row "$item.note" "no data yet"; return; }
  IFS='|' read -r five five_resets seven seven_resets \
    model_name model model_resets error <<EOF
$(read_usage "$cache")
EOF

  [ -n "$five" ] && five="$(current_usage "$five" "$five_resets")"
  [ -n "$seven" ] && seven="$(current_usage "$seven" "$seven_resets")"
  [ -n "$model" ] && model="$(current_usage "$model" "$model_resets")"

  sketchybar --set "$item" label="$(window_label "$seven")" \
               label.color="$(label_color "$seven" "$error")" \
             --set "$item.session" label="$(window_label "$five")" \
               label.color="$(label_color "$five" "$error")"
  set_popup_row "$item.5h" "5h" "$five" "$five_resets"
  set_popup_row "$item.7d" "7d" "$seven" "$seven_resets"
  [ "$item" = ai.claude ] &&
    set_popup_row "$item.model" "$model_name 7d" "$model" "$model_resets"
  set_note_row "$item.note" "$error"
}

# ── main ──

mkdir -p "$CACHE_DIR"
CLAUDE_CACHE="$CACHE_DIR/claude_usage.json"
CODEX_CACHE="$CACHE_DIR/codex_work_usage.json"

refresh "$CLAUDE_CACHE" fetch_claude
refresh "$CODEX_CACHE" fetch_codex
render ai.claude "$CLAUDE_CACHE"
render ai.codex "$CODEX_CACHE"
