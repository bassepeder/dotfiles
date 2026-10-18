-- eslint config markers; presence means a project wants eslint/prettier over oxlint/oxfmt
local eslint_markers = {
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.json",
  ".eslintrc.yaml",
  ".eslintrc.yml",
}

-- projects on TypeScript 7+ get the native `tsc --lsp` server instead of vtsls;
-- vtsls stays for older projects and Vue (tsc has no tsserver plugin support)
local ts7_cache = {} ---@type table<string, boolean>
---@return string? root of the buffer's project if it is on TypeScript 7+
local function ts7_root(bufnr)
  local lockfiles = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
  local root = vim.fs.root(bufnr, { lockfiles, ".git" })
  if not root then
    return nil
  end
  if ts7_cache[root] == nil then
    local bin = root .. "/node_modules/.bin/tsc"
    local version = vim.fn.executable(bin) == 1
      and vim.version.parse(vim.system({ bin, "--version" }, { text = true }):wait().stdout or "")
    ts7_cache[root] = version and version.major >= 7 or false
  end
  return ts7_cache[root] and root or nil
end

return {
  -- language servers
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- LazyVim excludes vue from inlay hints by default (leftover from when only
      -- ts_ls/vtsls without vue_ls could provide them) - vue_ls handles them fine now
      inlay_hints = { exclude = {} },
      servers = {
        ["*"] = {
          -- stylua: ignore
          keys = {
            { "ge", function() Snacks.picker.lsp_definitions() end, desc = "Definition", has = "definition", },
            { "gE", vim.lsp.buf.declaration, desc = "Goto Declaration" },
            { "gn", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
            { "gh", vim.lsp.buf.hover, desc = "Hover" },
            { "<leader>cl", vim.lsp.codelens.run, desc = "Run Codelens", mode = { "n", "x" }, has = "codeLens" },
          },
        },
        -- disabled in favor of vtsls: vue_ls needs vtsls (with the vue plugin below) for
        -- TS support in .vue files, and running both alongside each other isn't supported
        ts_ls = { enabled = false },
        buf_ls = {},
        -- vue_ls handles Vue-specific language features (template completion incl.
        -- component auto-import, directives, scoped style class refs); it forwards
        -- plain TS requests to vtsls below via hybrid mode
        -- https://github.com/vuejs/language-tools/wiki/Neovim
        vue_ls = {},
        vtsls = {
          -- vue_ls hybrid mode forwards TS requests to vtsls; wire in its vue plugin
          -- https://github.com/vuejs/language-tools/wiki/Neovim
          filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
          settings = {
            typescript = {
              inlayHints = {
                -- off by default; toggle at runtime with <leader>tp (see config/keymaps.lua)
                parameterNames = { enabled = "none" },
                parameterTypes = { enabled = true },
                -- off: too noisy on inferred const/let types, e.g. const failures: {...}[] = ...
                variableTypes = { enabled = false },
                propertyDeclarationTypes = { enabled = true },
                -- off by default; toggle at runtime with <leader>tr (see config/keymaps.lua)
                functionLikeReturnTypes = { enabled = false },
                enumMemberValues = { enabled = true },
              },
            },
            javascript = {
              inlayHints = {
                -- off by default; toggle at runtime with <leader>tp (see config/keymaps.lua)
                parameterNames = { enabled = "none" },
                parameterTypes = { enabled = true },
                -- off: too noisy on inferred const/let types, e.g. const failures: {...}[] = ...
                variableTypes = { enabled = false },
                propertyDeclarationTypes = { enabled = true },
                -- off by default; toggle at runtime with <leader>tr (see config/keymaps.lua)
                functionLikeReturnTypes = { enabled = false },
                enumMemberValues = { enabled = true },
              },
            },
            completions = {
              completeFunctionCalls = true,
            },
            vtsls = {
              tsserver = {
                globalPlugins = {
                  {
                    name = "@vue/typescript-plugin",
                    location = vim.fn.stdpath("data")
                      .. "/mason/packages/vue-language-server/node_modules/@vue/language-server",
                    languages = { "vue" },
                    configNamespace = "typescript",
                  },
                },
              },
            },
          },
        },
        tsc = {
          -- runs the project's own node_modules/.bin/tsc, not a Mason install
          mason = false,
          cmd = function(dispatchers, config)
            return vim.lsp.rpc.start({ config.root_dir .. "/node_modules/.bin/tsc", "--lsp", "--stdio" }, dispatchers)
          end,
          root_dir = function(bufnr, on_dir)
            local root = ts7_root(bufnr)
            if root then
              on_dir(root)
            end
          end,
          settings = {
            ["js/ts"] = {
              -- mirrors vtsls above; toggled by the same keymaps
              inlayHints = {
                parameterNames = { enabled = "none" },
                parameterTypes = { enabled = true },
                variableTypes = { enabled = false },
                propertyDeclarationTypes = { enabled = true },
                functionLikeReturnTypes = { enabled = false },
                enumMemberValues = { enabled = true },
              },
            },
          },
        },
        -- CSS/HTML/Tailwind/Emmet for .vue <style>/<template> blocks and standalone files
        cssls = {},
        html = {},
        tailwindcss = {}, -- only attaches when a tailwind/postcss config is found in the project
        emmet_language_server = {},
        eslint = {
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, eslint_markers)
            if root then
              on_dir(root)
            end
          end,
          settings = {
            -- helps eslint find the eslintrc when it's placed in a subfolder instead of the cwd root
            workingDirectories = { mode = "auto" },
            -- exposes eslint as a documentFormattingProvider so it fixes on save (below)
            format = true,
          },
        },
        -- skip oxlint where eslint owns the project (defaults mirrored from extras/lang/typescript/oxc.lua)
        oxlint = {
          root_dir = function(bufnr, on_dir)
            if vim.fs.root(bufnr, eslint_markers) then
              return
            end
            local git = vim.fs.root(bufnr, ".git")
            local markers = { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" }
            local root = git and vim.fs.root(git, markers) or vim.fs.root(bufnr, markers)
            if root then
              on_dir(root)
            end
          end,
          settings = {
            fixKind = "all",
          },
        },
      },
      setup = {
        vtsls = function(_, opts)
          local default = vim.lsp.config.vtsls.root_dir
          opts.root_dir = function(bufnr, on_dir)
            if vim.bo[bufnr].filetype == "vue" or not ts7_root(bufnr) then
              default(bufnr, on_dir)
            end
          end
        end,
        -- eslint exposes itself as a documentFormattingProvider (settings.format
        -- above); register it with LazyVim's format-on-save pipeline so `eslint
        -- --fix`-equivalent fixes run automatically, same as prettier/oxfmt
        eslint = function()
          LazyVim.format.register(LazyVim.lsp.formatter({
            name = "eslint: lsp",
            primary = false,
            priority = 200,
            filter = "eslint",
          }))
        end,
        -- oxlint has no documentFormattingProvider, only a custom "oxc.fixAll"
        -- command - wire it into the same on-save pipeline, ahead of prettier/oxfmt
        -- (priority 300 > eslint's 200 > conform's 100) so formatting cleans up after it
        oxlint = function()
          LazyVim.format.register({
            name = "oxlint: fix",
            primary = false,
            priority = 300,
            sources = function(buf)
              local clients = vim.lsp.get_clients({ bufnr = buf, name = "oxlint" })
              return #clients > 0 and { "oxlint" } or {}
            end,
            format = function(buf)
              local client = vim.lsp.get_clients({ bufnr = buf, name = "oxlint" })[1]
              if not client then
                return
              end
              local done = false
              client:exec_cmd({
                title = "Apply Oxlint automatic fixes",
                command = "oxc.fixAll",
                arguments = { { uri = vim.uri_from_bufnr(buf) } },
              }, { bufnr = buf }, function()
                done = true
              end)
              vim.wait(2000, function()
                return done
              end, 10)
            end,
          })
        end,
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "buf",
        "eslint-lsp",
        "vtsls",
        "vue-language-server",
        "css-lsp",
        "html-lsp",
        "tailwindcss-language-server",
        "emmet-language-server",
      },
    },
  },
}
