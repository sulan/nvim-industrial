# nvim-industrial

Industrial sound effects for Neovim. Every keystroke is a hammer strike. Every save, an explosion.

| Event | Sound |
|-------|-------|
| Typing in insert mode | Hammer on metal |
| Enter insert mode | Power drill rev |
| Leave insert mode | Steam hiss |
| Save file | Explosion |
| Open file | Rivet gun pop |
| Close buffer | Metal clatter (chainsaw) |
| Neovim startup | Factory bell |
| Neovim exit | Machinery wind-down |
| Text change (normal mode) | Metal grinder |
| Enter command mode | Gear ratchet |

## Requirements

- Neovim ≥ 0.7
- An audio player (one of):
  - **macOS**: `afplay` (built-in, no install needed)
  - **Linux**: `paplay` (PipeWire/PulseAudio), `pw-play`, `aplay`, or `mpv`

## Installation

### lazy.nvim

```lua
{
  "sulan/nvim-industrial",
  event = "VeryLazy",
  config = function()
    require("industrial").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "sulan/nvim-industrial",
  config = function()
    require("industrial").setup()
  end
}
```

## Getting the sound files

Sound files are not bundled in the repo (large binary files). Download them with the included script:

```bash
bash ~/.local/share/nvim/lazy/nvim-industrial/scripts/download_sounds.sh
```

Or clone and run directly:

```bash
git clone https://github.com/sulan/nvim-industrial
bash nvim-industrial/scripts/download_sounds.sh
```

**Requirements for the script**: `curl`, `ffmpeg` (with libmp3lame), and optionally `7za`/`7z` (`p7zip`).

```bash
# macOS
brew install ffmpeg p7zip

# Debian/Ubuntu
sudo apt install ffmpeg p7zip-full
```

