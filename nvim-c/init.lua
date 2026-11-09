-- nvim-c: a small, plugin-free Neovim for writing C.
-- Used inside cmode windows (scripts/cmode), where .zshrc sets NVIM_APPNAME=nvim-c.
-- Run it anywhere else with `NVIM_APPNAME=nvim-c nvim`.
--
--   <leader>m   build: `make`, or `make <file>` via make's built-in rules
--   <leader>r   `make run` if the Makefile has it, else ./<file>, in a terminal split  (:Run [cmd])
--   <leader>d   debug ./<file> with lldb              (:Debug [prog])
--   <leader>a   show the assembly for this file       (:Asm)
--   :Hex        toggle a hex view of the buffer (open binaries with `nvim -b`)
--   :Font [id]  switch this cmode window's font (a picker without an id)
--   K           man page (section 3 first, so libc)
--   gd ge       definition;  gD gE declaration;  gI implementation;  gy type definition
--   gn grr      references;  grn rename;  gK gh hover   (the main config's keys)
--   ]d [d       next/previous diagnostic, with its message;  <C-w>d  show it again
--   <leader><space> <leader>f   fuzzy-find files (fzf);  <leader>/  grep
--   <leader>, <leader>b         open buffers;  -  file browser
--   ?           this list as a cheat sheet in a popup   (:Keys)
--   q           close the quickfix list, man/help pages and the :Asm view

vim.g.mapleader = " "
vim.g.c_syntax_for_h = 1 -- .h is C, not C++

local o = vim.opt
o.number = true
-- Indentation follows the file (see detect_indent below). New files get 2
-- spaces, like ~/.clang-format (LLVM), so typing and formatting agree.
o.expandtab = true
o.shiftwidth = 2
o.softtabstop = -1 -- follow shiftwidth
o.tabstop = 8 -- how wide a real tab shows
o.list = true -- make tabs and trailing spaces visible, so a mix stands out
o.listchars = { tab = "» ", trail = "·", nbsp = "+" }
o.cinoptions = ":0,l1,t0" -- case labels at the switch, return type on its own
o.mouse = ""
o.clipboard = "unnamedplus"
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.splitright = true
o.splitbelow = true
o.signcolumn = "yes:1"
o.path = { ".", "**" }
o.wildignore:append({ "*.o", "*.a", "*.dSYM/*", ".git/*" })
o.shortmess:append("I")
-- Modus Vivendi (deuteranopia), black like the cmode terminal, upright text, and Vim's
-- classic regex syntax highlighting. The one plugin, via Neovim's built-in vim.pack.
o.termguicolors = true
o.background = "dark"
vim.pack.add({ "https://github.com/miikanissi/modus-themes.nvim" }, { confirm = false })
require("modus-themes").setup({
  style = "modus_vivendi",
  variants = { modus_vivendi = "deuteranopia" }, -- yellow/blue instead of red/green
  styles = { comments = { italic = false }, keywords = { italic = false } },
})
vim.cmd.colorscheme("modus_vivendi")

-- The 80-column limit: no guide line, just the characters past column 80
-- highlighted, in windows showing a file
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  callback = function()
    local wanted = vim.bo.buftype == ""
    if wanted and not vim.w.over80 then
      vim.w.over80 = vim.fn.matchadd("ColorColumn", [[\%>80v.\+]])
    elseif not wanted and vim.w.over80 then
      pcall(vim.fn.matchdelete, vim.w.over80)
      vim.w.over80 = nil
    end
  end,
})

-- Keep whatever indentation a file already uses: tabs stay tabs, and space
-- indentation keeps its width (the largest of 8/4/2 that ~90% of the indented
-- lines are a multiple of). An .editorconfig, which Neovim applies itself, wins.
local function detect_indent(buf)
  if next(vim.b[buf].editorconfig or {}) then
    return
  end
  local tabs, spaced, widths = 0, 0, {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 1000, false)) do
    local ws = line:match("^([ \t]+)%S")
    -- skip " * " block comment continuations, which are indented by one
    if ws and not line:match("^%s+%*") then
      if ws:find("\t") then
        tabs = tabs + 1
      else
        spaced = spaced + 1
        widths[#widths + 1] = #ws
      end
    end
  end
  local bo = vim.bo[buf]
  if tabs > spaced then
    bo.expandtab = false
    bo.shiftwidth = 0 -- follow tabstop
  elseif spaced > 0 then
    for _, w in ipairs({ 8, 4, 2 }) do
      local fits = #vim.tbl_filter(function(n)
        return n % w == 0
      end, widths)
      if fits >= 0.9 * spaced then
        bo.expandtab = true
        bo.shiftwidth = w
        return
      end
    end
  end
