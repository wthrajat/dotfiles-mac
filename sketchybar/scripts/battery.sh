# adapted from https://github.com/neutonfoo/dotfiles/blob/main/.config/sketchybar/plugins-laptop/battery.sh

# Single pmset call (was two); parsed in pure shell, zero extra forks.
BATT="$(pmset -g batt 2>/dev/null)"
PERCENTAGE="${BATT%%%*}"
PERCENTAGE="${PERCENTAGE##*[^0-9]}"
case "$BATT" in *'AC Power'*) CHARGING=yes;; *) CHARGING=;; esac

case "$PERCENTAGE" in ''|*[!0-9]*) exit 0;; esac

case ${PERCENTAGE} in
[8-9][0-9] | 100)
    ICON="􀛨"
    ;;
7[0-9])
    ICON="􀺸"
    ;;
[4-6][0-9])
    ICON="􀺶"
    ;;
[1-3][0-9])
    ICON="􀛩"
    ;;
[0-9])
    ICON="􀛪"
    ;;
esac

if [ -n "$CHARGING" ]; then
    ICON=""
fi

sketchybar --set battery \
    icon=$ICON \
    label="${PERCENTAGE}%"