#!/usr/bin/env bash

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

VM_STAT=$(vm_stat)

# Page size (16384 on Apple Silicon, 4096 on Intel). Parse robustly.
PAGE_SIZE=$(echo "$VM_STAT" | head -n 1 | grep -oE '[0-9]+')
[ -z "$PAGE_SIZE" ] && PAGE_SIZE=16384

# Helper: extract first integer from a vm_stat line, default 0.
get_pages() {
  local val
  val=$(echo "$VM_STAT" | grep -F "$1" | grep -oE '[0-9]+' | head -n 1)
  echo "${val:-0}"
}

PAGES_WIRED=$(get_pages "Pages wired down")
# Physical footprint. NOT "Pages stored in compressor" (that's the logical
# uncompressed size, ~3x larger - using it triple-counts compressed RAM).
PAGES_COMPRESSED=$(get_pages "Pages occupied by compressor")
if [ "$PAGES_COMPRESSED" -eq 0 ]; then
  PAGES_COMPRESSED=$(get_pages "Pages used by compressor")
fi
PAGES_PURGEABLE=$(get_pages "Pages purgeable")
PAGES_ANON=$(get_pages "Anonymous pages")

# App memory backing store. sysctl is the Activity Monitor source of truth;
# Anonymous pages is a close approximation (within ~1%).
PAGEABLE=$(sysctl -n vm.page_pageable_internal_count 2>/dev/null | grep -oE '[0-9]+' | head -n 1)
[ -z "$PAGEABLE" ] && PAGEABLE="$PAGES_ANON"

APP_PAGES=$((PAGEABLE - PAGES_PURGEABLE))
[ "$APP_PAGES" -lt 0 ] && APP_PAGES=0

# Total is installed RAM, not a vm_stat sum. Summing vm_stat double-counts
# (stored-in-compressor pages are already counted in active/inactive) and
# misses hardware-reserved pages, inflating total by ~10%+ on Apple Silicon.
TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null | grep -oE '[0-9]+' | head -n 1)
TOTAL_BYTES=${TOTAL_BYTES:-0}
if [ "$TOTAL_BYTES" -eq 0 ]; then
  TOTAL_BYTES=$(( (PAGES_WIRED + PAGES_COMPRESSED + APP_PAGES) * PAGE_SIZE ))
fi

USED_PAGES=$((APP_PAGES + PAGES_WIRED + PAGES_COMPRESSED))
BYTES_USED=$((USED_PAGES * PAGE_SIZE))

PERCENT=$((BYTES_USED * 100 / TOTAL_BYTES))

USED_GB=$(awk -v b="$BYTES_USED" 'BEGIN { printf "%.1f", b / 1024 / 1024 / 1024 }')

sketchybar --set "${NAME:-memory}" icon="" label="${PERCENT}% | ${USED_GB}G"
