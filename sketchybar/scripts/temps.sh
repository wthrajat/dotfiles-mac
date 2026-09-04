#!/usr/bin/env sh
# CPU temp = mean across Apple Silicon CPU die banks (PMU tdie* via mac-temp,
# read from the PMU through IOKit HID — the same sensors powermetrics-class
# tools use; no sudo needed).
#
# Mean, not peak: across 5 polls the peak jumped 72.8–75.5°C (±3°C noise from
# one hot bank) while the mean held steady. Mean is the conventional single
# "CPU temp" (btop averages eACC/pACC; Vitals shows rounded average in the
# menu bar). Deliberately excluded: tcal (Apple's internal calibrated
# estimate, reads ~15°C lower), NAND and battery sensors.
# Aggregation details: each of the 14 die banks prints 3 queued samples, so
# we keep the last (freshest) value per bank, drop readings below 10°C —
# physically impossible since Apple's rated minimum operating ambient is
# 10°C (observed transient 1.0°C garbage events) — then average the banks.
# Note: powermetrics' smc sampler doesn't exist on Apple Silicon, so macOS
# itself publishes no single official CPU number — die-bank mean is the
# closest standard equivalent.

BIN="$(command -v mac-temp 2>/dev/null)"
[ -n "$BIN" ] || BIN="/opt/homebrew/bin/mac-temp"

if [ ! -x "$BIN" ]; then
  sketchybar --set "${NAME:-temp}" label="--°C"
  exit 0
fi

MEAN="$("$BIN" 2>/dev/null | LC_ALL=C awk '
  /tdie/ {
    val = $NF; gsub(/[^0-9.]/, "", val)
    if (val + 0 >= 10) last[$1" "$2] = val + 0
  }
  END {
    for (k in last) { s += last[k]; n++ }
    if (n > 0) printf "%.1f", s / n
  }')"
[ -z "$MEAN" ] && exit 0

INT="$(printf '%.0f' "$MEAN" 2>/dev/null)"
case "$INT" in ''|*[!0-9]*) exit 0;; esac

LABEL="${INT}°C"

if [ "$INT" -ge 85 ]; then
  COLOR="0xFFed8796"
elif [ "$INT" -ge 75 ]; then
  COLOR="0xFFf5a97f"
elif [ "$INT" -ge 60 ]; then
  COLOR="0xFFeed49f"
else
  COLOR="0xFFa6da95"
fi

sketchybar --set "${NAME:-temp}" label="$LABEL" icon.color="$COLOR"