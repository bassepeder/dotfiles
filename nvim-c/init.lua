-- nvim-c: a small, plugin-free Neovim for writing C.
-- Used inside cmode windows (scripts/cmode), where .zshrc sets NVIM_APPNAME=nvim-c.
-- Run it anywhere else with `NVIM_APPNAME=nvim-c nvim`.
--
--   <leader>m   build: `make`, or `make <file>` via make's built-in rules
--   <leader>r   run ./<file> in a terminal split      (:Run [cmd])
--   <leader>d   debug ./<file> with lldb              (:Debug [prog])
--   <leader>a   show the assembly for this file       (:Asm)
--   :Hex        toggle a hex view of the buffer (open binaries with `nvim -b`)
--   K           man page (section 3 first, so libc)
--   gK          clangd hover;  <C-]> definition;  grr references;  grn rename
--   ]d [d       next/previous diagnostic;  <C-w>d  show it
--   <leader>f   :find (searches the tree);  <leader>b  pick a buffer;  -  file browser

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
o.colorcolumn = "80"
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
-- Modus Vivendi, black like the cmode terminal, upright text, and Vim's
-- classic regex syntax highlighting. The one plugin, via Neovim's built-in vim.pack.
o.termguicolors = true
o.background = "dark"
vim.pack.add({ "https://github.com/miikanissi/modus-themes.nvim" }, { confirm = false })
require("modus-themes").setup({
  style = "modus_vivendi",
  styles = { comments = { italic = false }, keywords = { italic = false } },
})
vim.cmd.colorscheme("modus_vivendi")

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

-- file:line:col and diagnostic counts, nothing else
function _G.cmode_status()
  local counts = vim.diagnostic.count(0)
  local e = counts[vim.diagnostic.severity.ERROR] or 0
  local w = counts[vim.diagnostic.severity.WARN] or 0
  local diag = (e > 0 and ("E" .. e .. " ") or "") .. (w > 0 and ("W" .. w .. " ") or "")
  return diag
end
o.laststatus = 2
o.statusline = " %f %m%r%=%{v:lua.cmode_status()}%l:%c "

vim.diagnostic.config({
  virtual_text = false,
  underline = true,
  severity_sort = true,
  signs = { text = { "E", "W", "I", "H" } },
  float = { border = "single", source = true },
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
  vim.cmd.startinsert()
end
vim.api.nvim_create_user_command("Run", function(args)
  term(args.args ~= "" and args.args or ("./" .. target()))
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
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if vim.fn.bufwinid(buf) == -1 then
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)
    vim.wo.wrap = false
    vim.wo.colorcolumn = ""
    vim.cmd("wincmd p")
  end
end, {})
map("n", "<leader>a", "<cmd>Asm<cr>", { desc = "assembly" })

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

map("n", "<leader>f", ":find ", { desc = "find file" })
map("n", "<leader>b", ":ls<cr>:b ", { desc = "buffer" })
map("n", "-", "<cmd>Explore<cr>", { desc = "file browser" })
map("n", "<esc>", "<cmd>nohlsearch<cr>")
map("t", "<esc><esc>", "<c-\\><c-n>")
