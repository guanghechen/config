---@class ghc.core.action.search.grep_string.context
local context = {
  session = require("ghc.core.context.session"),
}

---@class ghc.core.action.search.grep_string.util
local util = {
  path = require("ghc.core.util.path"),
  selection = require("guanghechen.util.selection"),
  table = require("guanghechen.util.table"),
}

local autocmd = require("ghc.core.action.autocmd")

---@param opts { cwd: string, replace_path?: string }
local function replace_word(opts)
  local sync_path = opts.replace_path == nil ---@type boolean
  local cwd = opts.cwd ---@type string

  local replace_path = opts.replace_path ---@type string
  if replace_path == nil or replace_path == "" then
    replace_path = context.session.replace_path:get_snapshot() ---@type string
  end

  local selected_text = util.selection.get_selected_text() ---@type string
  if selected_text and #selected_text > 1 then
    context.session.replace_search_keyword:next(selected_text)
  end

  local search_text = context.session.replace_search_keyword:get_snapshot() ---@type string
  local replace_text = context.session.replace_replace_keyword:get_snapshot() or search_text ---@type string

  require("spectre").open({
    cwd = cwd,
    --search_paths = {},
    path = replace_path,
    search_text = search_text,
    replace_text = replace_text,
    is_close = true, -- close an exists instance of spectre and open new
    is_insert_mode = false,
  })

  local prompt_bufnr = vim.api.nvim_get_current_buf()
  autocmd.autocmd_remember_spectre_prompt({ prompt_bufnr = prompt_bufnr, sync_path = sync_path })
end

---@class ghc.core.action.replace
local M = {}

function M.replace_word_workspace()
  local cwd = util.path.workspace() ---@type string
  replace_word({ cwd = cwd })
end

function M.replace_word_cwd()
  local cwd = util.path.cwd() ---@type string
  replace_word({ cwd = cwd })
end

function M.replace_word_current_file()
  local cwd = util.path.cwd() ---@type string
  local filepath = util.path.relative(cwd, util.path.current_filepath()) ---@type string
  replace_word({ cwd = cwd, replace_path = filepath })
end

function M.toggle_case_sensitive()
  local current_case_sensitive = context.session.replace_enable_case_sensitive:get_snapshot() ---@type boolean
  local next_case_sensitive = not current_case_sensitive
  context.session.replace_enable_case_sensitive:next(next_case_sensitive)
  require("spectre").change_options("ignore-case")
end

return M
