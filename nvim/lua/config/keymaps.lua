-- Keymaps are automatically loaded on the VeryLazy event                                                                   █
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua         █
-- Add any additional keymaps here

require("config.keymaps_lazyvim")

local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- toggles for TS inlay hints that are off by default (see plugins/lsp.lua)
-- `inlay_hints(on)` returns the typescript.inlayHints table for that state
local function ts_hint_toggle(label, inlay_hints)
  local enabled = false
  return function()
    enabled = not enabled
    local ts = { inlayHints = inlay_hints(enabled) }

    -- native tsc (TS 7+ projects, see plugins/lsp.lua) reads the same options under "js/ts"
    for name, settings in pairs({ vtsls = { typescript = ts, javascript = ts }, tsc = { ["js/ts"] = ts } }) do
      -- persist so clients started later (e.g. in another project) keep the choice
      vim.lsp.config(name, { settings = settings })

      for _, client in ipairs(vim.lsp.get_clients({ name = name })) do
        client.settings = vim.tbl_deep_extend("force", client.settings or {}, settings)
        client:notify("workspace/didChangeConfiguration", { settings = client.settings })
      end
    end

    -- force a re-request so the change shows up immediately instead of on next edit
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.lsp.inlay_hint.is_enabled({ bufnr = buf }) then
        vim.lsp.inlay_hint.enable(false, { bufnr = buf })
        vim.lsp.inlay_hint.enable(true, { bufnr = buf })
      end
    end

    vim.notify("TS/JS " .. label .. " hints " .. (enabled and "enabled" or "disabled"))
  end
end

map("n", "<leader>tr", ts_hint_toggle("return type", function(on)
  return { functionLikeReturnTypes = { enabled = on } }
end), { desc = "Toggle TS Return Type Hints" })
map("n", "<leader>tp", ts_hint_toggle("parameter name", function(on)
  return { parameterNames = { enabled = on and "all" or "none" } }
end), { desc = "Toggle TS Parameter Name Hints" })
