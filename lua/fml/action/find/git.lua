local name = "fml.action.find.git" ---@type string
local title = "Find Git" ---@type string

local finder_input_history = std.InputHistory.new({ name = name, capacity = 5 })
local o_finder_input = eve.context.select.find_git.input
local o_flag_foldempty = eve.context.select.find_git.flag_foldempty
local o_flag_fuzzy = eve.context.select.find_git.flag_fuzzy
local o_flag_regex = eve.context.select.find_git.flag_regex
local o_flag_sensitive = eve.context.select.find_git.flag_case_sensitive
local o_flag_selected = eve.context.select.find_git.flag_selected
local o_flag_viewtype = eve.context.select.find_git.flag_viewtype

local git_filepaths_dirty = true
local picker ---@type eve.ux.picker.FiletreeComposer

---@param force                         boolean
---@return nil
local function refresh(force)
  if not force and not git_filepaths_dirty then
    return
  end

  local workspace, status = eve.state.git.status("HEAD") ---@type string, table<string, string>
  local filepaths = {} ---@type string[]
  for filepath in pairs(status) do
    filepaths[#filepaths + 1] = filepath
  end

  picker:reset_filepaths(workspace, filepaths, false)
  git_filepaths_dirty = false
end

picker = eve.ux.picker.FiletreeComposer.new({
  name = name,
  frecency = eve.context.frecency.files,
  permanent = true,
  title = string.format("%s (not committed)", title),
  height = 0.90,
  width = 120,
  preview = false,

  finder_input = o_finder_input,
  finder_input_history = finder_input_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
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
    refresh(true)
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_git_not_committed()
  if not std.path.is_git_repo() then
    std.reporter.error({
      from = name,
      subject = "find_git_not_committed",
      message = "Not a git repository",
    })
    return
  end

  refresh(false)
  picker:focus()
end

return M
