---@see https://github.com/mfussenegger/nvim-lint

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

local pending_bufnrs = {} ---@type table<integer, true>
local deferred_bufnrs = {} ---@type table<integer, true>
local lint_debounced = nil ---@type stl.timer.IDisposableCallable|nil
local lint_schedule_subscription = nil ---@type stl.c.IUnsubscribable|nil

---@param bufnr                         integer
---@return boolean
local function is_buf_visible(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  for _, winnr in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.fn.win_gettype(winnr) ~= "autocmd" then
      return true
    end
  end
  return false
end

---@param bufnr                         integer
local function do_lint_current(bufnr)
  local spellcheck = dot.context.lsp.spellcheck:snapshot() ---@type boolean
  if not spellcheck then
    return
  end

  if vim.b[bufnr][dot.var.N_BUF_DISABLE_LINT] then
    return
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
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

---@param bufnr                         integer
local function do_lint(bufnr)
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  vim.api.nvim_buf_call(bufnr, function()
    do_lint_current(bufnr)
  end)
end

---@return nil
local function flush_pending_lints()
  local bufnrs = pending_bufnrs ---@type table<integer, true>
  pending_bufnrs = {}

  for bufnr in pairs(bufnrs) do
    local ok, err = pcall(do_lint, bufnr)
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "lint buffer",
        message = "Failed to lint buffer.",
        details = { bufnr = bufnr, error = err },
      })
    end
  end
end

---@param bufnr                         integer
---@return nil
local function schedule_lint(bufnr)
  if type(bufnr) ~= "number" or bufnr < 1 or lint_debounced == nil then
    return
  end

  deferred_bufnrs[bufnr] = nil
  pending_bufnrs[bufnr] = true
  lint_debounced()
end

---@param bufnr                         integer
---@return nil
local function schedule_passive_lint(bufnr)
  if type(bufnr) ~= "number" or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if is_buf_visible(bufnr) then
    schedule_lint(bufnr)
  else
    deferred_bufnrs[bufnr] = true
  end
end

---@param bufnr                         integer
---@return nil
local function schedule_deferred_lint(bufnr)
  if deferred_bufnrs[bufnr] and is_buf_visible(bufnr) then
    schedule_lint(bufnr)
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
    if lint_schedule_subscription ~= nil then
      lint_schedule_subscription:unsubscribe()
    end

    pending_bufnrs = {}
    deferred_bufnrs = {}
    lint_debounced = stl.timer.debounce(flush_pending_lints, 128)

    lint_schedule_subscription = dot.state.status.lint_schedule_nr:subscribe(
      stl.c.Subscriber.new({
        on_next = function(bufnr)
          schedule_lint(bufnr)
        end,
      }),
      true
    )

    local group_visible = stl.nvim.fn.augroup("nvim-lint-on-file-visible") ---@type integer
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
      group = group_visible,
      callback = function(event)
        schedule_passive_lint(event.buf)
      end,
    })
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = group_visible,
      callback = function(event)
        schedule_deferred_lint(event.buf)
      end,
    })
    vim.api.nvim_create_autocmd("BufDelete", {
      group = group_visible,
      callback = function(event)
        pending_bufnrs[event.buf] = nil
        deferred_bufnrs[event.buf] = nil
      end,
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
      group = stl.nvim.fn.augroup("nvim-lint-on-file-save"),
      callback = function(event)
        schedule_lint(event.buf)
      end,
    })

    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
      group = stl.nvim.fn.augroup("nvim-lint-on-insert-leave"),
      callback = function(event)
        schedule_lint(event.buf)
      end,
    })

    schedule_passive_lint(vim.api.nvim_get_current_buf())
  end,
}
