local name = "fml.action.find.git" ---@type string
local title = "Find Git" ---@type string

local search_pattern_history = ark.c.InputHistory.new({ name = name, capacity = 5 })
local o_search_pattern = era.context.select.find_git.search_pattern
local o_flag_foldempty = era.context.select.find_git.flag_foldempty
local o_flag_fuzzy = era.context.select.find_git.flag_fuzzy
local o_flag_regex = era.context.select.find_git.flag_regex
local o_flag_case_sensitive = era.context.select.find_git.flag_case_sensitive
local o_flag_selected = era.context.select.find_git.flag_selected
local o_flag_viewtype = era.context.select.find_git.flag_viewtype

local git_filepaths_dirty = true
local picker ---@type ux.picker.FiletreeComposer

---@param force                         boolean
---@return nil
local function refresh(force)
  if not force and not git_filepaths_dirty then
    return
  end

  local workspace, status = era.state.git.status("HEAD") ---@type string, table<string, string>
  local filepaths = {} ---@type string[]
  for filepath in pairs(status) do
    filepaths[#filepaths + 1] = filepath
  end

  picker:reset_filepaths(workspace, filepaths, false)
  git_filepaths_dirty = false
end

picker = ux.picker.FiletreeComposer.new({
  name = name,
  frecency = era.context.frecency.files,
  permanent = true,
  title = string.format("%s (not committed)", title),
  height = 0.90,
  width = 120,
  preview = false,

  search_pattern = o_search_pattern,
  search_pattern_history = search_pattern_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
  flags_start_index = 1,

  on_closed = function()
    git_filepaths_dirty = true
  end,
  on_focused = function()
    refresh(false)
  end,
  on_refresh = function()
    era.state.git.refresh_git_status(true)
    refresh(true)
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_git_not_committed()
  if not dot.path.is_git_repo() then
    ark.reporter.error({
      from = name,
      subject = "find_git_not_committed",
      message = "Not a git repository",
    })
    return
  end

  if picker:isfocused() then
    picker:hide()
    return
  end

  refresh(false)
  picker:focus()
end

return M
