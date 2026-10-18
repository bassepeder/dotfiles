-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.cmd([[
  " play2
  au BufRead,BufNewFile */conf/\(*\|\)routes set filetype=play2-routes
  au BufRead,BufNewFile */conf/*.conf setf hocon
]])

-- bufferline.nvim's highlight groups only apply once (nvim_set_hl default=true),
-- so if it loads before catppuccin settles, its colors get stuck wrong. Force
-- a recolor after startup and again once bufferline itself loads.
local function fix_bufferline_theme_race()
  vim.cmd.colorscheme(LazyVim.config.colorscheme)
  if package.loaded["bufferline"] then
    pcall(function()
      require("bufferline.highlights").set_all(require("bufferline.config").update_highlights())
    end)
  end
end

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = fix_bufferline_theme_race,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(ev)
    if ev.data == "bufferline.nvim" then
      fix_bufferline_theme_race()
    end
  end,
})
