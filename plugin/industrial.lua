-- plugin/industrial.lua
-- Startup guard. All logic lives in lua/industrial/.
-- No autocmds are registered here — nothing happens until the user calls setup().

if vim.g.loaded_industrial == 1 then
  return
end
vim.g.loaded_industrial = 1

if vim.fn.has("nvim-0.7") == 0 then
  vim.notify("nvim-industrial requires Neovim >= 0.7", vim.log.levels.WARN)
end
