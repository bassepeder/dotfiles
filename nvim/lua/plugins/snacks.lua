local large = {
  width = 0.95,
  height = 0.9,
}
return {
  {
    "folke/snacks.nvim",
    opts = {
      styles = {
        lazygit = large,
        blame_line = large,
        notification_history = large,
      },
      picker = {
        sources = {
          gh_issue = {},
          gh_pr = {},
          projects = {
            dev = { "~/dev" },
            max_depth = 3,
            patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "package.json", "Makefile" },
            confirm = function(picker, item)
              if not item then
                return Snacks.picker.actions.load_session(picker, item)
              end
              local old_bufs = vim.tbl_filter(function(b)
                return vim.bo[b].buflisted
              end, vim.api.nvim_list_bufs())
              Snacks.picker.actions.load_session(picker, item)
              for _, b in ipairs(old_bufs) do
                Snacks.bufdelete(b)
              end
            end,
          },
          files = { hidden = true },
          explorer = {
            include = { ".editorconfig", ".env", ".oxlintrc*", ".oxfmtrc*" },
            layout = {
              layout = {
                position = "right",
                width = 50,
                min_width = 50,
              },
            },
          },
        },
      },
      terminal = {
        wo = {
          winhighlight = "Normal:Normal",
        },
      },
      image = {},
      lazygit = {
        configure = true,
        config = {
          os = { editPreset = "nvim-remote" },
        },
      },
      gh = {
        wo = {
          winhighlight = "Normal:Normal",
        },
      },
      bigfile = {},
    },
    keys = {
      {
        "<space>e",
        function()
          Snacks.explorer.open({ cwd = LazyVim.root() })
        end,
        desc = "Explorer Snacks (root dir)",
      },
      {
        "<space>E",
        function()
          Snacks.explorer()
        end,
        desc = "Explorer Snacks (cwd)",
      },
      {
        "<leader>gi",
        function()
          Snacks.picker.gh_issue()
        end,
        desc = "GitHub Issues (open)",
      },
      {
        "<leader>gp",
        function()
          Snacks.picker.gh_pr()
        end,
        desc = "GitHub Pull Requests (open)",
      },
    },
  },
}
