return {
  -- jump motions (disabled: was overriding native s/S substitute - see chat notes)
  {
    "folke/flash.nvim",
    enabled = false,
  },

  { "folke/todo-comments.nvim", enabled = false },

  {
    "folke/trouble.nvim",
    opts = {
      auto_close = true, -- auto close when there are no items
      auto_refresh = true, -- auto refresh when open
      modes = {
        cascade = {
          mode = "diagnostics", -- inherit from diagnostics mode
          auto_open = false, -- auto open when there are items
          filter = function(items)
            local severity = vim.diagnostic.severity.HINT
            for _, item in ipairs(items) do
              severity = math.min(severity, item.severity)
            end
            return vim.tbl_filter(function(item)
              return item.severity == severity
            end, items)
          end,
        },
      },
    },
    keys = {
      { "<space>d", "<cmd>Trouble cascade toggle<cr>", desc = "Diagnostics (Trouble)" },
      {
        "<space><space>",
        "<cmd>Trouble cascade open focus=true<cr>",
        desc = "Diagnostics (Trouble)",
      },
    },
  },
}
