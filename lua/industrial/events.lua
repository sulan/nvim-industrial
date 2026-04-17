-- lua/industrial/events.lua
-- Registers all autocmds. High-frequency events are debounced with a shared timer.

local M = {}

local player = require("industrial.player")

local augroup_id = nil
local debounce_timer = nil

-- Returns a handler that plays sound_name at most once per debounce_ms window
-- (trailing-edge: sound fires after the burst ends, not at the start).
local function debounced(sound_name, debounce_ms)
  return function()
    if debounce_timer then
      debounce_timer:stop()
    else
      debounce_timer = vim.loop.new_timer()
    end
    -- schedule_wrap moves the callback onto the main Neovim thread
    -- (libuv timer callbacks run in a different context).
    debounce_timer:start(
      debounce_ms,
      0,
      vim.schedule_wrap(function()
        player.play(sound_name)
      end)
    )
  end
end

-- Returns a handler that plays sound_name immediately on the first trigger,
-- then ignores further triggers for debounce_ms (leading-edge debounce).
-- Ideal for per-keystroke sounds where immediate feedback matters.
local function leading_debounced(sound_name, debounce_ms)
  local suppressed = false
  return function()
    if suppressed then return end
    player.play(sound_name)
    suppressed = true
    if not debounce_timer then
      debounce_timer = vim.loop.new_timer()
    end
    debounce_timer:start(debounce_ms, 0, vim.schedule_wrap(function()
      suppressed = false
    end))
  end
end

function M.setup(cfg)
  augroup_id = vim.api.nvim_create_augroup("IndustrialSounds", { clear = true })

  local ev = cfg.events

  -- Helper: register an autocmd only if the event key is not false/nil
  local function reg(event, pattern, sound_key, callback_fn)
    local sound_name = ev[sound_key]
    if sound_name == false or sound_name == nil then
      return
    end
    vim.api.nvim_create_autocmd(event, {
      group = augroup_id,
      pattern = pattern,
      callback = callback_fn or function()
        player.play(sound_name)
      end,
    })
  end

  -- ── High-frequency: debounced ─────────────────────────────────────────────

  -- InsertCharPre fires on every keystroke in insert mode.
  -- Leading-edge debounce: plays immediately on first keypress, then suppresses
  -- repeats for debounce_ms so rapid typing doesn't flood the audio queue.
  if ev.insert_char ~= false and ev.insert_char ~= nil then
    vim.api.nvim_create_autocmd("InsertCharPre", {
      group = augroup_id,
      pattern = "*",
      callback = leading_debounced(ev.insert_char, cfg.debounce_ms),
    })
  end

  -- TextChanged fires in normal mode after text modifications (dd, p, c, etc.).
  if ev.text_changed ~= false and ev.text_changed ~= nil then
    vim.api.nvim_create_autocmd("TextChanged", {
      group = augroup_id,
      pattern = "*",
      callback = debounced(ev.text_changed, cfg.debounce_ms),
    })
  end

  -- ── Low-frequency: direct play ────────────────────────────────────────────

  reg("InsertEnter", "*", "insert_enter")
  reg("InsertLeave", "*", "insert_leave")
  reg("BufWritePost", "*", "buf_write")

  -- BufReadPost: skip special buffers (terminal, quickfix, help, etc.)
  if ev.buf_read ~= false and ev.buf_read ~= nil then
    local sound_name = ev.buf_read
    vim.api.nvim_create_autocmd("BufReadPost", {
      group = augroup_id,
      pattern = "*",
      callback = function()
        if vim.bo.buftype == "" then
          player.play(sound_name)
        end
      end,
    })
  end

  -- BufDelete: skip special buffers
  if ev.buf_delete ~= false and ev.buf_delete ~= nil then
    local sound_name = ev.buf_delete
    vim.api.nvim_create_autocmd("BufDelete", {
      group = augroup_id,
      pattern = "*",
      callback = function()
        if vim.bo.buftype == "" then
          player.play(sound_name)
        end
      end,
    })
  end

  -- VimEnter: defer 200ms so startup IO doesn't compete with audio launch
  if ev.vim_enter ~= false and ev.vim_enter ~= nil then
    local sound_name = ev.vim_enter
    vim.api.nvim_create_autocmd("VimEnter", {
      group = augroup_id,
      pattern = "*",
      once = true,
      callback = function()
        vim.defer_fn(function()
          player.play(sound_name)
        end, 200)
      end,
    })
  end

  -- VimLeave: player uses detach=true so the process outlives Neovim
  reg("VimLeave", "*", "vim_leave")

  -- CmdlineEnter: fires when entering `:`, `/`, `?`, etc.
  reg("CmdlineEnter", "*", "cmdline_enter")
end

function M.disable()
  if augroup_id then
    vim.api.nvim_del_augroup_by_id(augroup_id)
    augroup_id = nil
  end
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end
end

return M
