-- Theme and font shared with kitty, delta, lazygit, bat and btop.
-- The state lives in ~/.config/theme/state and theme/theme regenerates the
-- other tools' files; :Theme and :Font are pickers on top of that script.
local M = {}

local script = vim.fn.expand("~/.config/theme/theme")
local state_file = vim.fn.expand("~/.config/theme/state")

-- not "catppuccin": Neovim 0.12 ships a built-in colorscheme by that name, which
-- shadows the plugin so lazy.nvim never loads it (and its opts never apply)
M.families = {
  catppuccin = { label = "Catppuccin", colorscheme = "catppuccin-nvim", light = "Latte", dark = "Mocha" },
  modus = { label = "Modus", colorscheme = "modus", light = "Operandi", dark = "Vivendi" },
}

function M.state()
  local state = { family = "catppuccin", mode = "system", font = "jetbrains" }
  if vim.fn.filereadable(state_file) == 1 then
    for _, line in ipairs(vim.fn.readfile(state_file)) do
      local k, v = line:match("^(%w+)=(.*)$")
      if k then
        state[k] = v
      end
    end
  end
  if not M.families[state.family] then
    state.family = "catppuccin"
  end
  return state
end

function M.colorscheme()
  return M.families[M.state().family].colorscheme
end

-- auto-dark-mode only follows the macOS appearance in "system" mode
function M.follows_system()
  return M.state().mode == "system"
end

function M.system_background()
  if vim.uv.os_uname().sysname ~= "Darwin" then
    return vim.o.background
  end
  local ok, result = pcall(vim.fn.system, { "defaults", "read", "-g", "AppleInterfaceStyle" })
  return (ok and result:match("^Dark")) and "dark" or "light"
end

function M.background(mode)
  mode = mode or M.state().mode
  return mode == "system" and M.system_background() or mode
end

-- Both colorschemes pick their light/dark variant from `background`
local function apply(family, mode)
  vim.o.background = M.background(mode)
  local cs = M.families[family].colorscheme
  -- LazyVim.config has no __newindex, so this sticks for the auto-dark-mode
  -- callbacks and autocmds that reapply LazyVim.config.colorscheme
  LazyVim.config.colorscheme = cs
  vim.cmd.colorscheme(cs)
end

-- synchronous (it only writes a few files) so the state is on disk before
-- anything, e.g. an auto-dark-mode callback, reads it again
local function run(args)
  local res = vim.system(vim.list_extend({ script }, args), { text = true }):wait(5000)
  if res.code ~= 0 then
    vim.notify(vim.trim(res.stderr or "theme script failed"), vim.log.levels.ERROR, { title = "theme" })
  end
  return res.code == 0
end

function M.set(family, mode)
  if run({ "set", family, mode }) then
    apply(family, mode)
  end
end

function M.fonts()
  local fonts = {}
  for _, line in ipairs(vim.fn.systemlist({ script, "fonts" })) do
    local id, label, guifont, size = unpack(vim.split(line, "|", { plain = true }))
    fonts[#fonts + 1] = { id = id, label = label, guifont = guifont, size = tonumber(size) }
  end
  return fonts
end

function M.guifont(font)
  return font.guifont .. ":h" .. font.size
end

function M.apply_guifont()
  local id = M.state().font
  for _, font in ipairs(M.fonts()) do
    if font.id == id then
      vim.o.guifont = M.guifont(font)
    end
  end
end

function M.set_font(font)
  if vim.g.neovide then
    vim.o.guifont = M.guifont(font)
  end
  if run({ "font", font.id }) then
    vim.notify("Font: " .. font.label .. (vim.g.neovide and "" or " (kitty)"), vim.log.levels.INFO, { title = "theme" })
  end
end

local modes = {
  { id = "system", label = "follow system" },
  { id = "light", label = "always light" },
  { id = "dark", label = "always dark" },
}

function M.pick_theme()
  local state = M.state()
  local items = {}
  for _, family in ipairs({ "catppuccin", "modus" }) do
    local f = M.families[family]
    for _, mode in ipairs(modes) do
      local variant = mode.id == "system" and (f.light .. " / " .. f.dark) or f[mode.id]
      items[#items + 1] = {
        text = f.label .. " " .. mode.label,
        family = family,
        mode = mode.id,
        label = f.label,
        variant = variant,
        mode_label = mode.label,
        current = family == state.family and mode.id == state.mode,
      }
    end
  end

  local confirmed = false
  local before =
    { colorscheme = vim.g.colors_name, background = vim.o.background, lazyvim = LazyVim.config.colorscheme }
  Snacks.picker.pick({
    title = "Theme",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return {
        { item.current and "● " or "  ", "Special" },
        { ("%-11s"):format(item.label), "Title" },
        { ("%-15s"):format(item.mode_label) },
        { item.variant, "Comment" },
      }
    end,
    -- live preview in Neovim; the other tools only change on confirm
    on_change = function(_, item)
      if item then
        apply(item.family, item.mode)
      end
    end,
    on_show = function(picker)
      for i, item in ipairs(items) do
        if item.current then
          picker.list:set_target(i)
        end
      end
    end,
    confirm = function(picker, item)
      confirmed = true
      picker:close()
      if item then
        M.set(item.family, item.mode)
      end
    end,
    on_close = function()
      if not confirmed then
        vim.schedule(function()
          vim.o.background = before.background
          LazyVim.config.colorscheme = before.lazyvim
          vim.cmd.colorscheme(before.colorscheme)
        end)
      end
    end,
  })
end

function M.pick_font()
  local current = M.state().font
  local fonts = M.fonts()
  local items = {}
  for _, font in ipairs(fonts) do
    items[#items + 1] = vim.tbl_extend("force", font, { text = font.label, current = font.id == current })
  end
  Snacks.picker.pick({
    title = "Font",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return {
        { item.current and "● " or "  ", "Special" },
        { ("%-15s"):format(item.label), "Title" },
        { item.guifont:gsub("^Symbols Nerd Font Mono,", ""):gsub(",.*", "") .. " " .. item.size .. "pt", "Comment" },
      }
    end,
    on_show = function(picker)
      for i, item in ipairs(items) do
        if item.current then
          picker.list:set_target(i)
        end
      end
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        M.set_font(item)
      end
    end,
  })
end

function M.setup()
  vim.api.nvim_create_user_command("Theme", function(args)
    if args.args == "" then
      return M.pick_theme()
    end
    local family, mode = unpack(vim.split(args.args, "%s+"))
    if not M.families[family] then
      return vim.notify("Unknown theme: " .. family, vim.log.levels.ERROR)
    end
    M.set(family, mode or "system")
  end, {
    nargs = "*",
    desc = "Pick theme (kitty, nvim, delta, lazygit, bat, btop)",
    complete = function(_, line)
      local n = #vim.split(line, "%s+")
      return n <= 2 and vim.tbl_keys(M.families) or { "system", "light", "dark" }
    end,
  })
  vim.api.nvim_create_user_command("Font", function()
    M.pick_font()
  end, { desc = "Pick font (kitty, Neovide)" })

  -- catch changes made from another Neovim or the `theme` CLI
  local seen = M.state()
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("shared_theme", { clear = true }),
    -- lazy.nvim loads a colorscheme plugin from ColorSchemePre, which only
    -- fires inside another autocmd when it's nested
    nested = true,
    callback = function()
      local now = M.state()
      if now.family ~= seen.family or now.mode ~= seen.mode then
        apply(now.family, now.mode)
      end
      if vim.g.neovide and now.font ~= seen.font then
        M.apply_guifont()
      end
      seen = now
    end,
  })
end

return M
