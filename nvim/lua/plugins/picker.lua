local function pick(command, opts)
  opts = opts or {}
  return LazyVim.pick(command, opts)
end

local layouts = require("snacks.picker.config.layouts")
layouts.full_horiz = {
  reverse = true,
  layout = {
    box = "horizontal",
    width = 0.85,
    height = 0.8,
    border = "rounded",
    {
      box = "vertical",
      { win = "list", title = " Results ", title_pos = "center", border = "none" },
      { win = "input", height = 1, border = "none", title = "{title} {live} {flags}", title_pos = "center" },
    },
    {
      win = "preview",
      title = "{preview:Preview}",
      width = 0.6,
      border = "none",
      title_pos = "center",
    },
  },
}
layouts.full_vert = {
  layout = {
    backdrop = false,
    fullscreen = true,
    box = "vertical",
    border = "rounded",
    title = "{title} {live} {flags}",
    title_pos = "center",
    { win = "input", height = 1, border = "bottom" },
    { win = "list", border = "none" },
    { win = "preview", title = "{preview}", height = 0.4, border = "top" },
  },
}

return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        layout = {
          --- Use the default layout or vertical if the window is too narrow
          preset = function()
            return vim.o.columns >= 120 and "full_horiz" or "full_vert"
          end,
        },
        win = {
          -- input window
          input = {
            keys = {
              ["<Esc>"] = { "close", mode = "i" },
              ["<C-w>"] = { "<c-s-w>", mode = { "i" }, expr = true, desc = "delete word" },
              ["<C-i>"] = { "toggle_ignored", mode = { "i", "n" } },
              ["<C-h>"] = { "toggle_hidden", mode = { "i", "n" } },
              ["<C-k>"] = { "preview_scroll_up", mode = { "i", "n" } },
              ["<C-j>"] = { "preview_scroll_down", mode = { "i", "n" } },
              -- plain cycling, not multi-select (default <Tab> is select_and_next, which
              -- marks items as you tab past them so Enter opens the marked set, not the current one)
              ["<Tab>"] = { "list_down", mode = { "i", "n" } },
              ["<S-Tab>"] = { "list_up", mode = { "i", "n" } },
            },
          },
        },
      },
    },
    keys = function()
      -- stylua: ignore
      return {
      { "<leader>ff", pick("files"), desc = "Find Files (Root Dir)" },
      { "<leader>fF", pick("files", { root = false }), desc = "Find Files (cwd)" },
      { "<leader>fg", pick("live_grep"), desc = "Grep (Root Dir)" },


      { "<leader>qf", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
      { "<leader>ml", function() Snacks.picker.loclist() end, desc = "Location List" },
      -- lsp
      { "<space>o", function() Snacks.picker.lsp_symbols({ filter = LazyVim.config.kind_filter }) end, desc = "LSP Symbols" },
      { "<space>O", function() Snacks.picker.lsp_workspace_symbols({ filter = LazyVim.config.kind_filter }) end, desc = "LSP Workspace Symbols" },
      { "<space>i", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      -- git
      { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (hunks)" },
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
    }
    end,
  },
}
