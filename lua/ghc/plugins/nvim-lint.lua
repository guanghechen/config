local __module_name__ = "ghc.plugins.nvim-lint" ---@type string

local ft = require("eve.constant.filetype")
local state = require("eve.state")

local config = {
  excluded = {
    ".git/",
    ".cache/",
    ".next/",
    ".yarn/",
    "build/",
    "debug/",
    "data/",
    "public/",
    "node_modules/",
    "target/",
    "tmp/",
    "*.pdf",
    "*.mkv",
    "*.mp4",
    "*.zip",
  },
}

-- stylua: ignore start
local linters_by_ft = {
  -- web --
  css               = { "cspell" },
  graphql           = { "cspell" },
  handlebars        = { "cspell" },
  html              = { "cspell" },
  json              = { "cspell" },
  jsonc             = { "cspell" },
  javascript        = { "cspell" },
  javascriptreact   = { "cspell" },
  less              = { "cspell" },
  markdown          = { "cspell" },
  ["markdown.mdx"]  = { "cspell" },
  svelte            = { "cspell" },
  typescript        = { "cspell" },
  typescriptreact   = { "cspell" },
  yaml              = { "cspell" },

  -- shell --
  fish = { "fish" },

  -- lang --
  lua               = { "cspell" },
  python            = { "cspell" },
  rust              = { "cspell" },

  -- fallback --
  -- ["_"]             = { "cspell" },
}
-- stylua: ignore end

local linters = {}

return {
  name = "nvim-lint",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  config = function()
    local lint = require("lint")
    for name, linter in pairs(linters) do
      if type(linter) == "table" and type(lint.linters[name]) == "table" then
        lint.linters[name] = vim.tbl_deep_extend("force", lint.linters[name], linter)
        if type(linter.prepend_args) == "table" then
          lint.linters[name].args = lint.linters[name].args or {}
          vim.list_extend(lint.linters[name].args, linter.prepend_args)
        end
      else
        lint.linters[name] = linter
      end
    end
    lint.linters_by_ft = linters_by_ft

    local lint_scheduler = eve.col.Scheduler.new({
      name = __module_name__,
      delay = 100,
      silent = function()
        local devmode = state.flight.devmode:snapshot() ---@type boolean
        return devmode
      end,
      task = function()
        local bufnr = vim.api.nvim_get_current_buf() ---@type integer
        local filetype = vim.bo[bufnr].filetype ---@type string
        if ft.is_not_plain_file(filetype) then
          return "done"
        end

        local workspace = eve.path.workspace() ---@type string
        local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath_relative = eve.path.relative(workspace, filepath, true) ---@type string
        if eve.path.is_absolute(filepath_relative) then
          return "done"
        end

        for _, pattern in ipairs(config.excluded) do
          if vim.fn.match(filepath, pattern) ~= -1 then
            return "done"
          end
        end

        local dirpath = vim.fn.fnamemodify(filepath, ":h") ---@type string

        -- Use nvim-lint's logic first:
        -- * checks if linters exist for the full filetype first
        -- * otherwise will split filetype by "." and add all those linters
        -- * this differs from conform.nvim which only uses the first filetype that has a formatter
        local names = lint._resolve_linter_by_ft(vim.bo[bufnr].filetype) ---@type string[]

        -- Create a copy of the names table to avoid modifying the original.
        names = vim.list_slice(names)

        -- Add fallback linters.
        if #names == 0 then
          vim.list_extend(names, lint.linters_by_ft["_"] or {})
        end

        -- Add global linters.
        vim.list_extend(names, lint.linters_by_ft["*"] or {})

        -- Filter out linters that don't exist or don't match the condition.
        local ctx = { filename = filepath, dirname = dirpath }

        local k = 1 ---@type integer
        for i = 1, #names, 1 do
          local name = names[i] ---@type string

          local linter = lint.linters[name]
          if not linter then
            eve.reporter.warn({
              from = __module_name__,
              message = "Linter not found: " .. name,
            })
          elseif type(linter) ~= "table" or not linter.condition or linter.condition(ctx) then
            names[k] = name
            k = k + 1
          end
        end
        for i = k, #names, 1 do
          names[i] = nil
        end

        -- Run linters.
        if #names > 0 then
          lint.try_lint(names)
        end
        return "done"
      end,
    })

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = eve.nvim.augroup("nvim-lint"),
      callback = function()
        local spellcheck = state.lsp.spellcheck:snapshot() ---@type boolean
        if spellcheck then
          lint_scheduler:schedule()
        end
      end,
    })
  end,
}