end
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(args)
    detect_indent(args.buf)
  end,
})

-- An Emacs mode line:  -UU-:**-  F1  bf.c          62% L218   (C E1 W2) ------
--   UU    the file is UTF-8 (-- otherwise)      :   Unix line endings (\ DOS, / Mac)
--   **    modified, %% read-only, -- neither    F1  the tab page, like Emacs' frame
--   62%   how far down the window starts (Top, Bot or All when it shows the ends)
--   (C)   the filetype, then clangd's error and warning counts
local mode_names = { c = "C", cpp = "C++", objc = "ObjC", asm = "Asm", make = "Makefile", man = "Man",
  qf = "Quickfix", netrw = "Dired", sh = "Shell-script", [""] = "Fundamental" }
function _G.cmode_modeline()
  local win = vim.g.statusline_winid
  local buf = vim.api.nvim_win_get_buf(win)
  local bo = vim.bo[buf]
  local enc = (bo.fileencoding == "" or bo.fileencoding == "utf-8") and "UU" or "--"
  local eol = ({ unix = ":", dos = "\\", mac = "/" })[bo.fileformat] or ":"
  local flags = bo.readonly and (bo.modified and "%*" or "%%") or (bo.modified and "**" or "--")

  local top, bot, last = vim.fn.line("w0", win), vim.fn.line("w$", win), vim.fn.line("$", win)
  local pos = (top == 1 and bot == last) and "All"
    or top == 1 and "Top"
    or bot == last and "Bot"
    or (math.floor((top - 1) * 100 / last) .. "%")

  local mode = bo.buftype == "terminal" and "Term"
    or mode_names[bo.filetype]
    or (bo.filetype:gsub("^%l", string.upper))
  local counts = vim.diagnostic.count(buf)
  for _, d in ipairs({ { "E", vim.diagnostic.severity.ERROR }, { "W", vim.diagnostic.severity.WARN } }) do
    if (counts[d[2]] or 0) > 0 then
      mode = mode .. " " .. d[1] .. counts[d[2]]
    end
  end

  -- files by their name; other buffers Emacs-style: *asm bf.c*, *man printf(3)*
  local full = vim.api.nvim_buf_get_name(buf)
  local name
  if bo.buftype == "terminal" then
    name = "*terminal*"
  elseif bo.buftype == "quickfix" then
    name = "*Quickfix*"
  elseif bo.buftype ~= "" and full:match("^%w+://") then
    name = "*" .. full:gsub("^(%w+)://", "%1 ") .. "*"
  elseif full == "" then
    name = "*scratch*"
  else
    name = vim.fn.fnamemodify(full, ":t")
  end
  local line = string.format("-%s-%s%s-  F%d  %-13s %4s L%%l   (%s) ", enc, eol, flags,
    vim.fn.tabpagenr(), name, pos, mode)
  -- a literal % in the result has to be %% for the statusline; %l stays an item
  return (line:gsub("%%", "%%%%"):gsub("%%%%l", "%%l")) .. "%="
end
o.laststatus = 2
o.statusline = "%!v:lua.cmode_modeline()"
vim.g.qf_disable_statusline = 1 -- the quickfix window gets the mode line too
-- the dashes that run out to the right, like Emacs
o.fillchars:append({ stl = "-", stlnc = "-" })

