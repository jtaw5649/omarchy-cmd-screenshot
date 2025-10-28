# omarchy-cmd-screenshot (HDR-aware freeze)

This repository captures the changes made to `omarchy-cmd-screenshot` helper so HDR monitors keep the freeze/selection overlay visible while still producing a tonemapped capture.

## Why

Hyprland renders HDR outputs in a linear scRGB framebuffer. The original script used `wayfreeze` to paint that framebuffer back to the screen, which made the entire display grey and the selection rectangle black. We now:

1. Temporarily force all monitors to 8-bit mode before freezing.
2. Use `wayfreeze --hide-cursor` so the screen locks immediately when the shortcut is pressed.
3. Restore each monitor's original bit-depth after the selection ends.
4. Capture the actual region with `gpu-screen-recorder` (still tonemapped for the saved image) and pass it to Satty or the clipboard.

## Files

- `omarchy-cmd-screenshot.sh` – the updated screenshot script.
- `install.sh` – convenience script to back up your current binary and install this version.

## Dependencies

Make sure these tools are available (Arch package names shown):

- `gpu-screen-recorder`
- `wayfreeze`
- `imv`
- `hyprctl` (from Hyprland)
- `jq`
- `satty`

The install script preserves the previous copy at `omarchy-cmd-screenshot.backup-$(date …)` so you can roll back easily.

## Install

```bash
cd omarchy-cmd-screenshot
./install.sh
```

This script copies the updated helper to `~/.local/share/omarchy/bin/omarchy-cmd-screenshot` with executable permissions.

## Usage

Use your existing Hyprland bindings (PrintScreen, Shift+PrintScreen, etc.). When you press the hotkey the screen freezes instantly, the selection box is visible, and the resulting capture is tonemapped via `gpu-screen-recorder`.
