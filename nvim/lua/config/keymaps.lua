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

-- toggle TS "function return type" inlay hints (off by default, see plugins/lsp.lua)
local ts_return_hints_enabled = false
local function toggle_ts_return_hints()
  ts_return_hints_enabled = not ts_return_hints_enabled
  local setting = { typescript = { inlayHints = { functionLikeReturnTypes = { enabled = ts_return_hints_enabled } } } }
  setting.javascript = setting.typescript

  -- native tsc (TS 7+ projects, see plugins/lsp.lua) reads the same options under "js/ts"
  for name, settings in pairs({ vtsls = setting, tsc = { ["js/ts"] = setting.typescript } }) do
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

  vim.notify("TS/JS return type hints " .. (ts_return_hints_enabled and "enabled" or "disabled"))
end
map("n", "<leader>tr", toggle_ts_return_hints, { desc = "Toggle TS Return Type Hints" })

-- toggle TS "parameter name" inlay hints (off by default, see plugins/lsp.lua)
local ts_param_hints_enabled = false
local function toggle_ts_param_hints()
  ts_param_hints_enabled = not ts_param_hints_enabled
  local mode = ts_param_hints_enabled and "all" or "none"
  local setting = { typescript = { inlayHints = { parameterNames = { enabled = mode } } } }
  setting.javascript = setting.typescript

  -- native tsc (TS 7+ projects, see plugins/lsp.lua) reads the same options under "js/ts"
  for name, settings in pairs({ vtsls = setting, tsc = { ["js/ts"] = setting.typescript } }) do
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

  vim.notify("TS/JS parameter name hints " .. (ts_param_hints_enabled and "enabled" or "disabled"))
end
map("n", "<leader>tp", toggle_ts_param_hints, { desc = "Toggle TS Parameter Name Hints" })
