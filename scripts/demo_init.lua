-- scripts/demo_init.lua
-- Automated demo for nvim-industrial.  Plays every sound in sequence with
-- an on-screen label so viewers know exactly what triggered each one.
--
-- Usage (from the plugin root):
--   nvim -u scripts/demo_init.lua
-- or via the shell wrapper:
--   ./scripts/demo.sh

-- ── Minimal UI setup ────────────────────────────────────────────────────────

vim.opt.number         = true
vim.opt.relativenumber = false
vim.opt.cursorline     = true
vim.opt.termguicolors  = true
vim.opt.laststatus     = 2
vim.opt.showmode       = true
vim.opt.showcmd        = true

-- ── Load the plugin from the repo root ──────────────────────────────────────
-- Derive the plugin root from this file's own path so it works regardless of
-- what directory Neovim was launched from.

local this_file  = debug.getinfo(1, "S").source:sub(2)  -- strip leading "@"
local plugin_root = this_file:match("^(.+)/scripts/demo_init%.lua$")

if not plugin_root then
  vim.notify("[demo] Could not determine plugin root from: " .. this_file, vim.log.levels.ERROR)
  return
end

vim.opt.rtp:prepend(plugin_root)

local ok, industrial = pcall(require, "industrial")
if not ok then
  vim.notify("[demo] Failed to load plugin:\n" .. tostring(industrial), vim.log.levels.ERROR)
  return
end

industrial.setup()

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function feed(keys)
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes(keys, true, false, true),
    "n",
    false
  )
end

-- Persistent floating label in the top-right corner
local label_win, label_buf

local function show_label(text)
  local padded = "  " .. text .. "  "
  local width  = #padded

  if not label_buf or not vim.api.nvim_buf_is_valid(label_buf) then
    label_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(label_buf, "bufhidden", "wipe")
  end
  vim.api.nvim_buf_set_lines(label_buf, 0, -1, false, { padded })

  local opts = {
    relative = "editor",
    row      = 1,
    col      = vim.o.columns - width - 2,
    width    = width,
    height   = 1,
    style    = "minimal",
    border   = "rounded",
    zindex   = 50,
  }

  if label_win and vim.api.nvim_win_is_valid(label_win) then
    vim.api.nvim_win_set_config(label_win, opts)
  else
    label_win = vim.api.nvim_open_win(label_buf, false, opts)
  end
  vim.api.nvim_win_set_option(label_win, "winhl", "Normal:DiagnosticWarn,FloatBorder:DiagnosticWarn")
end

local function hide_label()
  if label_win and vim.api.nvim_win_is_valid(label_win) then
    vim.api.nvim_win_close(label_win, true)
    label_win = nil
  end
end

-- Run a list of {delay, fn} steps, each delay relative to the previous step.
local function run_sequence(steps, idx)
  idx = idx or 1
  if idx > #steps then return end
  vim.defer_fn(function()
    local ok, err = pcall(steps[idx].fn)
    if not ok then
      vim.notify("[demo] step " .. idx .. " error: " .. tostring(err), vim.log.levels.ERROR)
    end
    run_sequence(steps, idx + 1)
  end, steps[idx].delay)
end

-- ── Demo files ───────────────────────────────────────────────────────────────

local demo_file  = "/tmp/nvim_industrial_demo.lua"
local demo_file2 = "/tmp/nvim_industrial_demo2.lua"

local seed_lines = {
  "-- nvim-industrial demo",
  "local function greet(name)",
  "  return 'Hello, ' .. name",
  "end",
  "",
  "print(greet('factory floor'))",
}

-- ── Sequence ─────────────────────────────────────────────────────────────────
--
-- Event               → sound            trigger
-- ──────────────────────────────────────────────
-- VimEnter            → factory_bell     automatic (200 ms defer in plugin)
-- BufReadPost         → rivet            :edit a file
-- InsertEnter         → drill_start      'i' / 'o'
-- InsertCharPre       → hammer           typing chars
-- InsertLeave         → steam_hiss       <Esc>
-- CmdlineEnter        → gear_crank       ':'
-- TextChanged         → grinder          'dd' in normal mode
-- BufWritePost        → explosion        :w
-- BufReadPost         → rivet            :edit a second file
-- BufDelete           → chainsaw         :bd
-- VimLeave            → factory_shutdown :qa!

local steps = {

  -- ① factory_bell – plays automatically ~200ms after VimEnter.
  --   Give it a moment, then show the label.
  { delay = 900, fn = function()
    show_label("VimEnter → factory_bell")
  end },

  -- ② rivet – open a file
  { delay = 1800, fn = function()
    show_label("BufReadPost → rivet")
    -- Write seed content so we have lines to edit
    local f = io.open(demo_file, "w")
    if f then
      f:write(table.concat(seed_lines, "\n") .. "\n")
      f:close()
    end
    vim.cmd("edit " .. demo_file)
  end },

  -- ③ drill_start – enter insert mode
  { delay = 1600, fn = function()
    show_label("InsertEnter → drill_start")
    feed("G$o")  -- new line below last, enters Insert
  end },

  -- ④ hammer – type characters (spaced so debounce resets between words)
  { delay = 700, fn = function()
    show_label("InsertCharPre → hammer  (per keystroke)")
  end },
  { delay =  50, fn = function() feed("s") end },
  { delay = 220, fn = function() feed("t") end },
  { delay = 220, fn = function() feed("e") end },
  { delay = 220, fn = function() feed("a") end },
  { delay = 220, fn = function() feed("m") end },
  { delay = 500, fn = function() feed("(") end },  -- debounce gap
  { delay = 250, fn = function() feed("p") end },
  { delay = 220, fn = function() feed("o") end },
  { delay = 220, fn = function() feed("w") end },
  { delay = 220, fn = function() feed("e") end },
  { delay = 220, fn = function() feed("r") end },
  { delay = 500, fn = function() feed(")") end },

  -- ⑤ steam_hiss – leave insert mode
  { delay = 900, fn = function()
    show_label("InsertLeave → steam_hiss")
    feed("<Esc>")
  end },

  -- ⑥ gear_crank – enter command-line mode, then bail out
  { delay = 1300, fn = function()
    show_label("CmdlineEnter → gear_crank")
    feed(":")
  end },
  { delay = 900, fn = function()
    feed("<Esc>")
  end },

  -- ⑦ grinder – normal-mode text change (dd)
  { delay = 1100, fn = function()
    show_label("TextChanged → grinder")
    feed("3Gdd")  -- delete line 3
  end },

  -- ⑧ explosion – write file
  { delay = 1300, fn = function()
    show_label("BufWritePost → explosion")
    vim.cmd("w")
  end },

  -- ⑨ rivet again – open a second buffer
  { delay = 1600, fn = function()
    show_label("BufReadPost → rivet")
    local f = io.open(demo_file2, "w")
    if f then f:write("-- second demo file\n") f:close() end
    vim.cmd("edit " .. demo_file2)
  end },

  -- ⑩ chainsaw – delete the second buffer (goes back to first)
  { delay = 1600, fn = function()
    show_label("BufDelete → chainsaw")
    vim.cmd("bd")
  end },

  -- ⑪ factory_shutdown – quit Neovim (plugin uses detach=true so sound plays)
  { delay = 1800, fn = function()
    hide_label()
    show_label("VimLeave → factory_shutdown")
  end },
  { delay = 1200, fn = function()
    -- Clean up temp files before leaving
    os.remove(demo_file)
    os.remove(demo_file2)
    vim.cmd("qa!")
  end },
}

run_sequence(steps)