The script downloads the [68 Workshop Sounds](https://opengameart.org/content/68-workshop-sounds) pack (CC0, by Celianfrog on OpenGameArt) and synthesizes the remaining sounds (steam hiss, explosion, factory shutdown) using ffmpeg. If `7z` is unavailable, all sounds are synthesized.

### Manual placement

If you prefer, place any short audio files in the `sounds/` directory with these names:

```
hammer.mp3 / hammer.ogg / hammer.wav
drill_start.mp3
steam_hiss.mp3
explosion.mp3
rivet.mp3
chainsaw.mp3
factory_bell.mp3
factory_shutdown.mp3
grinder.mp3
gear_crank.mp3
```

OGG is tried first, then WAV, then MP3.

**Free CC0 sources:**
- https://opengameart.org/content/68-workshop-sounds (the pack this plugin is built around)
- https://freesound.org (filter by CC0 license)
- https://pixabay.com/sound-effects/ (all royalty-free)

## VSCode

The same repository doubles as a VSCode extension. It shares the `sounds/` directory with the Neovim plugin.

### Requirements

- VS Code ≥ 1.60
- An audio player (same as Neovim — `afplay` on macOS, `paplay`/`aplay`/`mpv` on Linux, PowerShell on Windows)

### Installation

**From source (development):**

1. Clone the repo and open it in VS Code
2. Press `F5` to launch an Extension Development Host
3. Run the sound download script if you haven't already (see [Getting the sound files](#getting-the-sound-files) above)

**Via VSIX (manual install):**

```bash
# Build the package (requires vsce: npm install -g @vscode/vsce)
vsce package
code --install-extension nvim-industrial-0.1.0.vsix
```

**From the marketplace** (once published):

Search for "Industrial Sound Effects" by `sulan` in the Extensions panel, or:

```bash
code --install-extension sulan.nvim-industrial
```

### Events in VSCode

VSCode has no modal editing, so the event mapping is simplified:

| Event | Sound | Trigger |
|-------|-------|---------|
| Text change (typing) | Hammer | Any text edit in a file |
| Switch editor tab | Drill rev | `onDidChangeActiveTextEditor` |
| Save file | Explosion | `onDidSaveTextDocument` |
| Open file | Rivet | `onDidOpenTextDocument` |
| Close file | Chainsaw | `onDidCloseTextDocument` |
| VS Code startup | Factory bell | Extension activates |
| VS Code shutdown | Turbine spin-down | Extension deactivates |

### VSCode Settings

Add to your `settings.json`:

```json
{
  "industrial.enabled": true,
  "industrial.volume": 0.7,
  "industrial.debounceMs": 80,
  "industrial.events.textChange": "hammer",
  "industrial.events.editorFocus": "drill_start",
  "industrial.events.save": "explosion",
  "industrial.events.open": "rivet",
  "industrial.events.close": "chainsaw",
  "industrial.events.startup": "factory_bell",
  "industrial.events.shutdown": "factory_shutdown"
}
```

Set any event to `""` (empty string) to disable it:

```json
{
  "industrial.events.editorFocus": "",
  "industrial.events.close": ""
}
```

### Commands

Open the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`) and search for:

| Command | Description |
|---------|-------------|
| `Industrial: Enable Sounds` | Re-enable all sounds |
| `Industrial: Disable Sounds` | Silence all sounds |
| `Industrial: Play Sound...` | Pick and play any sound from the library |

---

## Configuration

```lua
require("industrial").setup({
  enabled  = true,
  volume   = 0.7,       -- 0.0 to 1.0
  min_interval = 80,    -- ms between replays of the same sound
  global_min_interval = 40,  -- ms between any two sounds
  debounce_ms = 80,     -- trailing-edge debounce for typing/text-change events
  sounds_dir = nil,     -- nil = auto-detect (plugin_root/sounds/)

  events = {
    insert_char   = "hammer",          -- set to false to disable
    insert_enter  = "drill_start",
    insert_leave  = "steam_hiss",
    buf_write     = "explosion",
    buf_read      = "rivet",
    buf_delete    = "chainsaw",
    vim_enter     = "factory_bell",
    vim_leave     = "factory_shutdown",
    text_changed  = "grinder",
    cmdline_enter = "gear_crank",
  },
})
```

### Disable individual events

```lua
require("industrial").setup({
  events = {
    insert_char = false,   -- silence the hammer
    cmdline_enter = false, -- no gear crank on ':'
  }
})
```

### Use a custom sounds directory

```lua
require("industrial").setup({
  sounds_dir = vim.fn.expand("~/.config/nvim/my-sounds"),
})
```

### Use different sounds for events

Point any event to a different sound name (the file must exist in `sounds_dir`):

```lua
require("industrial").setup({
  events = {
    buf_write = "factory_bell",  -- bell instead of explosion on save
  }
})
```

## API

```lua
local industrial = require("industrial")

-- Play a sound directly (useful for keymaps or testing)
industrial.play("explosion")

-- Disable all sounds and remove autocmds
industrial.disable()

-- Re-enable (re-registers autocmds)
industrial.enable()

-- Debug info
print(vim.inspect(industrial.status()))
-- { setup_done=true, enabled=true, player="afplay", sounds_dir="...", volume=0.7, ... }
```

## Troubleshooting

**No sound playing:**

1. Check status: `:lua print(vim.inspect(require("industrial").status()))`
2. Check files exist: `:lua print(vim.fn.glob(require("industrial").status().sounds_dir .. "/*"))`
3. Test your audio player directly:
   ```
   :!afplay ~/.local/share/nvim/lazy/nvim-industrial/sounds/explosion.mp3
   ```
4. Check the player field in status — if `nil`, no supported audio player was found.

**Sounds firing too often:**
Increase `min_interval` and/or `debounce_ms` in setup().

**Sounds stepping on each other:**
Increase `global_min_interval` (default 40ms).

**Volume control not working (aplay):**
`aplay` has no volume flag. Use `paplay` or `mpv` instead, or control volume at the system level.

## License

The plugin code (Lua files) is released under the **MIT License** — see [`LICENSE`](LICENSE).

The bundled sound files are all **CC0 1.0 Public Domain** — see [`sounds/CREDITS.md`](sounds/CREDITS.md) for full attribution. Workshop sounds are derived from the [68 Workshop Sounds](https://opengameart.org/content/68-workshop-sounds) pack by Celianfrog (OpenGameArt). Synthesized sounds (steam hiss, explosion, factory shutdown) were generated with ffmpeg and dedicated to the public domain by the nvim-industrial contributors.
