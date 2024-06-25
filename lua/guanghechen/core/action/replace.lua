local action_autocmd = require("guanghechen.core.action.autocmd")
local context_session = require("guanghechen.core.context.session")

---@param opts { cwd: string, replace_path?: string }
local function replace_word(opts)
  local sync_path = opts.replace_path == nil ---@type boolean
  local cwd = opts.cwd ---@type string

  local replace_path = opts.replace_path ---@type string
  if replace_path == nil or replace_path == "" then
    replace_path = context_session.replace_path:get_snapshot() ---@type string
  end

  local selected_text = fml.fn.get_selected_text() ---@type string
  if selected_text and #selected_text > 1 then
    fml.context.replace.search_pattern:next(selected_text)
  end

  local search_paths_text = fml.context.replace.search_paths:get_snapshot() ---@type string
  local search_paths = fml.table.parse_comma_list(search_paths_text) ---@type string[]
  local search_text = fml.context.replace.search_pattern:get_snapshot() ---@type string
  local replace_text = fml.context.replace.replace_pattern:get_snapshot() or search_text ---@type string

  require("spectre").open({
    cwd = cwd,
    search_paths = #search_paths > 0 and search_paths or nil,
    path = replace_path,
    search_text = search_text,
    replace_text = replace_text,
    is_close = false, -- close an exists instance of spectre and open new
    is_insert_mode = false,
  })

  local prompt_bufnr = vim.api.nvim_get_current_buf()
  action_autocmd.autocmd_remember_spectre_prompt({ prompt_bufnr = prompt_bufnr, sync_path = sync_path })
end

---@class guanghechen.core.action.replace
local M = {}

function M.replace_word_workspace()
  local cwd = fml.path.workspace() ---@type string
  replace_word({ cwd = cwd })
end

function M.replace_word_cwd()
  local cwd = fml.path.cwd() ---@type string
  replace_word({ cwd = cwd })
end

function M.replace_word_current_file()
  local cwd = fml.path.cwd() ---@type string
  local filepath = fml.path.relative(cwd, fml.path.current_filepath()) ---@type string
  replace_word({ cwd = cwd, replace_path = filepath })
end

function M.toggle_case_sensitive()
  local current_case_sensitive = fml.context.replace.flag_case_sensitive:get_snapshot() ---@type boolean
  local next_case_sensitive = not current_case_sensitive
  fml.context.replace.flag_case_sensitive:next(next_case_sensitive)
  require("spectre").change_options("ignore-case")
end

return M