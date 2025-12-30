---@see https://github.com/mfussenegger/nvim-lint/tree/d1118791070d090777398792a73032a0ca5c79ff

local __module_name__ = "era.plugin.nvim-lint" ---@type string

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
  bash              = { "shellcheck" },
  sh                = { "shellcheck" },
  fish              = { "fish" },

  -- lang --
  lua               = { "cspell" },
  python            = { "cspell" },
  rust              = { "cspell" },

  -- fallback --
  -- ["_"]             = { "cspell" },
}
-- stylua: ignore end

local linters = {
  cspell = {
    append_args = { "--show-suggestions" },
  },
}

local lint_debounced = nil ---@type stl.timer.IDisposableCallable|nil

---@param bufnr                         integer
local function do_lint(bufnr)
  local spellcheck = dot.context.lsp.spellcheck:snapshot() ---@type boolean
  if not spellcheck then
    return
  end

  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if vim.b[bufnr][dot.var.N_BUF_DISABLE_LINT] then
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if stl.filetype.is_not_sourcefile(filetype) then
    return
  end

  local workspace = dot.path.workspace() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filepath_relative = dot.path.relative(workspace, filepath, "/") ---@type string
  if yoz.path.is_absolute(filepath_relative) then
    return
  end

  for _, pattern in ipairs(config.excluded) do
    if vim.fn.match(filepath, pattern) ~= -1 then
      return
    end
  end

  local dirpath = vim.fn.fnamemodify(filepath, ":h") ---@type string

  local lint = require("lint")

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
      stl.reporter.warn({
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
end

return {
  name = "nvim-lint",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    local lint = require("lint")
    for name, linter in pairs(linters) do
      if type(linter) == "table" and type(lint.linters[name]) == "table" then
        lint.linters[name] = vim.tbl_deep_extend("force", lint.linters[name], linter)
        if type(linter.append_args) == "table" then
          lint.linters[name].args = lint.linters[name].args or {}
          vim.list_extend(lint.linters[name].args, linter.append_args)
        end
      else
        lint.linters[name] = linter
      end
    end
    lint.linters_by_ft = linters_by_ft

    if lint_debounced ~= nil then
      lint_debounced:dispose()
    end
    lint_debounced = stl.timer.debounce(do_lint, 128)

    stl.fn.observe({ dot.state.status.lint_schedule_nr }, function()
      local bufnr = vim.api.nvim_get_current_buf() ---@type integer
      lint_debounced(bufnr)
    end)

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      group = stl.nvim.fn.augroup("nvim-lint-on-file-load-save"),
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf() ---@type integer
        lint_debounced(bufnr)
      end,
    })

    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
      group = stl.nvim.fn.augroup("nvim-lint-on-insert-leave"),
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf() ---@type integer
        lint_debounced(bufnr)
      end,
    })
  end,
}
