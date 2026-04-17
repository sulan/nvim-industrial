-- lua/industrial/player.lua
-- Handles OS detection, audio player selection, async playback, and rate limiting.

local M = {}

local cfg = nil
local player = nil

-- Rate limiting state
local last_play_times = {}  -- [sound_name] = ms timestamp
local last_global_play = 0  -- ms timestamp of most recent play

-- ── OS / player detection ────────────────────────────────────────────────────

local function detect_player()
  local uname = vim.loop.os_uname().sysname

  if uname == "Darwin" then
    if vim.fn.executable("afplay") == 1 then
      return {
        name = "afplay",
        build_cmd = function(file, vol)
          return { "afplay", "-v", string.format("%.2f", vol), file }
        end,
      }
    end
  end

  if vim.fn.executable("paplay") == 1 then
    return {
      name = "paplay",
      build_cmd = function(file, vol)
        return { "paplay", "--volume=" .. math.floor(vol * 65536), file }
      end,
    }
  end

  if vim.fn.executable("pw-play") == 1 then
    return {
      name = "pw-play",
      build_cmd = function(file, _vol)
        return { "pw-play", file }
      end,
    }
  end

  if vim.fn.executable("aplay") == 1 then
    return {
      name = "aplay",
      build_cmd = function(file, _vol)
        return { "aplay", "-q", file }
      end,
    }
  end

  if vim.fn.executable("mpv") == 1 then
    return {
      name = "mpv",
      build_cmd = function(file, vol)
        return { "mpv", "--no-terminal", "--volume=" .. math.floor(vol * 100), file }
      end,
    }
  end

  return nil
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function now_ms()
  -- hrtime() is nanoseconds; convert to ms (1-second resolution is too coarse)
  return math.floor(vim.loop.hrtime() / 1e6)
end

local function is_rate_limited(sound_name)
  local t = now_ms()
  if (t - last_global_play) < cfg.global_min_interval then
    return true
  end
  local last = last_play_times[sound_name] or 0
  if (t - last) < cfg.min_interval then
    return true
  end
  return false
end

local function record_play(sound_name)
  local t = now_ms()
  last_play_times[sound_name] = t
  last_global_play = t
end

local function resolve_file(sound_name)
  if not cfg.sounds_dir then
    return nil
  end
  for _, ext in ipairs({ "ogg", "wav", "mp3" }) do
    local path = cfg.sounds_dir .. "/" .. sound_name .. "." .. ext
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end
  return nil
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.setup(user_cfg)
  cfg = user_cfg
  last_play_times = {}
  last_global_play = 0

  player = detect_player()
  if not player then
    vim.notify(
      "nvim-industrial: no audio player found.\n"
        .. "Install afplay (macOS built-in), paplay (PipeWire/PulseAudio), or mpv.",
      vim.log.levels.WARN
    )
  end

  return player ~= nil
end

function M.player_name()
  return player and player.name or nil
end

function M.play(sound_name)
  if not cfg or not cfg.enabled then
    return false
  end
  if not player then
    return false
  end
  if is_rate_limited(sound_name) then
    return false
  end

  local file = resolve_file(sound_name)
  if not file then
    return false
  end

  local argv = player.build_cmd(file, cfg.volume)

  -- detach=true: audio process survives independent of Neovim (needed for VimLeave).
  -- on_exit noop: prevents "job N exited" noise in the command area.
  vim.fn.jobstart(argv, {
    detach = true,
    on_exit = function() end,
  })

  record_play(sound_name)
  return true
end

function M.reset()
  last_play_times = {}
  last_global_play = 0
end

return M
