-- lua/industrial/config.lua
local M = {}

local function default_sounds_dir()
  -- This file lives at <plugin_root>/lua/industrial/config.lua
  local this_file = debug.getinfo(1, "S").source:sub(2) -- strip leading "@"
  local plugin_root = this_file:match("^(.+)/lua/industrial/config%.lua$")
  if plugin_root then
    return plugin_root .. "/sounds"
  end
  return nil
end

M.defaults = {
  enabled = true,
  volume = 0.7,              -- 0.0 to 1.0
  min_interval = 80,         -- ms between replays of the same sound
  global_min_interval = 40,  -- ms between any two sounds (overlap guard)
  debounce_ms = 80,          -- trailing-edge debounce for high-freq events
  sounds_dir = nil,          -- nil = auto-detect from plugin root
  events = {
    insert_char     = "hammer",
    insert_enter    = "drill_start",
    insert_leave    = "steam_hiss",
    buf_write       = "explosion",
    buf_read        = "rivet",
    buf_delete      = "chainsaw",
    vim_enter       = "factory_bell",
    vim_leave       = "factory_shutdown",
    text_changed    = "grinder",
    cmdline_enter   = "gear_crank",
  },
}

-- Build a fully-resolved config by deep-merging user opts over defaults.
function M.build(user_opts)
  user_opts = user_opts or {}

  -- vim.tbl_deep_extend merges nested tables key-by-key,
  -- so { events = { buf_write = false } } only overrides buf_write.
  local cfg = vim.tbl_deep_extend("force", M.defaults, user_opts)

  if cfg.sounds_dir == nil then
    cfg.sounds_dir = default_sounds_dir()
  end

  -- Normalize: remove trailing slash
  if cfg.sounds_dir then
    cfg.sounds_dir = cfg.sounds_dir:gsub("/+$", "")
  end

  cfg.volume = math.max(0.0, math.min(1.0, cfg.volume))

  return cfg
end

return M
