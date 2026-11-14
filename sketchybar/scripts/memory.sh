#!/bin/sh

# Match Activity Monitor: Memory Used = App Memory + Wired + Compressed.
# Cached files (file-backed) and free/speculative are reclaimable, so they
# are NOT counted as used. This is why macOS can show 90%+ "used" in
# top/vm_stat sums while pressure is still green.
#
# Sources:
# - Apple: Memory Used = App + Wired + Compressed
#   https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac
# - App Memory = vm.page_pageable_internal_count - Pages purgeable
#   (falls back to Anonymous pages - purgeable)
#   https://rzarajczyk.github.io/macos-memory-statistics/
#
# Compressed uses "Pages occupied by compressor" (physical footprint), not
# "Pages stored in compressor" (logical size, ~3x larger). Total is installed
# RAM (hw.memsize), not a vm_stat sum, which double-counts and misses
# hardware-reserved pages.
#
# One sysctl and one vm_stat | awk per run (was ~25 processes).

# shellcheck disable=SC2046
set -- $(sysctl -n vm.page_pageable_internal_count hw.memsize 2>/dev/null)
PAGEABLE="${1:-}"
TOTAL_BYTES="${2:-0}"

LABEL="$(vm_stat | LC_ALL=C awk -v pageable="$PAGEABLE" -v total_bytes="$TOTAL_BYTES" '
  function pages(line) { gsub(/[^0-9]/, "", line); return line + 0 }
  NR == 1                                 { page_size = pages($0) }
  /^Pages wired down:/                    { wired = pages($NF) }
  /^Pages occupied by compressor:/        { compressed = pages($NF) }
  /^Pages used by compressor:/            { compressed_fallback = pages($NF) }
  /^Pages purgeable:/                     { purgeable = pages($NF) }
  /^Anonymous pages:/                     { anonymous = pages($NF) }
  END {
    if (!page_size) page_size = 16384
    if (!compressed) compressed = compressed_fallback
    app = (pageable != "" ? pageable : anonymous) - purgeable
    if (app < 0) app = 0
    used_bytes = (app + wired + compressed) * page_size
    if (!total_bytes) total_bytes = used_bytes
    if (!total_bytes) exit
    printf "%d%% | %.1fG", used_bytes * 100 / total_bytes, used_bytes / 1073741824
  }')"

[ -n "$LABEL" ] && sketchybar --set "${NAME:-memory}" icon="" label="$LABEL"
