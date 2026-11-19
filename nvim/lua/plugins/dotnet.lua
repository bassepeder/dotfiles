-- .NET: easy-dotnet, with a Metals-style menu (,ne) and one floating log
-- window for everything that runs. Runs, watches and debug sessions each get
-- a tab in it (,dl), and their output stays after the program exits.
--
--   ,ne  menu        ,nr  run         ,nd  debug       ,nw  watch
--   ,nb  build       ,nt  tests       ,ns  stop        ,dl  log
--   ,dm  menu (same as ,ne)

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
  { "Log", "Show or hide the log", "output", "run, watch and debug output, one tab each (,dl)" },
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

-- whether a debug session (or the one that started it) is easy-dotnet's
local function is_dotnet(session)
  while session and session.parent do
    session = session.parent
  end
  return session ~= nil and session.config.type == "easy-dotnet"
end

-- ,du: dap-ui on or off. Closes everything that's open (the bottom tray
-- included), and opens only the sidebar while debugging .NET.
local function toggle_dapui()
  local dapui = require("dapui")
  local open = vim.iter(vim.api.nvim_list_wins()):any(function(win)
    return vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match("^dapui_") ~= nil
  end)
  if open then
    dapui.close()
  else
    dapui.open(is_dotnet(require("dap").session()) and { layout = 1 } or {})
  end
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
    manager.set_active("debug")
    term.show()
    return tab.buf, manager.panel_win
  end

  -- easy-dotnet's debugger warns about its own Release-built startup hook on
  -- every session; keep that out of the REPL
  dap.defaults[adapter].on_output = function(_, body)
    if body.category ~= "telemetry" and not body.output:find("EasyDotnet.StartupHook", 1, true) then
      require("dap.repl").append(body.output, "$", { newline = false })
    end
  end

  -- dap-ui stays closed for .NET (the log has the output); ,du opens its
  -- sidebar (variables, breakpoints, stacks, watches), ,dr the REPL
  local ok, dapui = pcall(require, "dapui")
  if ok then
    dap.listeners.after.event_initialized["dapui_config"] = function(session)
      if not is_dotnet(session) then
        dapui.open({})
      end
    end
  end
end

-- easy-dotnet drops you into a run's terminal in insert mode, where keys go to
-- the program; stay in normal mode instead. Wraps its handler before its RPC
-- client caches it.
local function normal_mode_on_run()
  local name = "easy-dotnet.rpc.handlers.run_command_managed"
  local ok, original = pcall(require, name)
  if not ok or type(original) ~= "function" then
    return
  end
  package.loaded[name] = function(...)
    original(...)
    vim.cmd("stopinsert")
  end
end

