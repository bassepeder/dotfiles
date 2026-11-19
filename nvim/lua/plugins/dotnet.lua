-- .NET: easy-dotnet, with a Metals-style menu (,ne) and one output panel for
-- everything that runs. Runs, watches and debug sessions each get a tab in
-- easy-dotnet's panel (,no), which stays put after the program exits.
--
--   ,ne  menu        ,nr  run         ,nd  debug       ,nw  watch
--   ,nb  build       ,nt  tests       ,no  output      ,ns  stop

-- The menu: section, label, what to run (`:Dotnet <args>` or a function), and
-- a short explanation shown next to it.
local menu = {
  { "Run", "Run startup project", "run profile default", "the project you picked last, with its launch profile" },
  { "Run", "Run a project…", "run profile", "pick the project and launch profile" },
  { "Run", "Watch startup project", "watch default", "dotnet watch: rebuilds and restarts on save" },
  { "Run", "Stop", "stop", "stop the debug session or the running program" },
  { "Debug", "Debug startup project", "debug profile default", "the project you picked last, with its launch profile" },
  { "Debug", "Debug a project…", "debug profile", "pick the project and launch profile" },
  { "Debug", "Attach to a process…", "debug attach", "attach the debugger to a running .NET process" },
  { "Build", "Build solution", "build solution quickfix", "errors and warnings go to the quickfix list" },
  { "Build", "Build a project…", "build quickfix", "pick a project; problems go to the quickfix list" },
  { "Build", "Restore packages", "restore", "dotnet restore" },
  { "Build", "Clean", "clean", "dotnet clean" },
  { "Test", "Test runner", "testrunner", "browse, run and debug tests" },
  { "Test", "Run all tests", "test solution", "dotnet test for the whole solution" },
  { "Packages", "Add NuGet package…", "add package", "search NuGet and add it to a project" },
  { "Packages", "Remove NuGet package…", "remove package", "remove a package from a project" },
  { "Packages", "Outdated packages", "outdated", "show which packages have newer versions" },
  { "Project", "User secrets", "secrets", "edit the project's secrets.json" },
  { "Project", "New project…", "new", "create a project from a template" },
  { "Project", "New file…", "createfile", "class, interface, record, ... from a template" },
  { "Project", "Choose solution…", "solution select", "when the folder has more than one" },
  { "Project", "Add project to solution…", "solution add", "dotnet sln add" },
  { "Project", "Remove project from solution…", "solution remove", "dotnet sln remove" },
  { "Project", "Forget remembered choices", "reset", "pick the startup project and profile again" },
  { "Output", "Show or hide output", "output", "run, watch and debug logs, one tab each" },
}

local function output()
  local manager = require("easy-dotnet.terminal.manager")
  if #manager.get_all() == 0 then
    return vim.notify("No .NET output yet: run or debug something first", vim.log.levels.INFO)
  end
  require("easy-dotnet.terminal").toggle()
end

-- Stops the debug session if there is one, else the running program (asking
-- which one when several are running).
local function stop()
  local dap_ok, dap = pcall(require, "dap")
  if dap_ok and dap.session() then
    dap.terminate()
    return
  end
  local Tab = require("easy-dotnet.terminal.tab")
  local running = vim.tbl_filter(function(tab)
    return tab.owned_by == "server" and Tab.is_running(tab)
  end, require("easy-dotnet.terminal.manager").get_all())
  local function stop_tab(tab)
    vim.fn.jobstop(Tab.job_id(tab))
    vim.notify("Stopped " .. tab.label, vim.log.levels.INFO)
  end
  if #running == 0 then
    vim.notify("Nothing .NET is running", vim.log.levels.INFO)
  elseif #running == 1 then
    stop_tab(running[1])
  else
    vim.ui.select(running, {
      prompt = "Stop",
      format_item = function(tab)
        return tab.label
      end,
    }, function(tab)
      if tab then
        stop_tab(tab)
      end
    end)
  end
end

local actions = { output = output, stop = stop }

