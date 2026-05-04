#!/usr/bin/env bash

VM_STAT=$(vm_stat)

# Page size (usually 16384 on Apple Silicon)
PAGE_SIZE=$(echo "$VM_STAT" | grep "page size of" | awk '{print $8}')

# Extract pages
PAGES_FREE=$(echo "$VM_STAT" | grep "Pages free:" | awk '{print $3}' | tr -d '.')
PAGES_SPECULATIVE=$(echo "$VM_STAT" | grep "Pages speculative:" | awk '{print $3}' | tr -d '.')
PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active:" | awk '{print $3}' | tr -d '.')
PAGES_INACTIVE=$(echo "$VM_STAT" | grep "Pages inactive:" | awk '{print $3}' | tr -d '.')
PAGES_WIRED=$(echo "$VM_STAT" | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')
PAGES_COMPRESSED=$(echo "$VM_STAT" | grep "Pages stored in compressor:" | awk '{print $5}' | tr -d '.')

# Total memory (all pages)
TOTAL_PAGES=$((PAGES_FREE + PAGES_SPECULATIVE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_WIRED + PAGES_COMPRESSED))

# "Available" memory = free + speculative (quickly reclaimable)
AVAILABLE_PAGES=$((PAGES_FREE + PAGES_SPECULATIVE))

# "Used" memory = everything else
USED_PAGES=$((TOTAL_PAGES - AVAILABLE_PAGES))

# Percent
PERCENT=$((USED_PAGES * 100 / TOTAL_PAGES))

    # Convert to GB for display
    BYTES_USED=$((USED_PAGES * PAGE_SIZE))
    BYTES_TOTAL=$((TOTAL_PAGES * PAGE_SIZE))

    USED_GB=$(echo "scale=1; $BYTES_USED / 1024 / 1024 / 1024" | bc)

sketchybar --set "$NAME" icon="" label="${PERCENT}% | ${USED_GB}G"