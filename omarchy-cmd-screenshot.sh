#!/bin/bash

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
OUTPUT_DIR="${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"

if [[ ! -d "$OUTPUT_DIR" ]]; then
  notify-send "Screenshot directory does not exist: $OUTPUT_DIR" -u critical -t 3000
  exit 1
fi

pkill slurp && exit 0

MODE="${1:-smart}"
PROCESSING="${2:-slurp}"

FREEZE_PID=""
TMPFILE=""
FREEZE_MONITOR_NAMES=()
FREEZE_MONITOR_SPECS=()
FREEZE_MONITOR_BITDEPTHS=()
FREEZE_MONITOR_COLORS=()
FREEZE_MONITOR_COLOR_APPLIED=()
FREEZE_ENFORCER_PID=""

wait_for_monitor_bitdepth() {
  local attempts=0
  local max_attempts=40
  local monitors_state current ready name

  (( ${#FREEZE_MONITOR_NAMES[@]} == 0 )) && return 0

  while (( attempts < max_attempts )); do
    ready=1
    monitors_state=$(hyprctl monitors -j)
    for name in "${FREEZE_MONITOR_NAMES[@]}"; do
      current=$(jq -r --arg name "$name" '.[] | select(.name == $name) | .currentFormat // ""' <<<"$monitors_state")
      if [[ "$current" =~ 2101010|16161616|FP16 ]]; then
        ready=0
        break
      fi
    done
    (( ready )) && return 0
    sleep 0.02
    ((attempts++))
  done

  return 1
}

start_freeze() {
  command -v wayfreeze >/dev/null 2>&1 || return 1

  local monitors_json monitor_json name format bitdepth width height refresh x y scale refresh_fmt scale_fmt spec
  monitors_json=$(hyprctl monitors -j)
  while read -r monitor_json; do
    name=$(jq -r '.name' <<<"$monitor_json")
    format=$(jq -r '.currentFormat // ""' <<<"$monitor_json")
    bitdepth=8
    if [[ "$format" =~ 2101010 ]]; then
      bitdepth=10
    elif [[ "$format" =~ 16161616|FP16 ]]; then
      bitdepth=16
    fi

    if [[ "$bitdepth" -ne 8 ]]; then
      width=$(jq -r '.width' <<<"$monitor_json")
      height=$(jq -r '.height' <<<"$monitor_json")
      refresh=$(jq -r '.refreshRate' <<<"$monitor_json")
      x=$(jq -r '.x' <<<"$monitor_json")
      y=$(jq -r '.y' <<<"$monitor_json")
      scale=$(jq -r '.scale' <<<"$monitor_json")
      refresh_fmt="$refresh"
      scale_fmt="$scale"
      spec="${width}x${height}@${refresh_fmt},${x}x${y},${scale_fmt}"
      local color_mode color_applied
      color_mode=$(jq -r '.colorimetry // .colorimetryState // .colorimetryPreset // empty' <<<"$monitor_json")
      if [[ -z "$color_mode" || "$color_mode" == "null" ]]; then
        if (( bitdepth > 8 )); then
          color_mode="hdr"
        else
          color_mode="srgb"
        fi
      fi

      color_applied=0
      if hyprctl keyword monitor "$name,$spec,bitdepth,8,cm,srgb" >/dev/null 2>&1; then
        color_applied=1
      elif ! hyprctl keyword monitor "$name,$spec,bitdepth,8" >/dev/null 2>&1; then
        continue
      fi

      FREEZE_MONITOR_NAMES+=("$name")
      FREEZE_MONITOR_SPECS+=("$spec")
      FREEZE_MONITOR_BITDEPTHS+=("$bitdepth")
      FREEZE_MONITOR_COLORS+=("$color_mode")
      FREEZE_MONITOR_COLOR_APPLIED+=("$color_applied")
    fi
  done < <(jq -c '.[]' <<<"$monitors_json")

  wait_for_monitor_bitdepth || sleep 0.1

  if ((${#FREEZE_MONITOR_NAMES[@]})); then
    (
      while true; do
        for i in "${!FREEZE_MONITOR_NAMES[@]}"; do
          if [[ "${FREEZE_MONITOR_COLOR_APPLIED[$i]}" == "1" ]]; then
            hyprctl keyword monitor "${FREEZE_MONITOR_NAMES[$i]},${FREEZE_MONITOR_SPECS[$i]},bitdepth,8,cm,srgb" >/dev/null 2>&1 || \
              hyprctl keyword monitor "${FREEZE_MONITOR_NAMES[$i]},${FREEZE_MONITOR_SPECS[$i]},bitdepth,8" >/dev/null 2>&1
          else
            hyprctl keyword monitor "${FREEZE_MONITOR_NAMES[$i]},${FREEZE_MONITOR_SPECS[$i]},bitdepth,8" >/dev/null 2>&1
          fi
        done
        sleep 0.1
      done
    ) &
    FREEZE_ENFORCER_PID=$!
  fi

  wayfreeze --hide-cursor >/dev/null 2>&1 &
  FREEZE_PID=$!
  sleep 0.05
}

stop_freeze() {
  if [[ -n "$FREEZE_ENFORCER_PID" ]]; then
    kill "$FREEZE_ENFORCER_PID" 2>/dev/null
    wait "$FREEZE_ENFORCER_PID" 2>/dev/null
    FREEZE_ENFORCER_PID=""
  fi
  if [[ -n "$FREEZE_PID" ]]; then
    kill "$FREEZE_PID" 2>/dev/null
    wait "$FREEZE_PID" 2>/dev/null
    FREEZE_PID=""
  fi
  if ((${#FREEZE_MONITOR_NAMES[@]})); then
    for i in "${!FREEZE_MONITOR_NAMES[@]}"; do
      if [[ "${FREEZE_MONITOR_COLOR_APPLIED[$i]}" == "1" ]]; then
        hyprctl keyword monitor "${FREEZE_MONITOR_NAMES[$i]},${FREEZE_MONITOR_SPECS[$i]},bitdepth,${FREEZE_MONITOR_BITDEPTHS[$i]},cm,${FREEZE_MONITOR_COLORS[$i]}" >/dev/null 2>&1 || \
          hyprctl keyword monitor "${FREEZE_MONITOR_NAMES[$i]},${FREEZE_MONITOR_SPECS[$i]},bitdepth,${FREEZE_MONITOR_BITDEPTHS[$i]}" >/dev/null 2>&1
      else
        hyprctl keyword monitor "${FREEZE_MONITOR_NAMES[$i]},${FREEZE_MONITOR_SPECS[$i]},bitdepth,${FREEZE_MONITOR_BITDEPTHS[$i]}" >/dev/null 2>&1
      fi
    done
  fi
  FREEZE_MONITOR_NAMES=()
  FREEZE_MONITOR_SPECS=()
  FREEZE_MONITOR_BITDEPTHS=()
  FREEZE_MONITOR_COLORS=()
  FREEZE_MONITOR_COLOR_APPLIED=()
}

get_rectangles() {
  local active_workspace=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')
  hyprctl monitors -j | jq -r --arg ws "$active_workspace" '.[] | select(.activeWorkspace.id == ($ws | tonumber)) | "\(.x),\(.y) \((.width / .scale) | floor)x\((.height / .scale) | floor)"'
  hyprctl clients -j | jq -r --arg ws "$active_workspace" '.[] | select(.workspace.id == ($ws | tonumber)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

# Select based on mode
case "$MODE" in
  region)
    start_freeze
    SELECTION=$(slurp 2>/dev/null)
    stop_freeze
    ;;
  windows)
    start_freeze
    SELECTION=$(get_rectangles | slurp -r 2>/dev/null)
    stop_freeze
    ;;
  fullscreen)
    SELECTION=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x),\(.y) \((.width / .scale) | floor)x\((.height / .scale) | floor)"')
    ;;
  smart|*)
    RECTS=$(get_rectangles)
    start_freeze
    SELECTION=$(echo "$RECTS" | slurp 2>/dev/null)
    stop_freeze

    # If the selction area is L * W < 20, we'll assume you were trying to select whichever
    # window or output it was inside of to prevent accidental 2px snapshots
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
  SEL_X="${BASH_REMATCH[1]}"
  SEL_Y="${BASH_REMATCH[2]}"
  SEL_WIDTH="${BASH_REMATCH[3]}"
  SEL_HEIGHT="${BASH_REMATCH[4]}"
else
  notify-send "Screenshot failed" "Unable to parse capture geometry." -u critical -t 3000
  exit 1
fi

command -v gpu-screen-recorder >/dev/null 2>&1 || {
  notify-send "Screenshot failed" "gpu-screen-recorder is not installed." -u critical -t 3000
  exit 1
}

REGION="${SEL_WIDTH}x${SEL_HEIGHT}+${SEL_X}+${SEL_Y}"
TMPFILE="$(mktemp --suffix .png)"
trap 'stop_freeze; [[ -n "$TMPFILE" ]] && rm -f "$TMPFILE"' EXIT

if ! gpu-screen-recorder -w region -region "$REGION" -o "$TMPFILE" >/dev/null 2>&1; then
  notify-send "Screenshot failed" "gpu-screen-recorder could not capture the region." -u critical -t 3000
  exit 1
fi

if [[ $PROCESSING == "slurp" ]]; then
  satty --filename "$TMPFILE" \
    --output-filename "$OUTPUT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png" \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --copy-command 'wl-copy'
else
  wl-copy --type image/png < "$TMPFILE"
fi
