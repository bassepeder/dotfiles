return {
  {
    "GustavEikaas/easy-dotnet.nvim",
    -- only load for .NET work (it pulls in nvim-dap/dap-ui, ~70ms); lazy.nvim replays FileType so LSP still attaches
    ft = { "cs", "fsharp", "razor" },
    event = { "BufReadPre *.csproj,*.fsproj,*.sln,*.slnx,*.props,*.razor,*.cshtml" },
    cmd = "Dotnet",
    dependencies = { "nvim-lua/plenary.nvim", "mfussenegger/nvim-dap", "folke/snacks.nvim" },
    keys = {
      -- Env vars (e.g. ASPNETCORE_ENVIRONMENT) come from the picked profile in Properties/launchSettings.json
      -- the command, not require("easy-dotnet").debug_default(): that one launches without the profile's env vars
      { "<leader>dd", "<cmd>Dotnet debug profile default<cr>", desc = "Debug .NET project" },
      { "<leader>dT", "<cmd>Dotnet testrunner<cr>", desc = "Toggle .NET test runner" },
      -- errors/warnings go to the quickfix list; ]q / [q to walk them
      { "<leader>cb", "<cmd>Dotnet build solution quickfix<cr>", desc = "Build .NET solution" },
      {
        "<leader>dL",
        function()
          -- the debugged app's stdout lands in nvim-dap's terminal buffer (debugger.console = "integratedTerminal")
          local buf = vim.iter(vim.api.nvim_list_bufs()):rev():find(function(b)
            return vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b):find("%[dap%-terminal%]") ~= nil
          end)
          if not buf then return vim.notify("No debug output yet", vim.log.levels.INFO) end
          local win = vim.fn.bufwinid(buf)
          if win ~= -1 then
            vim.api.nvim_win_close(win, false)
          else
            vim.cmd("belowright split")
            vim.api.nvim_win_set_buf(0, buf)
          end
        end,
        desc = "Toggle debug output",
      },
    },
    init = function()
      -- jb (below) takes ~6s per run, too slow for format-on-save; format explicitly with <leader>cf
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "cs",
        callback = function(ev) vim.b[ev.buf].autoformat = false end,
      })
    end,
    config = function()
      require("easy-dotnet").setup()
    end,
  },

  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- Roslyn ignores resharper_* keys in .editorconfig (alignment, wrapping); ReSharper's CLI honours them
        cs = { "resharper", timeout_ms = 30000 },
      },
      formatters = {
        resharper = function(bufnr)
          -- conform's default temp file sits next to the original, so Roslyn sees the class twice and leaves
          -- stale "Ambiguity between ..." errors; obj/ is excluded from compilation and jb still finds .editorconfig
          local tmpfile_format
          local proj = vim.fs.root(bufnr, function(name) return name:match("%.csproj$") end)
          if proj and vim.uv.fs_stat(proj .. "/obj") then
            tmpfile_format = proj .. "/obj/conform.$RANDOM.$FILENAME"
          end
          return {
            command = "jb",
            args = { "cleanupcode", "--profile=Built-in: Reformat Code", "--no-build", "--verbosity=ERROR", "$FILENAME" },
            stdin = false,
            tmpfile_format = tmpfile_format,
          }
        end,
      },
    },
  },
}