local function dotnet_menu()
  local items = {}
  for _, m in ipairs(menu) do
    items[#items + 1] = { text = m[1] .. " " .. m[2] .. " " .. m[4], section = m[1], label = m[2], action = m[3], detail = m[4] }
  end
  Snacks.picker.pick({
    title = ".NET",
    items = items,
    layout = { preset = "select", layout = { width = 0.7, min_width = 90 } },
    format = function(item)
      return {
        { ("%-9s"):format(item.section), "Comment" },
        { ("%-32s"):format(item.label) },
        { item.detail, "Comment" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.schedule(function()
        if actions[item.action] then
          actions[item.action]()
        else
          vim.cmd("Dotnet " .. item.action)
        end
      end)
    end,
  })
end

-- Debug output goes to a "debug" tab in easy-dotnet's panel (next to the run
-- tabs) instead of dap-ui's console, which closes along with the session.
local function setup_debug_output()
  local dap = require("dap")
  local manager = require("easy-dotnet.terminal.manager")
  local term = require("easy-dotnet.terminal")
  local adapter = require("easy-dotnet.constants").debug_adapter_name

  -- nvim-dap keeps a finished program's terminal for the next session and then
  -- skips the hook below; a fresh session drops the old one so it doesn't
  local function drop_old()
    local tab = manager.get("debug")
    if tab and tab.buf and vim.api.nvim_buf_is_valid(tab.buf) then
      pcall(vim.api.nvim_buf_delete, tab.buf, { force = true })
    end
  end
  dap.listeners.on_config["dotnet-output"] = function(config)
    if config.type == adapter then
      drop_old()
    end
    return config
  end

  dap.defaults[adapter].terminal_win_cmd = function()
    local tab = manager.get_or_create("debug", "debug", "server")
    tab.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[tab.buf].bufhidden = "hide"
    vim.bo[tab.buf].buflisted = false
    tab.exec_name, tab.full_args = "debug", ""
    tab.last_status, tab.last_exit_code = "running", nil
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = tab.buf,
      once = true,
      callback = function()
        tab.last_status, tab.last_exit_code = "finished", vim.v.event.status
        pcall(require("easy-dotnet.terminal.tabline").render)
      end,
    })
    local code_win = vim.api.nvim_get_current_win()
    manager.set_active("debug")
    term.show()
    local panel = manager.panel_win
    if vim.api.nvim_win_is_valid(code_win) then
      vim.api.nvim_set_current_win(code_win)
    end
    return tab.buf, panel
  end

  -- dap-ui: only the sidebar (variables, breakpoints, stacks, watches) for
  -- .NET; the bottom tray would just hold an empty console. ,dr is the REPL.
  local ok, dapui = pcall(require, "dapui")
  if ok then
    dap.listeners.after.event_initialized["dapui_config"] = function(session)
      dapui.open(session.config.type == adapter and { layout = 1 } or {})
    end
  end
end

-- Runs show the panel but leave the cursor in the code, instead of jumping
-- into the program's terminal in insert mode. Wraps easy-dotnet's handler
-- before its RPC client caches it.
local function keep_focus_on_run()
  local name = "easy-dotnet.rpc.handlers.run_command_managed"
  local ok, original = pcall(require, name)
  if not ok or type(original) ~= "function" then
    return
  end
  package.loaded[name] = function(...)
    local code_win = vim.api.nvim_get_current_win()
    original(...)
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(code_win) then
      vim.api.nvim_set_current_win(code_win)
    end
  end
end

return {
  {
    "GustavEikaas/easy-dotnet.nvim",
    -- only load for .NET work (it pulls in nvim-dap/dap-ui, ~70ms); lazy.nvim replays FileType so LSP still attaches
    ft = { "cs", "fsharp", "razor" },
    event = { "BufReadPre *.csproj,*.fsproj,*.sln,*.slnx,*.props,*.razor,*.cshtml" },
    cmd = "Dotnet",
    dependencies = { "nvim-lua/plenary.nvim", "mfussenegger/nvim-dap", "folke/snacks.nvim" },
    -- Env vars (e.g. ASPNETCORE_ENVIRONMENT) come from the picked profile in Properties/launchSettings.json,
    -- hence the "profile" commands rather than require("easy-dotnet").debug_default(), which skips them
    keys = {
      { "<leader>ne", dotnet_menu, desc = ".NET menu" },
      { "<leader>nr", "<cmd>Dotnet run profile default<cr>", desc = "Run startup project" },
      { "<leader>nd", "<cmd>Dotnet debug profile default<cr>", desc = "Debug startup project" },
      { "<leader>nw", "<cmd>Dotnet watch default<cr>", desc = "Watch startup project" },
      -- errors/warnings go to the quickfix list; ]q / [q to walk them
      { "<leader>nb", "<cmd>Dotnet build solution quickfix<cr>", desc = "Build solution" },
      { "<leader>nt", "<cmd>Dotnet testrunner<cr>", desc = "Test runner" },
      { "<leader>no", output, desc = "Output (run/debug logs)" },
      { "<leader>ns", stop, desc = "Stop run/debug" },
      -- the older keys, still here for habit
      { "<leader>dd", "<cmd>Dotnet debug profile default<cr>", desc = "Debug .NET project" },
      { "<leader>dT", "<cmd>Dotnet testrunner<cr>", desc = "Toggle .NET test runner" },
      { "<leader>cb", "<cmd>Dotnet build solution quickfix<cr>", desc = "Build .NET solution" },
    },
    init = function()
      -- jb (below) takes ~6s per run, too slow for format-on-save; format explicitly with <leader>cf
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "cs",
        callback = function(ev) vim.b[ev.buf].autoformat = false end,
      })
    end,
    config = function()
      keep_focus_on_run()
      require("easy-dotnet").setup({
        -- auto-detect only knows telescope and fzf-lua, not Snacks
        picker = "snacks",
      })
      setup_debug_output()
    end,
  },

  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>n", group = ".NET" } } },
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
