-- emacs: Emacs-style colours for nvim-c, on black like the cmode terminal.
--
-- Few colours, the way Emacs' C mode uses them: keywords blue; types and the
-- names a declaration introduces (variables, parameters, struct fields,
-- macros) teal; function names in their definitions light blue; strings and
-- comments warm; the preprocessor steel blue. Calls, uses of variables,
-- fields, numbers, macros in use and operators stay plain text. No bold or
-- italic, which pixel fonts can't do.
--
-- The declaration names come from queries/c/highlights.scm.

vim.cmd("highlight clear")
vim.g.colors_name = "emacs"
vim.o.background = "dark"

local c = {
  bg = "#000000",
  fg = "#d0d0d0",
  dim = "#6c6c6c", -- line numbers, whitespace markers
  keyword = "#3a9eff",
  teal = "#2ec4b0",
  func = "#87cefa", -- Emacs' LightSkyBlue
  string = "#f0a080", -- LightSalmon
  comment = "#e07a3f", -- chocolate
  preproc = "#b0c4de", -- LightSteelBlue
  modeline = "#303070",
  modeline_nc = "#1c1c38",
  region = "#2e3f6e",
  current = "#3a3a3a", -- the current line's number
}

local groups = {
  Normal = { fg = c.fg, bg = c.bg },
  NormalNC = { link = "Normal" },
  NormalFloat = { fg = c.fg, bg = "#121212" },
  FloatBorder = { fg = c.dim, bg = "#121212" },

  -- the gutter: plain numbers on black, the current one in a grey box
  LineNr = { fg = c.dim },
  CursorLineNr = { fg = "#ffffff", bg = c.current },
  SignColumn = { bg = c.bg },
  CursorLine = { bg = "#1c1c1c" },
  EndOfBuffer = { fg = c.bg },
  NonText = { fg = "#4e4e4e" },
  Whitespace = { fg = "#4e4e4e" },
  ColorColumn = { bg = "#3a1c1c" },
  WinSeparator = { fg = c.dim },

  -- the mode line
  StatusLine = { fg = "#e0e0e0", bg = c.modeline },
  StatusLineNC = { fg = "#9e9e9e", bg = c.modeline_nc },
  TabLine = { fg = "#9e9e9e", bg = c.modeline_nc },
  TabLineSel = { fg = "#e0e0e0", bg = c.modeline },
  TabLineFill = { bg = c.modeline_nc },

  Visual = { bg = c.region },
  Search = { fg = c.bg, bg = "#d7af5f" },
  IncSearch = { fg = c.bg, bg = "#ff87d7" },
  CurSearch = { link = "IncSearch" },
  MatchParen = { bg = "#305070" },
  Pmenu = { fg = c.fg, bg = "#1c1c1c" },
  PmenuSel = { fg = "#ffffff", bg = c.region },
  PmenuSbar = { bg = "#262626" },
  PmenuThumb = { bg = c.dim },
  Directory = { fg = c.func },
  Title = { fg = c.keyword },
  Question = { fg = c.teal },
  MoreMsg = { fg = c.teal },
  ModeMsg = { fg = c.fg },
  ErrorMsg = { fg = "#ff5f5f" },
  WarningMsg = { fg = "#ffaf00" },
  Folded = { fg = c.dim, bg = "#121212" },
  QuickFixLine = { bg = c.region },

  -- syntax (also netrw, man pages, :Asm, and files without tree-sitter)
  Comment = { fg = c.comment },
  String = { fg = c.string },
  Character = { link = "String" },
  Constant = { fg = c.fg },
  Number = { fg = c.fg },
  Boolean = { fg = c.fg },
  Identifier = { fg = c.fg },
  Function = { fg = c.func },
  Statement = { fg = c.keyword },
  Keyword = { fg = c.keyword },
  Conditional = { fg = c.keyword },
  Repeat = { fg = c.keyword },
  Label = { fg = c.keyword },
  Exception = { fg = c.keyword },
  Operator = { fg = c.fg },
  PreProc = { fg = c.preproc },
  Include = { fg = c.preproc },
  Define = { fg = c.preproc },
  Macro = { fg = c.preproc },
  PreCondit = { fg = c.preproc },
  Type = { fg = c.teal },
  StorageClass = { fg = c.keyword },
  Structure = { fg = c.keyword },
  Typedef = { fg = c.keyword },
  Special = { fg = c.string },
  SpecialChar = { fg = c.string },
  Delimiter = { fg = c.fg },
  Todo = { fg = c.bg, bg = c.comment },
  Underlined = { underline = true },
  Error = { fg = "#ff5f5f" },

  -- tree-sitter
  ["@variable"] = { fg = c.fg },
  ["@variable.builtin"] = { fg = c.fg },
  ["@variable.parameter"] = { fg = c.teal },
  ["@variable.declaration"] = { fg = c.teal },
  ["@variable.member"] = { fg = c.fg },
  ["@property"] = { fg = c.fg },
  ["@constant"] = { fg = c.fg },
  ["@constant.builtin"] = { fg = c.fg },
  ["@constant.macro"] = { fg = c.teal },
  ["@label"] = { fg = c.fg },
  ["@number"] = { fg = c.fg },
  ["@boolean"] = { fg = c.fg },
  ["@string"] = { fg = c.string },
  ["@string.escape"] = { fg = c.string },
  ["@character"] = { fg = c.string },
  ["@comment"] = { fg = c.comment },
  ["@type"] = { fg = c.teal },
  ["@type.builtin"] = { fg = c.teal },
  ["@type.definition"] = { fg = c.teal },
  ["@function"] = { fg = c.func },
  ["@function.call"] = { fg = c.fg },
  ["@function.builtin"] = { fg = c.fg },
  ["@function.macro"] = { fg = c.func },
  ["@keyword"] = { fg = c.keyword },
  ["@keyword.directive"] = { fg = c.preproc },
  ["@keyword.directive.define"] = { fg = c.preproc },
  ["@keyword.import"] = { fg = c.preproc },
  ["@operator"] = { fg = c.fg },
  ["@punctuation"] = { fg = c.fg },
  ["@attribute"] = { fg = c.fg },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end