vim.diagnostic.config({
  virtual_text = false,
  underline = true,
  severity_sort = true,
  signs = { text = { "E", "W", "I", "H" } },
  float = { border = "single", source = true },
  -- ]d / [d show the message once they land, so Ctrl-w d is rarely needed
  jump = {
    on_jump = function(diagnostic, bufnr)
      if not diagnostic then
        return
      end
      -- The jump's own CursorMoved would close a normal popup straight away,
      -- so leave CursorMoved out and close it once the cursor really moves on
      local _, win = vim.diagnostic.open_float({
        bufnr = bufnr,
        scope = "cursor",
        focus = false,
        close_events = { "InsertEnter", "BufLeave", "WinLeave" },
      })
      if not win then
        return
      end
      local landed = vim.api.nvim_win_get_cursor(0)
      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = bufnr,
        callback = function()
          if not vim.api.nvim_win_is_valid(win) then
            return true -- already closed; drop this autocmd
          end
          local now = vim.api.nvim_win_get_cursor(0)
          if now[1] ~= landed[1] or now[2] ~= landed[2] then
            vim.api.nvim_win_close(win, true)
            return true
          end
        end,
      })
    end,
  },
})

-- clangd for definitions, references and diagnostics. Completion only when
-- asked for (<C-x><C-o>), and no semantic highlighting on top of the syntax.
vim.lsp.config("clangd", {
  cmd = { "clangd", "--header-insertion=never" },
  filetypes = { "c", "cpp", "objc" },
  root_markers = { "compile_commands.json", "compile_flags.txt", "Makefile", ".git" },
  -- used when there is no compile_commands.json (`bear -- make` writes one)
  init_options = { fallbackFlags = { "-std=c99", "-Wall", "-Wextra", "-Wpedantic" } },
})
vim.lsp.enable("clangd")
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      client.server_capabilities.semanticTokensProvider = nil
    end
  end,
})

local map = vim.keymap.set

-- K: man pages, libc (section 3) first
map("n", "K", function()
  local word = vim.fn.expand("<cword>")
  if not pcall(vim.cmd.Man, { args = { "3", word } }) and not pcall(vim.cmd.Man, word) then
    vim.notify("No manual entry for " .. word, vim.log.levels.WARN)
  end
end, { desc = "man page" })
map("n", "gK", vim.lsp.buf.hover, { desc = "clangd hover" })

-- the same go-to keys as the main config (LazyVim's plus its own ge/gE/gn/gh);
-- with several results they open in the quickfix list
local lsp = vim.lsp.buf
for keys, def in pairs({
  gd = { lsp.definition, "definition" },
  ge = { lsp.definition, "definition" },
  gD = { lsp.declaration, "declaration" },
  gE = { lsp.declaration, "declaration" },
  gI = { lsp.implementation, "implementation" },
  gy = { lsp.type_definition, "type definition" },
  gn = { lsp.references, "references" },
  gh = { lsp.hover, "hover" },
}) do
  map("n", keys, function()
    def[1]()
  end, { desc = def[2] })
end

-- build: a Makefile if there is one, else make's built-in rule for this file,
-- which compiles foo.c into foo with $CC and $CFLAGS
local function target()
  return vim.fn.expand("%:r")
end
local function has_makefile()
  return vim.fn.filereadable("Makefile") == 1 or vim.fn.filereadable("makefile") == 1
end
map("n", "<leader>m", function()
  vim.cmd("silent! write")
  vim.o.makeprg = has_makefile() and "make" or ("make " .. target())
  vim.cmd("silent make!")
  -- errors and warnings both open the list
  local problems = #vim.tbl_filter(function(item)
    return item.valid == 1
  end, vim.fn.getqflist())
  if problems > 0 then
    vim.cmd("botright cwindow")
  else
    vim.cmd("cclose")
    vim.api.nvim_echo({ { vim.o.makeprg .. ": ok" } }, false, {})
  end
end, { desc = "make" })

local function term(cmd)
  vim.cmd("botright 15split")
  vim.cmd.terminal(cmd)
  local buf = vim.api.nvim_get_current_buf()
  local pid = vim.b[buf].terminal_job_pid
  -- Closing the split stops everything it started. Neovim only stops the job
  -- itself, so with `make run` the server would outlive make; the job has its
  -- own process group, so signal all of it.
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      pcall(vim.uv.kill, -pid, "sigterm")
    end,
  })
  -- like the other panes: q closes it (out of terminal mode, after Esc Esc)
  vim.keymap.set("n", "q", "<cmd>bwipeout!<cr>", { buffer = buf, nowait = true })
  vim.cmd.startinsert()
