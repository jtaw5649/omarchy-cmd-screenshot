#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPT="$SRC_DIR/omarchy-cmd-screenshot"
TARGET_SCRIPT="$HOME/.local/share/omarchy/bin/omarchy-cmd-screenshot"

if [[ ! -f "$SRC_SCRIPT" ]]; then
  echo "Source script not found: $SRC_SCRIPT" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_SCRIPT")"

if [[ -f "$TARGET_SCRIPT" ]]; then
  backup_path="${TARGET_SCRIPT}.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$TARGET_SCRIPT" "$backup_path"
  echo "Backed up existing script to $backup_path"
fi

install -m 0755 "$SRC_SCRIPT" "$TARGET_SCRIPT"

echo "Installed omarchy-cmd-screenshot to $TARGET_SCRIPT"
