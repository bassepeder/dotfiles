-- This file replaces LazyVim/lua/lazyvim/config/keymaps.lua
local map = LazyVim.safe_keymap_set

-- Move in windows using <ctrl> arrow keys
map("n", "<leader>n", "<C-w>h", { desc = "Go to left window" })
map("n", "<leader>e", "<C-w>l", { desc = "Go to right window" })

-- buffers
map("n", "<C-tab>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<C-S-tab>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
map("n", "<leader>wd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })
map("n", "<leader>wO", function()
  Snacks.bufdelete.other()
end, { desc = "Delete other buffers" })
map("n", "<leader>wA", function()
  Snacks.bufdelete.all()
  Snacks.dashboard.open()
end, { desc = "Close all buffers and open Dashboard" })

-- Clear search with <esc>
map({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and Clear hlsearch" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
-- NOTE: bound to n/N (not j/J) - j/J must stay as native down-motion/join
map("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- Add undo break-points
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

-- Alternative way to save and exit in Normal mode.
-- NOTE: Adding `redraw` helps with `cmdheight=0` if buffer is not modified
map("n", "<C-s>", "<Cmd>silent! update | redraw<CR>", { desc = "Save" })
map({ "i", "x" }, "<C-s>", "<Esc><Cmd>silent! update | redraw<CR>", { desc = "Save and go to Normal mode" })

-- new file
map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New File" })

-- formatting
map({ "n", "v" }, "<leader>cf", function()
  LazyVim.format({ force = true })
end, { desc = "Format" })

-- diagnostic
local diagnostic_goto = function(next, severity)
  return function()
    vim.diagnostic.jump({
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = true,
    })
  end
end
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
map("n", "[d", diagnostic_goto(false), { desc = "Prev Diagnostic" })
map("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
map("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Prev Error" })
map("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
map("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Prev Warning" })

-- stylua: ignore start

-- toggle options
LazyVim.format.snacks_toggle():map("<leader>uf")
Snacks.toggle.option("spell", { name = "Spelling"}):map("<leader>us")
Snacks.toggle.option("wrap", {name = "Wrap"}):map("<leader>uw")
Snacks.toggle.option("relativenumber", { name = "Relative Number"}):map("<leader>uL")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.option("conceallevel", {off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2}):map("<leader>uc")
Snacks.toggle.treesitter():map("<leader>uT")
Snacks.toggle.option("background", { off = "light", on = "dark" , name = "Dark Background"}):map("<leader>ub")
if vim.lsp.inlay_hint then
  Snacks.toggle.inlay_hints():map("<leader>uh")
end
map("n", "<leader>ug", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle Git blame" })

-- lazygit
map("n", "<leader>gg", function() Snacks.lazygit( { cwd = LazyVim.root.git() }) end, { desc = "Lazygit (Root Dir)" })
map("n", "<leader>gb", function() Snacks.git.blame_line() end, { desc = "Git Blame Line" })
map({ "n", "x" }, "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Git Browse (open)" })
map({"n", "x" }, "<leader>gY", function()
  Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false })
end, { desc = "Git Browse (copy)" })
map("n", "<leader>gf", function() Snacks.lazygit.log_file() end, { desc = "Lazygit Current File History" })
map("n", "<leader>gl", function() Snacks.lazygit.log({ cwd = LazyVim.root.git() }) end, { desc = "Lazygit Log" })
map("n", "<leader>gL", function() Snacks.lazygit.log() end, { desc = "Lazygit Log (cwd)" })

-- quit
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- highlights under cursor
map("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })

-- floating terminal
map("n", "<leader>ft", function() Snacks.terminal(nil, { cwd = LazyVim.root() }) end, { desc = "Terminal (Root Dir)" })
map("n", "<leader>fT", function() Snacks.terminal() end, { desc = "Terminal (cwd)" })
map("t", "<esc><esc>", "<c-\\><c-n>", { desc = "Enter Normal Mode" })
map("t", "<c-t>", "<c-\\><c-n><c-w>k", { desc = "Switch away from the terminal to top window." })

-- tabs
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
