-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- vim.opt.mouse = "" -- mouse mode is required for neovide middle-click paste
vim.opt.relativenumber = false -- Relative line numbers
vim.opt.scrolloff = 9 -- Lines of context

vim.opt.backup = false -- Don't store backup while overwriting the file
vim.opt.writebackup = false -- Don't store backup while overwriting the file
vim.opt.swapfile = false -- Use an SCM instead of swap files

vim.opt.list = false -- Don't display whitespaces

vim.opt.virtualedit = "block" -- Allow going past the end of line in visual block mode

-- for edgy: Default splitting will cause your main splits to jump when opening an edgebar.
-- To prevent this, set `splitkeep` to either `screen` or `topline`.
vim.opt.splitkeep = "screen"

vim.g.deprecation_warnings = true
vim.g.snacks_animate = false

-- Seed `background` from the real macOS appearance before lazy.nvim loads, so
-- catppuccin's `flavour = "auto"` (plugins/ui.lua) resolves correctly on the
-- first `colorscheme` call instead of Neovim's "dark" default.
if vim.uv.os_uname().sysname == "Darwin" then
  local ok, result = pcall(vim.fn.system, { "defaults", "read", "-g", "AppleInterfaceStyle" })
  vim.opt.background = (ok and result:match("^Dark")) and "dark" or "light"
end

if vim.g.neovide then
  require("config.neovide")
end
