#!/bin/bash

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
OUTPUT_DIR="${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"

if [[ ! -d "$OUTPUT_DIR" ]]; then
  notify-send "Screenshot directory does not exist: $OUTPUT_DIR" -u critical -t 3000
  exit 1
fi

command -v hyprpicker >/dev/null 2>&1 || {
  notify-send "Screenshot failed" "hyprpicker is not installed." -u critical -t 3000
  exit 1
}

command -v grim >/dev/null 2>&1 || {
  notify-send "Screenshot failed" "grim is not installed." -u critical -t 3000
  exit 1
}

command -v slurp >/dev/null 2>&1 || {
  notify-send "Screenshot failed" "slurp is not installed." -u critical -t 3000
  exit 1
}

pkill slurp && exit 0

MODE="${1:-smart}"
PROCESSING="${2:-slurp}"

timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
filename="screenshot-${timestamp}.png"
TMPFILE=""
FREEZE_PID=""

cleanup() {
  if [[ -n "$FREEZE_PID" ]]; then
    kill "$FREEZE_PID" 2>/dev/null
    wait "$FREEZE_PID" 2>/dev/null
    FREEZE_PID=""
  fi
  if [[ -n "$TMPFILE" && -f "$TMPFILE" ]]; then
    rm -f "$TMPFILE"
  fi
}

trap cleanup EXIT

start_freeze() {
  hyprpicker -r -z >/dev/null 2>&1 &
  FREEZE_PID=$!
  sleep 0.1
}

stop_freeze() {
  if [[ -n "$FREEZE_PID" ]]; then
    kill "$FREEZE_PID" 2>/dev/null
    wait "$FREEZE_PID" 2>/dev/null
    FREEZE_PID=""
  fi
}

get_rectangles() {
  local active_workspace
  active_workspace=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')
  hyprctl monitors -j | jq -r --arg ws "$active_workspace" '.[] | select(.activeWorkspace.id == ($ws | tonumber)) | "\(.x),\(.y) \((.width / .scale) | floor)x\((.height / .scale) | floor)"'
  hyprctl clients -j | jq -r --arg ws "$active_workspace" '.[] | select(.workspace.id == ($ws | tonumber)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

capture_region() {
  local geometry="$1"
  if grim -g "$geometry" "$TMPFILE" >/dev/null 2>&1; then
    stop_freeze
    return 0
  fi
  stop_freeze
  if grim -g "$geometry" "$TMPFILE" >/dev/null 2>&1; then
    return 0
  fi
  notify-send "Screenshot failed" "grim could not capture the region." -u critical -t 3000
  exit 1
}

TMPFILE="$(mktemp --suffix .png)"

start_freeze

case "$MODE" in
  region)
    SELECTION=$(slurp 2>/dev/null)
    ;;
  windows|window)
    SELECTION=$(get_rectangles | slurp -r 2>/dev/null)
    ;;
  fullscreen|output)
    SELECTION=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x),\(.y) \((.width / .scale) | floor)x\((.height / .scale) | floor)"')
    ;;
  smart|*)
    RECTS=$(get_rectangles)
    SELECTION=$(echo "$RECTS" | slurp 2>/dev/null)
    if [[ "$SELECTION" =~ ^([0-9]+),([0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]]; then
      if (( ${BASH_REMATCH[3]} * ${BASH_REMATCH[4]} < 20 )); then
        click_x="${BASH_REMATCH[1]}"
        click_y="${BASH_REMATCH[2]}"
        while IFS= read -r rect; do
          if [[ "$rect" =~ ^([0-9]+),([0-9]+)[[:space:]]([0-9]+)x([0-9]+) ]]; then
            rect_x="${BASH_REMATCH[1]}"
            rect_y="${BASH_REMATCH[2]}"
            rect_width="${BASH_REMATCH[3]}"
            rect_height="${BASH_REMATCH[4]}"
            if (( click_x >= rect_x && click_x < rect_x+rect_width && click_y >= rect_y && click_y < rect_y+rect_height )); then
              SELECTION="${rect_x},${rect_y} ${rect_width}x${rect_height}"
              break
            fi
          fi
        done <<< "$RECTS"
      fi
    fi
    ;;
esac

[ -z "$SELECTION" ] && exit 0

if [[ "$SELECTION" =~ ^([0-9]+),([0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]]; then
  GEOMETRY="$SELECTION"
else
  notify-send "Screenshot failed" "Unable to parse capture geometry." -u critical -t 3000
  exit 1
fi

capture_region "$GEOMETRY"

if [[ "${PROCESSING,,}" == "clipboard" ]]; then
  if ! wl-copy --type image/png < "$TMPFILE"; then
    notify-send "Screenshot failed" "Unable to copy capture to the clipboard." -u critical -t 3000
    exit 1
  fi
  exit 0
fi

OUTPUT_PATH="$OUTPUT_DIR/$filename"
mv "$TMPFILE" "$OUTPUT_PATH"
TMPFILE="$OUTPUT_PATH"

satty --filename "$OUTPUT_PATH" \
  --output-filename "$OUTPUT_PATH" \
  --early-exit \
  --actions-on-enter save-to-clipboard \
  --save-after-copy \
  --copy-command 'wl-copy'