end
-- a Makefile with a `run:` target knows how to start the program best
local function has_run_target()
  for _, name in ipairs({ "Makefile", "makefile" }) do
    if vim.fn.filereadable(name) == 1 then
      for _, line in ipairs(vim.fn.readfile(name)) do
        if line:match("^run%s*:") then
          return true
        end
      end
    end
  end
  return false
end
vim.api.nvim_create_user_command("Run", function(args)
  if args.args ~= "" then
    term(args.args)
  else
    term(has_run_target() and "make run" or ("./" .. target()))
  end
end, { nargs = "*", complete = "file" })
vim.api.nvim_create_user_command("Debug", function(args)
  term("lldb -- " .. (args.args ~= "" and args.args or ("./" .. target())))
end, { nargs = "*", complete = "file" })
map("n", "<leader>r", "<cmd>Run<cr>", { desc = "run" })
map("n", "<leader>d", "<cmd>Debug<cr>", { desc = "debug with lldb" })

-- assembly for the current file at -O2, without the assembler directives
vim.api.nvim_create_user_command("Asm", function()
  vim.cmd("silent! write")
  local file = vim.fn.expand("%:p")
  local cmd = { vim.env.CC or "cc" }
  for flag in (vim.env.CFLAGS or "-std=c99"):gmatch("%S+") do
    if not flag:match("^%-fsanitize") and not flag:match("^%-O") and flag ~= "-g" then
      cmd[#cmd + 1] = flag
    end
  end
  vim.list_extend(cmd, { "-O2", "-S", "-fno-asynchronous-unwind-tables", "-o", "-", file })
  local res = vim.system(cmd, { text = true }):wait()
  local lines = {}
  for _, line in ipairs(vim.split((res.code == 0) and res.stdout or res.stderr, "\n", { trimempty = true })) do
    -- drop directives (`.p2align 2`, `.subsections_via_symbols`), keep labels (`Lloh0:`)
    local directive = line:match("^%s*%.[%w_]+%s") or line:match("^%s*%.[%w_]+$")
    if res.code ~= 0 or not directive then
      lines[#lines + 1] = line
    end
  end

  local name = "asm://" .. vim.fn.expand("%:t")
  local buf = vim.fn.bufnr(name)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].filetype = "asm"
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true, desc = "close" })
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if vim.fn.bufwinid(buf) == -1 then
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)
    vim.wo.wrap = false
    vim.wo.colorcolumn = ""
    vim.wo.list = false -- the assembler's tabs aren't worth flagging
    vim.cmd("wincmd p")
  end
end, {})
map("n", "<leader>a", "<cmd>Asm<cr>", { desc = "assembly" })

-- q closes the panes that pop up (the quickfix list, man and help pages),
-- like in the main config. The :Asm view sets its own above.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "man", "help" },
  callback = function(args)
    vim.keymap.set("n", "q", function()
      -- the last window can't be closed; then just drop the buffer
      if not pcall(vim.cmd.close) then
        vim.cmd.bdelete()
      end
    end, { buffer = args.buf, nowait = true, desc = "close" })
  end,
})

-- In the quickfix/location list, Tab and Shift-Tab step to the next/previous
-- entry and show it in the code window, keeping the cursor in the list.
-- They wrap around at the ends.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(args)
    local loclist = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].loclist == 1
    local function step(next, wrap)
      local p = loclist and "l" or "c"
      return function()
        if not pcall(vim.cmd, p .. next) then
          pcall(vim.cmd, p .. wrap)
        end
        vim.cmd("wincmd p")
      end
    end
    vim.keymap.set("n", "<Tab>", step("next", "first"), { buffer = args.buf, desc = "next entry" })
    vim.keymap.set("n", "<S-Tab>", step("prev", "last"), { buffer = args.buf, desc = "previous entry" })
  end,
})

