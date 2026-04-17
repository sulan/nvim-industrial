-- lua/industrial/init.lua
-- Public API. Users call require("industrial").setup(opts).

local M = {}

local _cfg = nil
local _setup_done = false

local config_mod = require("industrial.config")
local player     = require("industrial.player")
local events     = require("industrial.events")

--- Configure and activate the plugin.
--- Safe to call multiple times (re-registers autocmds with new config).
---@param opts table|nil User options (merged over defaults)
function M.setup(opts)
  _cfg = config_mod.build(opts)

  if _cfg.sounds_dir == nil then
    vim.notify(
      "nvim-industrial: could not find sounds directory.\n"
        .. "Set `sounds_dir` in your setup() call, or reinstall the plugin.",
      vim.log.levels.WARN
    )
  end

  player.setup(_cfg)
  events.setup(_cfg)

  _setup_done = true
end

--- Play a named sound immediately (bypasses debounce, respects rate limiting).
--- Useful for keymaps or testing: require("industrial").play("explosion")
---@param sound_name string
function M.play(sound_name)
  if not _setup_done then
    vim.notify("nvim-industrial: call setup() first", vim.log.levels.WARN)
    return
  end
  player.play(sound_name)
end

--- Disable all sounds and remove autocmds.
function M.disable()
  if not _setup_done then return end
  events.disable()
  _cfg.enabled = false
end

--- Re-enable sounds and re-register autocmds.
function M.enable()
  if not _setup_done then
    vim.notify("nvim-industrial: call setup() first", vim.log.levels.WARN)
    return
  end
  _cfg.enabled = true
  events.setup(_cfg)
end

--- Return a status table for debugging.
---@return table
function M.status()
  if not _setup_done then
    return { setup_done = false }
  end
  return {
    setup_done  = true,
    enabled     = _cfg.enabled,
    sounds_dir  = _cfg.sounds_dir,
    volume      = _cfg.volume,
    player      = player.player_name(),
    debounce_ms = _cfg.debounce_ms,
    min_interval = _cfg.min_interval,
  }
end

return M
