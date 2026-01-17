---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.find_git" ---@type string

local name = "era.fn.find_git" ---@type string
local title = "Find Git" ---@type string

local search_pattern_history = stl.c.InputHistory.new({ name = name, capacity = 5 })
local o_search_pattern = dot.context.select.find_git.search_pattern
local o_flag_foldempty = dot.context.select.find_git.flag_foldempty
local o_flag_fuzzy = dot.context.select.find_git.flag_fuzzy
local o_flag_regex = dot.context.select.find_git.flag_regex
local o_flag_case_sensitive = dot.context.select.find_git.flag_case_sensitive
local o_flag_selected = dot.context.select.find_git.flag_selected
local o_flag_viewtype = dot.context.select.find_git.flag_viewtype

local git_filepaths_dirty = true
local picker ---@type era.m.picker.FiletreeComposer

---@async
---@param force                         boolean
---@return nil
local function refresh(force)
  if not force and not git_filepaths_dirty then
    return
  end

  local status = era.m.git.state.status("HEAD"):await()
  if status == nil then
    return
  end

  local workspace = dot.path.workspace()
  local filepaths = {} ---@type string[]
  for filepath in pairs(status) do
    filepaths[#filepaths + 1] = filepath
  end

  picker:reset_filepaths(workspace, filepaths, false)
  git_filepaths_dirty = false
end

picker = era.m.picker.FiletreeComposer.new({
  name = name,
  frecency = dot.context.frecency.files,
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
    stl.async.run(function()
      refresh(false)
    end)
  end,
  on_refresh = function()
    stl.async.run(function()
      era.m.git.state.refresh(true):await()
      refresh(true)
    end)
  end,
})

---@return nil
local function find_git()
  if not dot.path.is_git_repo() then
    stl.reporter.error({
      from = name,
      subject = "find_git",
      message = "Not a git repository",
    })
    return
  end

  if picker:isfocused() then
    picker:hide()
    return
  end

  stl.async.run(function()
    refresh(false)
    picker:focus()
  end)
end

return find_git