-- hex view: the classic xxd round trip
vim.api.nvim_create_user_command("Hex", function()
  if vim.b.hex then
    vim.cmd("%!xxd -r")
    vim.b.hex = false
    vim.bo.filetype = vim.b.hex_ft or ""
  else
    vim.b.hex_ft = vim.bo.filetype
    vim.cmd("%!xxd")
    vim.b.hex = true
    vim.bo.filetype = "xxd"
  end
end, {})

-- :Font: this cmode window's font, via `cmode font` (fonts from `theme fonts`)
local cmode = vim.fn.expand("~/.local/bin/cmode")
local function fonts()
  local list = {}
  for _, line in ipairs(vim.fn.systemlist({ vim.fn.expand("~/.local/bin/theme"), "fonts" })) do
    local id, label = line:match("^([^|]+)|([^|]+)")
    if id then
      list[#list + 1] = { id = id, label = label }
    end
  end
  return list
end
local function set_font(id)
  local res = vim.system({ cmode, "font", id }, { text = true }):wait()
  if res.code ~= 0 then
    vim.notify(vim.trim(res.stderr), vim.log.levels.ERROR)
  else
    vim.api.nvim_echo({ { "font: " .. id } }, false, {})
  end
end
vim.api.nvim_create_user_command("Font", function(args)
  if not vim.env.CMODE_FONT_FILE then
    return vim.notify(":Font only works inside a cmode window", vim.log.levels.WARN)
  end
  if args.args ~= "" then
    return set_font(args.args)
  end
  local current = vim.trim(vim.fn.system({ cmode, "font" }))
  vim.ui.select(fonts(), {
    prompt = "Font",
    format_item = function(f)
      return (f.id == current and "* " or "  ") .. f.label
    end,
  }, function(f)
    if f then
      set_font(f.id)
    end
  end)
end, {
  nargs = "?",
  complete = function()
    return vim.tbl_map(function(f)
      return f.id
    end, fonts())
  end,
})

-- ? : a cheat sheet in a popup, since there's no which-key here
local cheatsheet = {
  "",
  " Space is the leader: press Space, then the key.",
  "",
  " BUILD AND RUN",
  "   Space m         build (make, or make <file>)",
  "   Space r         run: make run, or else ./<file>  (:Run [cmd])",
  "   Space d         debug ./<file> with lldb       (:Debug [prog])",
  "   Space a         the file's assembly beside it  (:Asm)",
  "   Esc Esc         leave a terminal split (:q closes it)",
  "",
  " LISTS (build errors, references)",
  "   Tab / S-Tab     next / previous entry, shown in the code",
  "   ]q / [q         the same, from anywhere",
  "   Enter           jump to the entry",
  "   q               close the list (also man pages and :Asm)",
  "",
  " READING CODE",
  "   K               man page for the word (libc first)",
  "   gh or gK        clangd: type, signature, docs",
  "   gd or ge        go to the definition",
  "   Ctrl-o          jump back",
  "   gD or gE        go to the declaration",
  "   gI              go to the implementation",
  "   gy              go to the type definition",
  "   gn or grr       list everywhere it's used",
  "   grn             rename it everywhere",
  "",
  " PROBLEMS (the E and W in the margin)",
  "   ]d              next error or warning, and its message",
  "   [d              previous one, and its message",
  "   Ctrl-w d        show the message again",
  "",
  " TYPING",
  "   Ctrl-x Ctrl-o   complete the word",
  "   Ctrl-n / Ctrl-p move through the suggestions",
  "",
  " FINDING (Tab / S-Tab move, Enter opens, Esc cancels)",
  "   Space Space     files (also Space f)",
  "   Space /         grep the project as you type",
  "   Space ,         open buffers (also Space b)",
  "   -               file browser (Enter opens, - goes up)",
  "",
  " COMMANDS",
  "   :Font [id]      this window's font",
  "   :Hex            hex view",
  "",
  " q, Esc or ? closes this. Search backwards with / and then N.",
  "",
}
local function show_keys()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, cheatsheet)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local ns = vim.api.nvim_create_namespace("nvim_c_keys")
  for i, line in ipairs(cheatsheet) do
    if line:match("^ %u%u+") then -- the section headings
      vim.hl.range(buf, ns, "Title", { i - 1, 0 }, { i - 1, #line })
    end
  end
  local width = 2
  for _, line in ipairs(cheatsheet) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 1)
  end
  width = math.min(width, vim.o.columns - 4)
  local height = math.min(#cheatsheet, vim.o.lines - 4)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "single",
    title = " nvim-c keys ",
    title_pos = "center",
  })
  for _, key in ipairs({ "q", "<esc>", "?" }) do
    vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = buf, nowait = true })
  end
