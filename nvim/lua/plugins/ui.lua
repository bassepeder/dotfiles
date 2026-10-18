return {
  {
    -- background is pre-seeded in config/options.lua; this plugin only needs
    -- to catch appearance changes during the session, so skip redundant reapplies.
    "f-person/auto-dark-mode.nvim",
    lazy = false,
    opts = {
      set_dark_mode = function()
        if vim.o.background ~= "dark" then
          vim.o.background = "dark"
          vim.cmd.colorscheme(LazyVim.config.colorscheme)
        end
      end,
      set_light_mode = function()
        if vim.o.background ~= "light" then
          vim.o.background = "light"
          vim.cmd.colorscheme(LazyVim.config.colorscheme)
        end
      end,
    },
  },
  {
    "catppuccin",
    opts = {
      term_colors = true,
      flavour = "auto",
      background = { -- :h background
        light = "latte",
        dark = "mocha",
      },
      transparent_background = false,
      float = {
        transparent = false, -- enable transparent floating windows
      },
    },
  },
  {
    "folke/tokyonight.nvim",
    enabled = false,
  },

  -- several LSP clients answer hover; the empty replies would each notify
  {
    "folke/noice.nvim",
    opts = { lsp = { hover = { silent = true } } },
  },

  -- edgy
  {
    "folke/edgy.nvim",
    opts = {
      options = {
        left = { size = 30 },
        bottom = { size = 10 },
        right = { size = 50 },
        top = { size = 10 },
      },
      animate = {
        enabled = false,
      },
    },
  },

  -- bufferline
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        show_buffer_close_icons = false,
      },
    },
    keys = {
      { "<leader>1", "<Cmd>BufferLineGoToBuffer 1<CR>" },
      { "<leader>2", "<Cmd>BufferLineGoToBuffer 2<CR>" },
      { "<leader>3", "<Cmd>BufferLineGoToBuffer 3<CR>" },
      { "<leader>4", "<Cmd>BufferLineGoToBuffer 4<CR>" },
      { "<leader>5", "<Cmd>BufferLineGoToBuffer 5<CR>" },
      { "<leader>6", "<Cmd>BufferLineGoToBuffer 6<CR>" },
      { "<leader>7", "<Cmd>BufferLineGoToBuffer 7<CR>" },
      { "<leader>8", "<Cmd>BufferLineGoToBuffer 8<CR>" },
      { "<leader>9", "<Cmd>BufferLineGoToBuffer 9<CR>" },
    },
  },

  -- statusline
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections.lualine_a = {
        {
          "mode",
          fmt = function(str)
            return str:sub(1, 1)
          end,
        },
      }

      opts.sections.lualine_c[4] = {
        LazyVim.lualine.pretty_path({ length = 6 }),
      }

      -- move metals status to the left
      opts.sections.lualine_z = opts.sections.lualine_y
      opts.sections.lualine_y = opts.sections.lualine_x

      opts.sections.lualine_x = {
        "g:metals_status",
        "searchcount",
      }
    end,
  },
}
