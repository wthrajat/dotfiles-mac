#!/bin/sh
# CPU % = total per-process %CPU across all cores, divided by core count.
# ncpu is queried (not hardcoded) so this stays correct on any Mac - the old
# hardcoded /8 divisor overstated usage 1.75x on this 14-core machine.

NCPU="$(sysctl -n hw.ncpu 2>/dev/null)"
case "$NCPU" in ''|*[!0-9]*|0) NCPU=1;; esac

PCT="$(ps -A -o %cpu 2>/dev/null | LC_ALL=C awk -v n="$NCPU" '{s += $1} END {if (n > 0) printf "%.1f", s / n}')"
sketchybar --set "${NAME:-cpu}" icon="􀫥" label="${PCT}%"