end
vim.api.nvim_create_user_command("Keys", show_keys, {})
map("n", "?", show_keys, { desc = "cheat sheet" })

-- Fuzzy finding with the fzf command in a floating terminal, no plugin.
-- run: the shell command fzf reads from; picked(line) gets the chosen line.
local function fzf(title, run, fzf_args, picked)
  local out = vim.fn.tempname()
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.75)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "single",
    title = " " .. title .. " ",
    title_pos = "center",
  })
  -- a single Esc goes straight to fzf (which cancels), not to the <esc><esc> map
  vim.keymap.set("t", "<esc>", "<esc>", { buffer = buf, nowait = true })
  -- input on top, results below it, and Tab / Shift-Tab to move through them
  -- (wrapping around), like Tab in the quickfix list
  local keys = "--layout=reverse --cycle --bind 'tab:down,shift-tab:up' "
  vim.fn.jobstart(run .. " | fzf " .. keys .. fzf_args .. " > " .. vim.fn.shellescape(out), {
    term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        local choice = code == 0 and vim.fn.filereadable(out) == 1 and vim.fn.readfile(out)[1]
        os.remove(out)
        if choice and choice ~= "" then
          picked(choice)
        end
      end)
    end,
  })
  vim.cmd.startinsert()
end

-- previews in the editor's own colours rather than the shared bat theme
local bat = "bat --color=always --style=numbers --theme=modus-vivendi-deuteranopia"
local preview = "--preview '" .. bat .. " {} 2>/dev/null || cat {}'"
local function find_files()
  fzf("Files", "rg --files --hidden -g '!.git'", preview, function(file)
    vim.cmd.edit(vim.fn.fnameescape(file))
  end)
end

-- search the project as you type; rg runs again on every keystroke
local function grep()
  local rg = "rg --column --line-number --no-heading --color=always --smart-case -- {q} || true"
  fzf("Grep", ":", table.concat({
    "--disabled --ansi --delimiter :",
    "--bind " .. vim.fn.shellescape("start:reload:" .. rg),
    "--bind " .. vim.fn.shellescape("change:reload:" .. rg),
    "--preview '" .. bat .. " --highlight-line {2} {1}'",
    "--preview-window '+{2}/2'",
  }, " "), function(line)
    local file, lnum, col = line:match("^(.-):(%d+):(%d+):")
    if file then
      vim.cmd.edit(vim.fn.fnameescape(file))
      vim.api.nvim_win_set_cursor(0, { tonumber(lnum), tonumber(col) - 1 })
    end
  end)
end

local function buffers()
  local names = {}
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.name ~= "" then
      names[#names + 1] = vim.fn.fnamemodify(b.name, ":.")
    end
  end
  local list = vim.fn.tempname()
  vim.fn.writefile(names, list)
  fzf("Buffers", "cat " .. vim.fn.shellescape(list), preview, function(name)
    os.remove(list)
    vim.cmd.buffer(vim.fn.fnameescape(name))
  end)
end

map("n", "<leader><space>", find_files, { desc = "find file" })
map("n", "<leader>f", find_files, { desc = "find file" })
map("n", "<leader>/", grep, { desc = "grep" })
map("n", "<leader>,", buffers, { desc = "buffers" })
map("n", "<leader>b", buffers, { desc = "buffers" })
map("n", "-", "<cmd>Explore<cr>", { desc = "file browser" })
map("n", "<esc>", "<cmd>nohlsearch<cr>")
map("t", "<esc><esc>", "<c-\\><c-n>")
