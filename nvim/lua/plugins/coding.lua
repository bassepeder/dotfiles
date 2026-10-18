local prettier_config_cache = {} ---@type table<string, boolean>

return {
  -- autocompletion https://www.lazyvim.org/extras/coding/blink
  {
    "saghen/blink.cmp",
    dependencies = {
      {
        -- autocomplete issues and PRs from GitHub
        "Kaiser-Yang/blink-cmp-git",
      },
    },
    opts = {
      sources = {
        default = { "git", "lsp", "buffer", "path" },
        providers = {
          git = {
            module = "blink-cmp-git",
            name = "Git",
            opts = {
              commit = {
                -- removed `:` to prevent false positives
                triggers = {},
              },
            },
          },
        },
      },
      keymap = {
        preset = nil,
        ["<C-h>"] = { "select_and_accept" },
        ["<C-space>"] = { "show", "accept" },
        ["<C-c>"] = { "hide" },
        ["<up>"] = { "select_prev" },
        ["<down>"] = { "select_next" },
      },
      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 50,
          update_delay_ms = 50,
        },
        ghost_text = {
          enabled = true,
        },
      },
    },
  },

  -- brought by blink.cmp
  { "rafamadriz/friendly-snippets", enabled = false },

  { "nvim-mini/mini.pairs", enabled = true },

  -- surround
  {
    "nvim-mini/mini.surround",
    opts = {
      mappings = {
        add = "<space>sa", -- Add surrounding in Normal and Visual modes
        delete = "<space>sd", -- Delete surrounding
        find = "<space>sf", -- Find surrounding (to the right)
        find_left = "<space>sF", -- Find surrounding (to the left)
        highlight = "<space>sh", -- Highlight surrounding
        replace = "<space>sr", -- Replace surrounding
        update_n_lines = "<space>sn", -- Update `n_lines`
      },
    },
  },

  {
    "stevearc/conform.nvim",
    opts = {
      -- stop after the first applicable formatter (needed for the prettier/oxfmt fallback below)
      default_format_opts = { stop_after_first = true },
      formatters_by_ft = {
        scss = { "oxfmt" },
        -- prettier only runs when the project has its own config; falls back to oxfmt otherwise
        typescript = { "prettier", "oxfmt" },
        javascript = { "prettier", "oxfmt" },
        vue = { "prettier", "oxfmt" },
        markdown = { "oxfmt" },
        ["markdown.mdx"] = { "oxfmt" },
      },
      formatters = {
        prettier = {
          -- cached per directory: the lookup spawns node, too slow to run on every save
          condition = function(_, ctx)
            local dir = vim.fs.dirname(ctx.filename)
            if prettier_config_cache[dir] == nil then
              vim.fn.system({ "prettier", "--find-config-path", ctx.filename })
              prettier_config_cache[dir] = vim.v.shell_error == 0
            end
            return prettier_config_cache[dir]
          end,
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "prettier" } },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "css",
        "diff",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "jsonc",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "nix",
        "printf",
        "proto",
        "query",
        "regex",
        "rust",
        "scala",
        "scss",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
      },
    },
  },
}