-- The log as a floating window instead of easy-dotnet's bottom split. Its
-- show/hide/toggle are replaced, so runs, watches, debug sessions,
-- :Dotnet terminal and its hide-on-breakpoint all use the float.
local function setup_log_float()
  local term = require("easy-dotnet.terminal")
  local manager = require("easy-dotnet.terminal.manager")
  local Tab = require("easy-dotnet.terminal.tab")
  local tabline = require("easy-dotnet.terminal.tabline")

  local function is_open()
    return manager.panel_win and vim.api.nvim_win_is_valid(manager.panel_win)
  end

  local function geometry()
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.7)
    return {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2) - 1,
      col = math.floor((vim.o.columns - width) / 2),
    }
  end

  -- what killed programs exit with: ,ns (hangup), Ctrl-C, the debugger
  -- stopping it (kill), SIGTERM; anything else non-zero is a failure
  local stopped = { [129] = true, [130] = true, [137] = true, [143] = true }

  local function status(tab)
    local code = tab.last_exit_code
    if Tab.is_running(tab) then
      return "running"
    elseif code == nil then
      return tab.last_status == "finished" and "finished" or "idle"
    elseif code == 0 then
      return "finished"
    end
    return stopped[code] and "stopped" or ("failed, exit code " .. code)
  end

  -- title: the tab shown and its state; footer: all tabs and the keys
  local function decorate()
    if not is_open() then
      return
    end
    local active = manager.active_id and manager.get(manager.active_id)
    local names = vim.tbl_map(function(tab)
      return tab.id == manager.active_id and ("[" .. tab.label .. "]") or tab.label
    end, manager.get_all())
    pcall(vim.api.nvim_win_set_config, manager.panel_win, {
      title = active and (" .NET log · %s · %s "):format(active.label, status(active)) or " .NET log ",
      title_pos = "center",
      footer = (" %s    Tab next · q hide · ,ns stop "):format(table.concat(names, "  ")),
      footer_pos = "center",
    })
  end

  local function cycle(dir)
    local tabs = manager.get_all()
    for i, tab in ipairs(tabs) do
      if tab.id == manager.active_id and #tabs > 1 then
        manager.set_active(tabs[(i - 1 + dir) % #tabs + 1].id)
        return
      end
    end
  end

  local function map_keys(buf)
    local function map(lhs, fn)
      vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true })
    end
    map("q", term.hide)
    map("<Esc>", term.hide)
    map("<Tab>", function()
      cycle(1)
    end)
    map("<S-Tab>", function()
      cycle(-1)
    end)
  end

  term.show = function()
    if is_open() then
      vim.api.nvim_set_current_win(manager.panel_win)
      return
    end
    local ok, runner = pcall(require, "easy-dotnet.test-runner.render")
    if ok and runner.win and vim.api.nvim_win_is_valid(runner.win) then
      runner.hide()
    end
    if #manager.get_all() == 0 then
      manager.active_id = manager.new_user_terminal().id
    end
    local active = manager.get(manager.active_id) or manager.get_all()[1]
    manager.active_id = active.id
    Tab.ensure_buf(active)
    local config = vim.tbl_extend("force", geometry(), { border = "rounded", style = "minimal" })
    local win = vim.api.nvim_open_win(active.buf, true, config)
    manager.panel_win = win
    vim.wo[win].winfixbuf = true
    manager._on_tab_activated = function(tab)
      map_keys(tab.buf)
      decorate()
    end
    map_keys(active.buf)
    vim.cmd("normal! G") -- follow the output
    decorate()
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(win),
      once = true,
      callback = function()
        manager.panel_win = nil
      end,
    })
  end

  term.hide = function()
    if is_open() then
      vim.api.nvim_win_close(manager.panel_win, false)
    end
  end

  -- open and focused: hide; open behind another window: focus it; else show
  term.toggle = function()
    if is_open() and vim.api.nvim_get_current_win() == manager.panel_win then
      term.hide()
    else
      term.show()
    end
  end

  -- easy-dotnet re-renders its tabline whenever a tab starts or stops; keep
  -- the float's title and footer up to date at the same moments
  local render = tabline.render
  tabline.render = function(...)
    pcall(render, ...)
    decorate()
  end

  local group = vim.api.nvim_create_augroup("dotnet-log", { clear = true })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if is_open() then
        vim.api.nvim_win_set_config(manager.panel_win, geometry())
      end
    end,
  })

  -- going back to the code (a click, <C-w>, a breakpoint) hides the log, so
  -- it never sits on top of what you're editing; ,dl brings it back
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if is_open() and vim.api.nvim_win_get_config(0).relative == "" then
        vim.schedule(function()
          if vim.api.nvim_get_current_win() ~= manager.panel_win then
            term.hide()
          end
        end)
      end
    end,
  })

  -- the log opens before the program starts; put the cursor on its last line
  -- once it does, which makes Neovim follow the output (scroll up to pause,
  -- G to follow again)
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(ev)
      vim.schedule(function()
        if is_open() and vim.api.nvim_win_get_buf(manager.panel_win) == ev.buf then
          vim.api.nvim_win_call(manager.panel_win, function()
            vim.cmd("normal! G")
          end)
        end
      end)
    end,
  })

  -- easy-dotnet's server reports every exit as an error, ,ns included; the
  -- notices below replace it
  local notifications = require("easy-dotnet.rpc.notification-handler")
  local handle = notifications.handler
  notifications.handler = function(client, method, params)
    local message = method == "displayError" and type(params) == "table" and params.message
    if type(message) == "string" and message:match(" exited with code %-?%d+$") then
      return
    end
    return handle(client, method, params)
  end

  -- with the log hidden, say when a program ends, and make ,dl show its tab
  vim.api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function(ev)
      local code = vim.v.event.status
      local tab = vim.iter(manager.get_all()):find(function(t)
        return t.buf == ev.buf and t.owned_by == "server"
      end)
      if not tab or stopped[code] then
        return
      end
      vim.schedule(function()
        if is_open() then
          if manager.active_id ~= tab.id and code ~= 0 then
            vim.notify(("%s failed with exit code %d (Tab to see it)"):format(tab.label, code), vim.log.levels.ERROR)
          end
          return
        end
        manager.set_active(tab.id)
        if code == 0 then
          vim.notify(tab.label .. " finished (,dl for the log)", vim.log.levels.INFO)
        else
          vim.notify(("%s failed with exit code %d (,dl for the log)"):format(tab.label, code), vim.log.levels.ERROR)
        end
      end)
    end,
  })
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
      { "<leader>dm", dotnet_menu, desc = ".NET menu" },
      { "<leader>nr", "<cmd>Dotnet run profile default<cr>", desc = "Run startup project" },
      { "<leader>nd", "<cmd>Dotnet debug profile default<cr>", desc = "Debug startup project" },
      { "<leader>nw", "<cmd>Dotnet watch default<cr>", desc = "Watch startup project" },
      -- errors/warnings go to the quickfix list; ]q / [q to walk them
      { "<leader>nb", "<cmd>Dotnet build solution quickfix<cr>", desc = "Build solution" },
      { "<leader>nt", "<cmd>Dotnet testrunner<cr>", desc = "Test runner" },
      { "<leader>ns", stop, desc = "Stop run/debug" },
      { "<leader>dl", output, desc = ".NET log" },
      -- the older build key, still here for habit
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
      normal_mode_on_run()
      require("easy-dotnet").setup({
        -- auto-detect only knows telescope and fzf-lua, not Snacks
        picker = "snacks",
        -- keep the log after a program exits instead of closing it a second later
        managed_terminal = { auto_hide = false },
      })
      setup_debug_output()
      setup_log_float()
    end,
  },

  -- ,dl is the .NET log; LazyVim has it as dap's "Run Last"
  {
    "mfussenegger/nvim-dap",
    keys = { { "<leader>dl", false } },
  },

  {
    "rcarriga/nvim-dap-ui",
    keys = { { "<leader>du", toggle_dapui, desc = "Dap UI" } },
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
