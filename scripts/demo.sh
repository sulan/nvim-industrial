#!/usr/bin/env bash
# scripts/demo.sh — launch the nvim-industrial automated demo
#
# Starts Neovim with a minimal init that loads the plugin and runs a timed
# sequence triggering every sound, with on-screen labels for each event.
#
# Prerequisites:
#   - Neovim 0.9+
#   - A working audio player (afplay on macOS, paplay/mpv on Linux)
#   - The plugin's sounds/ directory present (run scripts/download_sounds.sh if missing)
#
# For recording with audio (macOS):
#   1. Install BlackHole:  brew install blackhole-2ch
#   2. Create a Multi-Output Device in Audio MIDI Setup
#      (BlackHole 2ch + your speakers, set as system output)
#   3. Open OBS → add Screen Capture + Audio Output Capture (BlackHole 2ch)
#   4. Start OBS recording, then run this script
#   5. Stop OBS after Neovim exits

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Verify sounds directory exists
if [[ ! -d "$PLUGIN_ROOT/sounds" ]] || [[ -z "$(ls "$PLUGIN_ROOT/sounds"/*.mp3 2>/dev/null)" ]]; then
  echo "ERROR: sounds/ directory is empty or missing."
  echo "Run:  bash $PLUGIN_ROOT/scripts/download_sounds.sh"
  exit 1
fi

echo "Starting nvim-industrial demo..."
echo "Press Ctrl-C to abort early."
echo ""

cd "$PLUGIN_ROOT"
exec nvim -u scripts/demo_init.lua
