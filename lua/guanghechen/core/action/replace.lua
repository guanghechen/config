---@param opts { cwd: string, replace_path?: string }
local function replace_word(opts)
  local cwd = opts.cwd ---@type string
  local selected_text = fml.fn.get_selected_text() ---@type string
  ghc.command.replace.search({ cwd = cwd, word = selected_text })
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
  local next_case_sensitive = not ghc.context.search.flag_case_sensitive:get_snapshot() ---@type boolean
  ghc.context.search.flag_case_sensitive:next(next_case_sensitive)
end

return M

