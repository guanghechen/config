local __module_name__ = "ghc.plugins.nvim-lint" ---@type string

---@class ghc.plugins.nvim_lint.IScheduleContext
---@field public bufnr                  ?integer

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
  css               = { "stylelint", "cspell" },
  graphql           = { "cspell" },
  handlebars        = { "cspell" },
  html              = { "cspell" },
  json              = { "cspell" },
  jsonc             = { "cspell" },
  javascript        = { "cspell" },
  javascriptreact   = { "cspell" },
  less              = { "stylelint", "cspell" },
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

local scheduler = nil ---@type std.collection.Scheduler|nil

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

    if scheduler ~= nil then
      scheduler:dispose()
    end

    ---@type std.collection.Scheduler
    scheduler = std.Scheduler.new({
      name = __module_name__,
      mode = "debounce",
      delay = 128,
      timeout = 0,
      silent = std.fn.falsy,
      value = std.Observable.from_value(true),
      task = function(_, context)
        local spellcheck = eve.context.lsp.spellcheck:snapshot() ---@type boolean
        if not spellcheck then
          return
        end

        context = context or {} ---@type ghc.plugins.nvim_lint.IScheduleContext
        local bufnr = context.bufnr ---@type integer|nil
        if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        if vim.b[bufnr][eve.var.Names.BUF_DISABLE_LINT] then
          return true
        end

        local filetype = vim.bo[bufnr].filetype ---@type string
        if eve.filetype.is_not_sourcefile(filetype) then
          return
        end

        local workspace = std.path.workspace() ---@type string
        local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath_relative = std.path.relative(workspace, filepath, true) ---@type string
        if std.path.is_absolute(filepath_relative) then
          return true
        end

        for _, pattern in ipairs(config.excluded) do
          if vim.fn.match(filepath, pattern) ~= -1 then
            return
          end
        end

        local dirpath = vim.fn.fnamemodify(filepath, ":h") ---@type string

        -- Use nvim-lint's logic first:
        -- * checks if linters exist for the full filetype first
        -- * otherwise will split filetype by "." and add all those linters
        -- * this differs from conform.nvim which only uses the first filetype that has a formatter
        local names = lint._resolve_linter_by_ft(filetype) ---@type string[]

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
            std.reporter.warn({
              from = __module_name__,
              message = "Linter not found: " .. name,
            })
          elseif type(linter) ~= "table" or not linter.condition or linter.condition(ctx) then
            names[k] = name
            k = k + 1
          end
        end
        for i = #names, k, -1 do
          names[i] = nil
        end

        -- Run linters.
        if #names > 0 then
          lint.try_lint(names)
        end
      end,
    })

    std.fn.observe({ eve.status.lint_schedule_nr }, function()
      local bufnr = vim.api.nvim_get_current_buf() ---@type integer
      local context = { bufnr = bufnr } ---@type ghc.plugins.nvim_lint.IScheduleContext
      scheduler:schedule({ context = context })
    end)

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      group = eve.nvim.augroup("nvim-lint-on-file-load-save"),
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf() ---@type integer
        local context = { bufnr = bufnr } ---@type ghc.plugins.nvim_lint.IScheduleContext
        scheduler:schedule({ context = context })
      end,
    })

    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
      group = eve.nvim.augroup("nvim-lint-on-insert-leave"),
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf() ---@type integer
        local context = { bufnr = bufnr } ---@type ghc.plugins.nvim_lint.IScheduleContext
        scheduler:schedule({ context = context })
      end,
    })
  end,
}
