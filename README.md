# omarchy-cmd-screenshot (HDR-aware freeze)

This repository captures the changes made to `omarchy-cmd-screenshot` helper so HDR monitors keep the freeze/selection overlay visible while still producing a tonemapped capture.

## Why

Hyprland renders HDR outputs in a linear scRGB framebuffer. The original script used `wayfreeze` to paint that framebuffer back to the screen, which made the entire display grey and the selection rectangle black. This helper freezes the scene with `hyprpicker`, lets you choose a window or region via `slurp`, and then saves exactly that area with `grim`. The resulting PNG can be edited in Satty or copied directly to the clipboard while preserving the compositor’s tonemapping.

## Files

- `omarchy-cmd-screenshot` – the screenshot helper.
- `install.sh` – convenience script to back up your current binary and install this version.

## Dependencies

Make sure these tools are available (Arch package names shown):

- `hyprpicker`
- `grim`
- `slurp`
- `hyprctl` (from Hyprland)
- `jq`
- `satty`
- `wl-clipboard`

The install script preserves the previous copy at `omarchy-cmd-screenshot.backup-$(date …)` so you can roll back easily.

## Install

```bash
cd omarchy-cmd-screenshot
./install.sh
```

This script copies the updated helper to `~/.local/share/omarchy/bin/omarchy-cmd-screenshot` with executable permissions.

## Usage

Reuse your existing Hyprland bindings (PrintScreen, Shift+PrintScreen, etc.). When invoked, the helper:

1. Freezes the display so the visible frame stays put.
2. Lets you draw a region or click a window (`smart` mode snaps tiny selections to their containing window).
3. Captures the selection with `grim`.
4. Either opens Satty for editing/saving or pipes the PNG straight to the clipboard, depending on the binding (`... clipboard` skips Satty).
